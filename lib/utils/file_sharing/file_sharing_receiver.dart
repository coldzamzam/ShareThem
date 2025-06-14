import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/protos/packet.pbenum.dart';
import 'package:flutter_shareit/protos/packet.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:flutter_shareit/utils/auth_utils.dart';
import 'package:flutter_shareit/models/received_file_entry.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_shareit/firebase_options.dart';
import 'package:flutter/services.dart'; // Import for BackgroundIsolateBinaryMessenger
import 'dart:ui' as ui; // Import for ui.RootIsolateToken

// --- TOP-LEVEL HELPER FUNCTIONS FOR ISOLATE ---

Future<Directory> _getDownloadDirectoryForUser(String receiverUserId) async {
  final baseDir = (await getExternalStorageDirectory())!;
  final downloadDir = Directory(
    p.join(baseDir.path, 'downloads', receiverUserId),
  );
  if (!await downloadDir.exists()) {
    await downloadDir.create(recursive: true);
  }
  return downloadDir;
}

Future<String?> _performFinalizeSaveInIsolate(
  Map<String, dynamic> params,
) async {
  // Retrieve the token from params
  final ui.RootIsolateToken? rootIsolateToken = params['rootIsolateToken'] as ui.RootIsolateToken?;

  if (rootIsolateToken == null) {
    print("Isolate: Error: RootIsolateToken is null. Cannot initialize BackgroundIsolateBinaryMessenger.");
    return "Error: Failed to initialize background services for file save.";
  }

  // Pass the token to ensureInitialized
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

  // Initialize Firebase for this isolate if it hasn't been already
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("Isolate: Firebase initialized successfully in isolate.");
    } catch (e) {
      print("Isolate: Error initializing Firebase in isolate: $e");
      return "Error: Failed to initialize Firebase for saving file metadata: $e";
    }
  }

  final String tempFilePathWithPart = params['tempFilePathWithPart'];
  final String originalFileName = params['originalFileName'];
  final int fileSize = params['fileSize'];
  final String senderId = params['senderId'];
  final String senderName = params['senderName'];
  final String receiverUserId = params['receiverUserId'];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final File tempFile = File(tempFilePathWithPart);
  if (!await tempFile.exists()) {
    return "Error: Temporary file '$tempFilePathWithPart' not found.";
  }

  try {
    Directory targetDirectory = await _getDownloadDirectoryForUser(
      receiverUserId,
    );
    print(
      "Isolate: Target directory for receiver $receiverUserId is: ${targetDirectory.path}",
    );

    String finalPath = p.join(targetDirectory.path, originalFileName);
    String baseName = p.basenameWithoutExtension(originalFileName);
    String extension = p.extension(originalFileName);
    int count = 1;

    while (await File(finalPath).exists()) {
      String newName = '$baseName ($count)$extension';
      finalPath = p.join(targetDirectory.path, newName);
      count++;
    }

    print("Isolate: Reading temporary file '$tempFilePathWithPart'.");
    final Uint8List fileBytes = await tempFile.readAsBytes();

    print("Isolate: Attempting to save file to: '$finalPath'");
    final File finalFile = File(finalPath);
    await finalFile.writeAsBytes(fileBytes);

    print("Isolate: File saved successfully to: '$finalPath'");
    await tempFile.delete();
    print("Isolate: Temporary file '$tempFilePathWithPart' deleted.");

    final receivedFileEntry = ReceivedFileEntry(
      id: '',
      fileName: p.basename(finalPath),
      filePath: finalPath,
      fileSize: fileSize,
      modifiedDate: DateTime.now(),
      senderId: senderId,
      senderName: senderName,
    );

    await firestore
      .collection('users') // <--- Collection 'users'
      .doc(receiverUserId) // <--- Document for the user
      .collection('savedFiles') // <--- Subcollection 'savedFiles'
      .add(receivedFileEntry.toFirestore());

    print(
      "Isolate: Saved file metadata to Firestore for receiver $receiverUserId.",
    );
    return finalPath;
  } catch (e, s) {
    print("Isolate: Error during finalizeSave: $e\n$s");
    String errorMessage = "Failed to save '$originalFileName': $e";
    if (Platform.isAndroid && e is FileSystemException) {
      if (e.osError?.errorCode == 13 || e.osError?.errorCode == 1) {
        errorMessage =
          "Failed to save '$originalFileName' due to permission issues on Android.";
      }
    }
    return "Error: $errorMessage";
  }
}

class FileSharingReceiver {
  final int listenPort;
  ValueChanged<List<(SharedFile, int)>>? onFileProgress;
  ValueChanged<String>? onError;
  ValueChanged<List<dynamic>>? onFileReceivedToTemp;
  VoidCallback? onTransferComplete;

  Map<
    String,
    ({SharedFile sharedFile, int receivedBytes, bool isCompletedAndNotified})
  >
  _sharedFilesStatus = {};
  ServerSocket? _serverSocket;
  Socket? _currentClientSocket;
  StreamSubscription<Uint8List>? _socketSubscription;
  String? _temporaryStoragePath;

  final Map<String, IOSink> _fileSinks = {};
  Uint8List _incomingBuffer = Uint8List(
    0,
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _appId = 'flutter_shareit_app';

  FileSharingReceiver({
    this.listenPort = SharingDiscoveryService.servicePort,
    this.onFileProgress,
    this.onError,
    this.onFileReceivedToTemp,
    this.onTransferComplete,
  });

  Future<void> _prepareStoragePaths() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _temporaryStoragePath = tempDir.path;
      print(
        'FileSharingReceiver: Temporary files will be stored in: $_temporaryStoragePath',
      );
    } catch (e) {
      print("FileSharingReceiver: Error preparing temporary storage path: $e");
      onError?.call("Failed to prepare temporary storage directory: $e");
      _temporaryStoragePath = null;
    }
  }

  Future<void> stop() async {
    print("FileSharingReceiver: stop() called.");

    await _socketSubscription?.cancel();
    _socketSubscription = null;

    try {
      if (_currentClientSocket != null) {
        await _currentClientSocket?.flush();
        await _currentClientSocket?.close();
        _currentClientSocket = null;
        print("FileSharingReceiver: Current client socket closed.");
      }
    } catch (e) {
      print("FileSharingReceiver: Error closing current client socket: $e");
    }

    try {
      if (_serverSocket != null) {
        await _serverSocket?.close();
        _serverSocket = null;
        print("FileSharingReceiver: Server socket closed.");
      }
    } catch (e) {
      print("FileSharingReceiver: Error closing server socket: $e");
    }

    final List<String> sinkKeys = _fileSinks.keys.toList();
    for (final key in sinkKeys) {
      final sink = _fileSinks[key];
      try {
        await sink?.flush();
        await sink?.close();
        print("FileSharingReceiver: Closed sink for $key.");
      } catch (e) {
        print("FileSharingReceiver: Error closing sink for $key: $e");
      }
    }
    _fileSinks.clear();
    _incomingBuffer = Uint8List(0);
    print(
      "FileSharingReceiver: All sinks closed and cleared. Receiver stopped.",
    );
  }

  Future<void> start() async {
    print("FileSharingReceiver: start() called.");
    if (_serverSocket != null) {
      print("FileSharingReceiver: Receiver already running.");
      return;
    }

    await _prepareStoragePaths();
    if (_temporaryStoragePath == null) {
      onError?.call(
        "Temporary storage path not available. Cannot start receiver.",
      );
      return;
    }
    _sharedFilesStatus.clear();
    _incomingBuffer = Uint8List(0);

    if (_fileSinks.isNotEmpty) {
      print(
        "FileSharingReceiver: Warning - _fileSinks was not empty at start. Clearing now.",
      );
      final List<String> sinkKeys = _fileSinks.keys.toList();
      for (final key in sinkKeys) {
        try {
          await _fileSinks[key]?.flush();
          await _fileSinks[key]?.close();
        } catch (e) {
          /* ignore errors during forced cleanup */
        }
      }
      _fileSinks.clear();
    }

    print(
      "FileSharingReceiver: Attempting to bind server socket on port $listenPort.",
    );
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        listenPort,
      );
      print(
        'FileSharingReceiver: Server socket bound successfully on port $listenPort. Listening for connections...',
      );
    } catch (e) {
      print("FileSharingReceiver: Error binding server socket: $e");
      onError?.call("Failed to start receiver: $e");
      return;
    }

    _serverSocket!.listen((socket) {
      if (_currentClientSocket != null) {
        print(
          'FileSharingReceiver: Already connected to a sender. Rejecting new connection from ${socket.remoteAddress.address}:${socket.remotePort}',
        );
        socket.destroy();
        return;
      }

      _currentClientSocket = socket;
      print(
        'FileSharingReceiver: Connection received from ${socket.remoteAddress.address}:${socket.remotePort}',
      );
      _incomingBuffer = Uint8List(0);

      _socketSubscription = _currentClientSocket!.listen(
        (data) async {
          _incomingBuffer = Uint8List.fromList([..._incomingBuffer, ...data]);

          var offset = 0;
          while (true) {
            if (offset + 4 > _incomingBuffer.lengthInBytes) {
              break;
            }

            final packetLength = ByteData.view(
              _incomingBuffer.buffer,
              offset,
              4,
            ).getUint32(0);
            final headerAndPacketLength =
                4 +
                1 +
                packetLength;

            if (offset + headerAndPacketLength >
                _incomingBuffer.lengthInBytes) {
              break;
            }

            final packetTypeByte =
                _incomingBuffer[offset + 4];
            EPacketType? packetType;
            try {
              packetType = EPacketType.valueOf(packetTypeByte);
            } catch (e) {
              print(
                "FileSharingReceiver: Unknown EPacketType byte: $packetTypeByte at offset $offset. Skipping this packet.",
              );
              offset += headerAndPacketLength;
              continue;
            }

            final payloadOffset = offset + 4 + 1;
            final Uint8List payloadBytes = Uint8List.sublistView(
              _incomingBuffer,
              payloadOffset,
              payloadOffset + packetLength,
            );

            switch (packetType) {
              case EPacketType.GetSharedFilesRsp:
                try {
                  final filesRsp = GetSharedFilesRsp.fromBuffer(payloadBytes);
                  print(
                    "FileSharingReceiver: GetSharedFilesRsp - Received with files: ${filesRsp.files.map((f) => f.fileName).toList()}",
                  );

                  Map<
                    String,
                    ({
                      SharedFile sharedFile,
                      int receivedBytes,
                      bool isCompletedAndNotified,
                    })
                  >
                  newStatusMap = {};
                  for (var fileMetaFromRsp in filesRsp.files) {
                    final existingStatus =
                        _sharedFilesStatus[fileMetaFromRsp.fileName];
                    newStatusMap[fileMetaFromRsp.fileName] = (
                      sharedFile: fileMetaFromRsp,
                      receivedBytes:
                          existingStatus?.receivedBytes ??
                          0,
                      isCompletedAndNotified:
                          existingStatus?.isCompletedAndNotified ??
                          false,
                    );
                  }
                  _sharedFilesStatus = newStatusMap;

                  onFileProgress?.call(
                    _sharedFilesStatus.values
                        .map((s) => (s.sharedFile, s.receivedBytes))
                        .toList(),
                  );
                } catch (e, s) {
                  print(
                    "FileSharingReceiver: Error parsing GetSharedFilesRsp: $e\n$s",
                  );
                  onError?.call("Error processing file list: $e");
                }
                break;

              case EPacketType.SharedFileContentNotify:
                if (_temporaryStoragePath == null) {
                  onError?.call("Temporary storage path not set. File chunk skipped.");
                  break;
                }
                SharedFileContentNotify? fileChunk;
                try {
                  fileChunk = SharedFileContentNotify.fromBuffer(payloadBytes);
                  final SharedFile sharedFileInfoFromChunk = fileChunk.file;
                  final String originalFileName = sharedFileInfoFromChunk.fileName;
                  final fileContent = fileChunk.content;

                  var fileStatus = _sharedFilesStatus[originalFileName];

                  // --- MODIFICATION HERE FOR LINGERING SINK CLEANUP ---
                  if (fileStatus != null && fileStatus.isCompletedAndNotified) {
                    if (_fileSinks.containsKey(originalFileName)) {
                        IOSink? existingSink = _fileSinks[originalFileName];
                        if (existingSink != null) {
                            print("FileSharingReceiver: Found unexpected, lingering sink for completed file: $originalFileName. Attempting final cleanup.");
                            try {
                                // Flush any remaining buffer, then attempt to close.
                                // It's okay if this throws Bad state, as the primary close likely succeeded.
                                await existingSink.flush();
                                await existingSink.close();
                                print("FileSharingReceiver: Lingering sink for $originalFileName successfully cleaned up.");
                            } catch (e) {
                                print("FileSharingReceiver: Error during lingering sink cleanup for $originalFileName: $e");
                                // **Crucial: Even if close fails, ensure it's removed from the map.**
                                // This is the most important part to prevent *future* interactions.
                            } finally {
                                _fileSinks.remove(originalFileName); // Remove regardless of close success/failure
                            }
                        }
                    }
                    print("FileSharingReceiver: Ignoring processing for already completed/handled file: $originalFileName. No longer expecting content.");
                    break; // Stop all further processing for this chunk.
                  }
                  // --- END MODIFICATION ---

                  if (fileStatus == null) {
                    _sharedFilesStatus[originalFileName] = (
                      sharedFile: sharedFileInfoFromChunk,
                      receivedBytes: 0,
                      isCompletedAndNotified: false
                    );
                    fileStatus = _sharedFilesStatus[originalFileName];
                  }

                  var currentReceivedBytes = fileStatus!.receivedBytes + fileContent.length;
                  _sharedFilesStatus[originalFileName] = (
                    sharedFile: fileStatus.sharedFile,
                    receivedBytes: currentReceivedBytes,
                    isCompletedAndNotified: fileStatus.isCompletedAndNotified
                  );

                  final String tempFilePath = p.join(_temporaryStoragePath!, '$originalFileName.part');
                  IOSink sink = _fileSinks[originalFileName] ??= File(tempFilePath).openWrite(mode: FileMode.append);
                  
                  // Add content to the sink
                  sink.add(fileContent);

                  onFileProgress?.call(
                    _sharedFilesStatus.values.map((s) => (s.sharedFile, s.receivedBytes)).toList()
                  );

                  // This block handles the *primary* closure of the sink when the file is fully received.
                  if (currentReceivedBytes >= sharedFileInfoFromChunk.fileSize && !fileStatus.isCompletedAndNotified) {
                    print('FileSharingReceiver: File $originalFileName received completely to temp. Path: $tempFilePath');

                    _sharedFilesStatus[originalFileName] = (
                      sharedFile: fileStatus.sharedFile,
                      receivedBytes: currentReceivedBytes,
                      isCompletedAndNotified: true
                    );

                    final sinkToClose = _fileSinks[originalFileName];
                    if (sinkToClose != null) {
                      try {
                        await sinkToClose.flush();
                        await sinkToClose.close(); // Primary close operation
                        print("FileSharingReceiver: Sink for $originalFileName successfully closed after full reception.");
                      } catch (e) {
                        print("FileSharingReceiver: Primary error closing sink for $originalFileName after completion: $e");
                        onError?.call("Failed to finalize temporary file for '$originalFileName': $e");
                      } finally {
                         // Always ensure it's removed immediately after trying to close.
                         _fileSinks.remove(originalFileName); 
                      }
                    } else {
                        print("FileSharingReceiver: Warning: Sink for $originalFileName was null after full reception. (Likely race condition)");
                    }
                    onFileReceivedToTemp?.call([fileStatus.sharedFile, tempFilePath]);
                  }
                } catch (e, s) {
                  final fileNameForError = fileChunk?.file.fileName ?? 'unknown file';
                  print("FileSharingReceiver: Error processing SharedFileContentNotify for $fileNameForError: $e\n$s");
                  onError?.call("Error saving file chunk to temp for $fileNameForError: $e");

                  if (_sharedFilesStatus.containsKey(fileNameForError)) {
                      _sharedFilesStatus[fileNameForError] = (
                          sharedFile: _sharedFilesStatus[fileNameForError]!.sharedFile,
                          receivedBytes: _sharedFilesStatus[fileNameForError]!.receivedBytes,
                          isCompletedAndNotified: true
                      );
                  }

                  final sinkOnError = _fileSinks[fileNameForError];
                  if (sinkOnError != null) {
                    try {
                      await sinkOnError.flush();
                      await sinkOnError.close();
                      print("FileSharingReceiver: Sink for $fileNameForError successfully closed on error.");
                    } catch (closeError) {
                      print("FileSharingReceiver: Error closing sink for $fileNameForError in error handler: $closeError");
                    } finally {
                      _fileSinks.remove(fileNameForError); // Always ensure it's removed
                    }
                  }
                }
                break;

              case EPacketType.FileTransferCompleteNotify:
                print(
                  "FileSharingReceiver: <<< RECEIVED FILE_TRANSFER_COMPLETE_NOTIFY >>>",
                );

                for (var key in _fileSinks.keys.toList()) {
                  final sink = _fileSinks[key];
                  try {
                    await sink?.flush();
                    await sink?.close();
                    print(
                      "FileSharingReceiver: Closed remaining sink for $key.",
                    );
                  } catch (e) {
                    print(
                      "FileSharingReceiver: Error closing remaining sink for $key: $e",
                    );
                  }
                }
                _fileSinks.clear();

                onTransferComplete?.call();

                await _currentClientSocket?.close();
                print(
                  "FileSharingReceiver: Client socket closed by receiver after FileTransferCompleteNotify.",
                );
                await _socketSubscription?.cancel();
                _socketSubscription = null;
                _currentClientSocket = null;
                break;

              default:
                print(
                  "FileSharingReceiver: Invalid EPacketType received: $packetType (byte: $packetTypeByte)",
                );
                break;
            }
            // Move offset past the processed packet
            offset += headerAndPacketLength;
          }

          // If there's remaining data after processing all complete packets,
          // create a new _incomingBuffer with just the remaining part.
          if (offset < _incomingBuffer.lengthInBytes) {
            _incomingBuffer = Uint8List.sublistView(_incomingBuffer, offset);
          } else {
            _incomingBuffer = Uint8List(0); // All data processed, clear buffer
          }
        },
        onDone: () async {
          print(
            'FileSharingReceiver: Socket listener onDone: Connection closed by sender or network. Client: ${_currentClientSocket?.remoteAddress.address}:${_currentClientSocket?.remotePort}',
          );

          bool allFilesActuallyCompleted = _sharedFilesStatus.values.every(
            (e) => e.isCompletedAndNotified,
          );

          if (!allFilesActuallyCompleted && _sharedFilesStatus.isNotEmpty) {
            onError?.call(
              'Connection closed unexpectedly during transfer. Not all files may have been sent.',
            );
          }

          for (var key in _fileSinks.keys.toList()) {
            final sink = _fileSinks[key];
            if (sink != null) {
              try {
                await sink.close();
              } catch (e) {
                print(
                  "FileSharingReceiver: Error closing sink for $key in onDone: $e",
                );
              }
            }
          }
          _fileSinks.clear();
          _sharedFilesStatus.clear();
          _incomingBuffer = Uint8List(0);

          _currentClientSocket = null;
          _socketSubscription = null;
        },
        onError: (error, stackTrace) async {
          print('FileSharingReceiver: Socket error: $error\n$stackTrace');
          _currentClientSocket?.destroy();
          _currentClientSocket = null;
          _socketSubscription?.cancel();
          _socketSubscription = null;
          onError?.call("Network connection error during receive: $error");

          for (var key in _fileSinks.keys.toList()) {
            final sink = _fileSinks[key];
            if (sink != null) {
              try {
                await sink.close();
              } catch (e) {
                print(
                  "FileSharingReceiver: Error closing sink for $key in onError: $e",
                );
              }
            }
          }
          _fileSinks.clear();
          _sharedFilesStatus.clear();
          _incomingBuffer = Uint8List(0);
        },
        cancelOnError: true,
      );

      try {
        print(
          "FileSharingReceiver: Sending GetSharedFilesReq to ${_currentClientSocket?.remoteAddress.address}",
        );
        final packet = makePacket(EPacketType.GetSharedFilesReq);
        _currentClientSocket?.add(Uint8List.sublistView(packet));
        _currentClientSocket?.flush();
      } catch (e) {
        print("FileSharingReceiver: Error sending GetSharedFilesReq: $e");
        onError?.call("Failed to request file list from sender: $e");
      }
    });
  }

  Future<String?> finalizeSave(
    String tempFilePathWithPart,
    String originalFileName,
    int fileSize,
    String senderId,
    String senderName,
    String receiverUserId,
    ui.RootIsolateToken rootIsolateToken, // ADD THIS PARAMETER
  ) async {
    final Map<String, dynamic> params = {
      'tempFilePathWithPart': tempFilePathWithPart,
      'originalFileName': originalFileName,
      'fileSize': fileSize,
      'senderId': senderId,
      'senderName': senderName,
      'receiverUserId': receiverUserId,
      '_appId': _appId,
      'rootIsolateToken': rootIsolateToken, // PASS THE TOKEN HERE
    };

    final result = await Isolate.run(
      () => _performFinalizeSaveInIsolate(params),
    );

    if (result != null && result.startsWith("Error:")) {
      onError?.call(result.substring(7));
      return null;
    }
    return result;
  }
}