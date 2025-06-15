import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // For Isolate.run
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart'; // For ValueChanged, VoidCallback
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/protos/packet.pbenum.dart'; // EPacketType
import 'package:flutter_shareit/protos/packet.pb.dart'; // Packet, GetSharedFilesRsp, SharedFileContentNotify
import 'package:flutter_shareit/utils/file_sharing/packet.dart'; // Your makePacket function (ensure it also uses Endian.little)
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:flutter_shareit/models/received_file_entry.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_shareit/firebase_options.dart';
import 'package:flutter/services.dart'; // Import for BackgroundIsolateBinaryMessenger
import 'dart:ui' as ui; // Import for ui.RootIsolateToken
import 'dart:math'; // For min function in logging


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
  final ui.RootIsolateToken? rootIsolateToken = params['rootIsolateToken'] as ui.RootIsolateToken?;

  if (rootIsolateToken == null) {
    print("Isolate: Error: RootIsolateToken is null. Cannot initialize BackgroundIsolateBinaryMessenger.");
    return "Error: Failed to initialize background services for file save.";
  }

  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

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
    return "Error: Temporary file '$tempFilePathWithPart' not found. It might have been deleted.";
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
      .collection('users')
      .doc(receiverUserId)
      .collection('savedFiles')
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
          "Failed to save '$originalFileName' due to permission issues on Android. Please grant storage permissions in app settings.";
      }
    }
    return "Error: $errorMessage";
  }
}

// --- FILE SHARING RECEIVER CLASS ---

typedef FileProgressCallback = void Function(List<(SharedFile, int)>);
typedef FileReceivedToTempCallback = void Function(List<dynamic>);
typedef TransferCompleteCallback = void Function();
typedef ErrorCallback = void Function(String);

class FileSharingReceiver {
  final int listenPort;

  final FileProgressCallback? onFileProgress;
  final ErrorCallback? onError;
  final FileReceivedToTempCallback? onFileReceivedToTemp;
  final TransferCompleteCallback? onTransferComplete;

  Map<
    String,
    ({SharedFile sharedFile, int receivedBytes, bool isCompletedAndNotified})
  > _sharedFilesStatus = {};

  ServerSocket? _serverSocket;
  Socket? _currentClientSocket;
  StreamSubscription<Uint8List>? _socketSubscription;

  String? _temporaryStoragePath;

  final Map<String, IOSink> _fileSinks = {};
  Uint8List _incomingBuffer = Uint8List(0); // This buffer accumulates all incoming bytes

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

    _incomingBuffer = Uint8List(0); // Clear buffer on full stop
    _sharedFilesStatus.clear(); // Clear all file statuses

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
    _incomingBuffer = Uint8List(0); // Reset buffer for new start

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
      _incomingBuffer = Uint8List(0); // Clear buffer for new connection

      _socketSubscription = _currentClientSocket!.listen(
        (data) async {
          // Append newly received data to the incoming buffer
          _incomingBuffer = Uint8List.fromList([..._incomingBuffer, ...data]);
          print("FileSharingReceiver: Received ${data.length} bytes. Total buffer size: ${_incomingBuffer.length} bytes.");

          // bytesProcessedInThisLoop tracks how many bytes we've successfully parsed
          // from the *current* _incomingBuffer's start (index 0) in this processing cycle.
          int bytesConsumedInThisLoop = 0; 

          while (true) {
            // Log current buffer state before attempting to parse
            if (_incomingBuffer.lengthInBytes > bytesConsumedInThisLoop) {
                print("FileSharingReceiver: Current buffer state before next packet attempt (from offset $bytesConsumedInThisLoop):");
                final int printLength = min(30, _incomingBuffer.lengthInBytes - bytesConsumedInThisLoop);
                final String hexBytes = _incomingBuffer.sublist(bytesConsumedInThisLoop, bytesConsumedInThisLoop + printLength)
                                        .map((b) => b.toRadixString(16).padLeft(2, '0'))
                                        .join(' ');
                print("  Raw bytes (first $printLength): $hexBytes");
            }

            // Check if there are enough bytes for the packet length (4 bytes)
            if (bytesConsumedInThisLoop + 4 > _incomingBuffer.lengthInBytes) {
              print("FileSharingReceiver: Not enough bytes for length header at offset $bytesConsumedInThisLoop. Buffer size: ${_incomingBuffer.lengthInBytes}. Breaking loop (awaiting more data).");
              break; // Not enough data for a full header, wait for more
            }

            // Read packet length with explicit Endian.little
            final ByteData currentPacketLengthView = ByteData.view(
                _incomingBuffer.buffer,
                _incomingBuffer.offsetInBytes + bytesConsumedInThisLoop, // Use the current read pointer
                4 // Length of the header (4 bytes for packetLength)
            );
            final int packetLength = currentPacketLengthView.getUint32(0, Endian.little); // <--- ENSURE Endian.little HERE

            // Calculate the total size of the packet (4 bytes length + 1 byte type + payloadLength)
            final int headerAndPacketLength = 4 + 1 + packetLength;

            // Validate packet length to prevent potential overflow or malicious data
            // Max 100MB per payload is a reasonable limit for typical file sharing chunks
            if (packetLength < 0 || packetLength > 100 * 1024 * 1024) {
                onError?.call("Received invalid packet length: $packetLength. Data stream corrupted.");
                print("FileSharingReceiver: Invalid packet length detected: $packetLength. Discarding remaining buffer.");
                _incomingBuffer = Uint8List(0); // Clear buffer on severe corruption
                return; // Stop parsing this batch of data, await next 'data' event
            }

            // Check if there are enough bytes for the entire packet (header + payload)
            if (bytesConsumedInThisLoop + headerAndPacketLength > _incomingBuffer.lengthInBytes) {
              print("FileSharingReceiver: Not enough bytes for full packet. Remaining: ${_incomingBuffer.lengthInBytes - bytesConsumedInThisLoop}. Expected: $headerAndPacketLength. Breaking loop (awaiting more data).");
              break; // Not enough data for the full packet, wait for more
            }

            // Read the packet type byte
            final packetTypeByte = _incomingBuffer[bytesConsumedInThisLoop + 4];
            print("FileSharingReceiver: Attempting to parse packet at offset $bytesConsumedInThisLoop. Declared Payload Length: $packetLength. Declared Packet Type Byte: $packetTypeByte.");

            EPacketType? packetType;
            try {
              packetType = EPacketType.valueOf(packetTypeByte);
              print("FileSharingReceiver: Successfully mapped byte $packetTypeByte to EPacketType.$packetType.");
            } catch (e) {
              // If the byte doesn't map to a known EPacketType, it's likely corruption or desynchronization
              print("FileSharingReceiver: **ERROR**: Failed to map byte $packetTypeByte to EPacketType. Error: $e");
              print("FileSharingReceiver: This usually indicates desynchronization or corrupted data. Advancing by 1 byte to try resynchronization.");
              bytesConsumedInThisLoop += 1; // Try to resynchronize by skipping a single byte
              continue; // Continue to the next iteration to parse from the new offset
            }

            // Extract the payload bytes (skip 4 bytes for length and 1 for type)
            final payloadStartOffset = bytesConsumedInThisLoop + 4 + 1;
            final Uint8List payloadBytes = _incomingBuffer.sublist(
              payloadStartOffset,
              payloadStartOffset + packetLength,
            );
            
            print('FileSharingReceiver: Processed packet of type $packetType, length $packetLength at offset $bytesConsumedInThisLoop. Payload bytes start at $payloadStartOffset.');

            // Process the packet based on its type
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
                  onError?.call("Error processing file list from sender: $e");
                }
                break;

              case EPacketType.SharedFileContentNotify:
                if (_temporaryStoragePath == null) {
                  onError?.call("Temporary storage path not set. File chunk skipped.");
                  bytesConsumedInThisLoop += headerAndPacketLength;
                  continue;
                }
                SharedFileContentNotify? fileChunk;
                try {
                  fileChunk = SharedFileContentNotify.fromBuffer(payloadBytes);
                  final SharedFile sharedFileInfoFromChunk = fileChunk.file;
                  final String originalFileName = sharedFileInfoFromChunk.fileName;
                  final fileContent = fileChunk.content;

                  var fileStatus = _sharedFilesStatus[originalFileName];

                  if (fileStatus != null && fileStatus.isCompletedAndNotified) {
                    print("FileSharingReceiver: Ignoring processing for already completed/handled file: $originalFileName. No longer expecting content. (Received ${fileContent.length} extra bytes)");
                    final IOSink? existingSink = _fileSinks.remove(originalFileName);
                    if (existingSink != null) {
                        print("FileSharingReceiver: Attempting to close lingering sink for $originalFileName upon receiving extra data.");
                        try {
                            await existingSink.flush();
                            await existingSink.close();
                            print("FileSharingReceiver: Lingering sink for $originalFileName successfully closed.");
                        } catch (e) {
                            print("FileSharingReceiver: Error during closing lingering sink for $originalFileName: $e");
                        }
                    }
                    bytesConsumedInThisLoop += headerAndPacketLength;
                    continue; // Skip this chunk, process next packet
                  }

                  if (fileStatus == null) {
                    print("FileSharingReceiver: Warning: Received content for unknown file '$originalFileName'. Initializing status.");
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
                  
                  sink.add(fileContent);

                  onFileProgress?.call(
                    _sharedFilesStatus.values.map((s) => (s.sharedFile, s.receivedBytes)).toList()
                  );

                  if (currentReceivedBytes >= sharedFileInfoFromChunk.fileSize && !fileStatus.isCompletedAndNotified) {
                    print('FileSharingReceiver: File $originalFileName received completely to temp. Path: $tempFilePath');

                    _sharedFilesStatus[originalFileName] = (
                      sharedFile: fileStatus.sharedFile,
                      receivedBytes: currentReceivedBytes,
                      isCompletedAndNotified: true
                    );

                    final sinkToClose = _fileSinks.remove(originalFileName);
                    if (sinkToClose != null) {
                      try {
                        await sinkToClose.flush();
                        await sinkToClose.close();
                        print("FileSharingReceiver: Sink for $originalFileName successfully closed after full reception.");
                      } catch (e) {
                        print("FileSharingReceiver: Primary error closing sink for $originalFileName after completion: $e");
                        onError?.call("Failed to finalize temporary file for '$originalFileName': $e");
                      }
                    } else {
                        print("FileSharingReceiver: Warning: Sink for $originalFileName was null after full reception or already removed. (Race condition or double close attempt avoided)");
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

                  final sinkOnError = _fileSinks.remove(fileNameForError);
                  if (sinkOnError != null) {
                    try {
                      await sinkOnError.flush();
                      await sinkOnError.close();
                      print("FileSharingReceiver: Sink for $fileNameForError successfully closed on error.");
                    } catch (closeError) {
                      print("FileSharingReceiver: Error closing sink for $fileNameForError in error handler: $closeError");
                    }
                  }
                  bytesConsumedInThisLoop += headerAndPacketLength;
                  continue;
                }
                break;

             case EPacketType.FileTransferCompleteNotify:
                print("FileSharingReceiver: <<< RECEIVED FILE_TRANSFER_COMPLETE_NOTIFY >>>");

                final List<String> pendingKeys = _fileSinks.keys.toList();
                for (var key in pendingKeys) {
                  final sink = _fileSinks[key];
                  if (sink != null) {
                    try {
                      await sink.flush();
                      await sink.close();
                      print("FileSharingReceiver: Closed remaining sink for $key.");
                    } catch (e) {
                      print("FileSharingReceiver: Error closing remaining sink for $key: $e");
                      onError?.call("Error during final cleanup of file '$key': $e");
                    }
                  }
                }
                _fileSinks.clear();

                onTransferComplete?.call();

                await _currentClientSocket?.close();
                print("FileSharingReceiver: Client socket closed by receiver after FileTransferCompleteNotify.");
                await _socketSubscription?.cancel();
                _socketSubscription = null;
                _currentClientSocket = null;
                break;

              case EPacketType.None:
                print(
                  "FileSharingReceiver: Received EPacketType.None (byte: $packetTypeByte). This usually means an uninitialized packet type or an unexpected value. Ignoring.",
                );
                bytesConsumedInThisLoop += headerAndPacketLength;
                continue;

              default:
                print(
                  "FileSharingReceiver: Unexpected EPacketType received: $packetType (byte: $packetTypeByte). Ignoring.",
                );
                bytesConsumedInThisLoop += headerAndPacketLength;
                continue;
            }
            // Advance bytesConsumedInThisLoop for the successfully processed packet
            bytesConsumedInThisLoop += headerAndPacketLength;
          }

          // After the loop, trim the buffer to remove processed bytes
          if (bytesConsumedInThisLoop > 0) {
            _incomingBuffer = _incomingBuffer.sublist(bytesConsumedInThisLoop);
            print('FileSharingReceiver: Trimmed buffer by $bytesConsumedInThisLoop bytes. New buffer size: ${_incomingBuffer.length}');
          } else {
            print('FileSharingReceiver: No full packets parsed in this iteration. Buffer size: ${_incomingBuffer.length}');
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
              'Connection closed unexpectedly during transfer. Not all files may have been sent or finalized.',
            );
          }

          for (var key in _fileSinks.keys.toList()) {
            final sink = _fileSinks[key];
            if (sink != null) {
              try {
                await sink.flush();
                await sink.close();
                print("FileSharingReceiver: Closed remaining sink for $key in onDone.");
              } catch (e) {
                print(
                  "FileSharingReceiver: Error closing sink for $key in onDone handler: $e",
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
                await sink.flush();
                await sink.close();
                print("FileSharingReceiver: Closed remaining sink for $key in onError.");
              } catch (e) {
                print(
                  "FileSharingReceiver: Error closing sink for $key in onError handler: $e",
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
        _currentClientSocket?.add(packet.buffer.asUint8List());
        _currentClientSocket?.flush();
      } catch (e) {
        print("FileSharingReceiver: Error sending GetSharedFilesReq: $e");
        onError?.call("Failed to request file list from sender: $e");
        _currentClientSocket?.destroy();
        _currentClientSocket = null;
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
    ui.RootIsolateToken rootIsolateToken,
  ) async {
    final Map<String, dynamic> params = {
      'tempFilePathWithPart': tempFilePathWithPart,
      'originalFileName': originalFileName,
      'fileSize': fileSize,
      'senderId': senderId,
      'senderName': senderName,
      'receiverUserId': receiverUserId,
      'rootIsolateToken': rootIsolateToken,
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