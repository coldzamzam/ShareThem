import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart'; // ValueChanged
import 'package:path_provider/path_provider.dart'; // Added for getDownloadsDirectory
import 'package:path/path.dart' as p; // Import package path
// import 'package:file_saver/file_saver.dart'; // REMOVED file_saver

// Diasumsikan proto dan packet util ada di path yang benar relatif terhadap file ini
// Sesuaikan import jika struktur proyek Anda berbeda
import 'package:flutter_shareit/protos/packet.pbenum.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';

class FileSharingReceiver {
  final int listenPort;
  ValueChanged<List<(SharedFile, int)>>? onFileProgress;
  ValueChanged<String>? onError;
  ValueChanged<List<dynamic>>? onFileReceivedToTemp;

  List<(SharedFile, int)> _sharedFiles = [];
  ServerSocket? _serverSocket;
  String? _temporaryStoragePath;

  final Map<String, IOSink> _fileSinks = {};

  FileSharingReceiver({
    this.listenPort = SharingDiscoveryService.servicePort,
    this.onFileProgress,
    this.onError,
    this.onFileReceivedToTemp,
  });

  Future<void> _prepareStoragePaths() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _temporaryStoragePath = tempDir.path;
      print('FileSharingReceiver: Temporary files will be stored in: $_temporaryStoragePath');
    } catch (e) {
      print("FileSharingReceiver: Error preparing temporary storage path: $e");
      onError?.call("Failed to prepare temporary storage directory: $e");
      _temporaryStoragePath = null;
    }
  }

  Future<void> stop() async {
    print("FileSharingReceiver: stop() called.");
    if (_serverSocket == null && _fileSinks.isEmpty) {
      print("FileSharingReceiver: Already stopped or nothing to stop.");
    }
    try {
      await _serverSocket?.close();
      print("FileSharingReceiver: Server socket closed.");
    } catch (e) {
      print("FileSharingReceiver: Error closing server socket: $e");
    }
    _serverSocket = null;

    final List<String> sinkKeys = _fileSinks.keys.toList();
    for (final key in sinkKeys) {
      final sink = _fileSinks[key];
      try {
        await sink?.close();
        print("FileSharingReceiver: Closed sink for $key.");
      } catch (e) {
        print("FileSharingReceiver: Error closing sink for $key: $e");
      }
    }
    _fileSinks.clear();
    print("FileSharingReceiver: All sinks closed and cleared. Receiver stopped.");
  }

  Future<void> start() async {
    print("FileSharingReceiver: start() called.");
    if (_serverSocket != null) {
      print("FileSharingReceiver: Receiver already running.");
      return;
    }

    await _prepareStoragePaths();
    if (_temporaryStoragePath == null) {
      print("FileSharingReceiver: Temporary storage path not available. Receiver cannot start.");
      onError?.call("Temporary storage path not available. Cannot start receiver.");
      return;
    }
    _sharedFiles.clear();
    if (_fileSinks.isNotEmpty) {
        print("FileSharingReceiver: Warning - _fileSinks was not empty at start. Clearing now.");
        final List<String> sinkKeys = _fileSinks.keys.toList();
        for (final key in sinkKeys) {
            try {
                await _fileSinks[key]?.close();
            } catch (e) {/* ignore */}
        }
        _fileSinks.clear();
    }

    print("FileSharingReceiver: Attempting to bind server socket on port $listenPort.");
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        listenPort,
      );
      print('FileSharingReceiver: Server socket bound successfully on port $listenPort. Listening for connections...');
    } catch (e) {
      print("FileSharingReceiver: Error binding server socket: $e");
      onError?.call("Failed to start receiver: $e");
      return;
    }

    _serverSocket!.listen((socket) {
      print('FileSharingReceiver: Connection received from ${socket.remoteAddress.address}:${socket.remotePort}');
      Uint8List? tempBuf;

      socket.listen(
        (data) async {
          if (tempBuf != null) {
            data = Uint8List.fromList([...tempBuf!, ...data]);
            tempBuf = null;
          } else {
            data = Uint8List.fromList(data);
          }

          final bytes = data.buffer.asByteData();
          var offset = 0;

          while(true) {
            if (offset + 4 > bytes.lengthInBytes) {
              tempBuf = Uint8List.sublistView(data, offset);
              break;
            }

            final length = bytes.getUint32(offset);
            final headerAndPacketLength = 4 + 1 + length;

            if (offset + headerAndPacketLength > bytes.lengthInBytes) {
              tempBuf = Uint8List.sublistView(data, offset);
              break;
            }

            final packetTypeByte = bytes.getUint8(offset + 4);
            EPacketType? packetType;
            try {
                packetType = EPacketType.valueOf(packetTypeByte);
            } catch (e) {
                print("FileSharingReceiver: Unknown EPacketType byte: $packetTypeByte. Skipping.");
                offset += headerAndPacketLength;
                if (offset >= bytes.lengthInBytes) {
                    tempBuf = null; break;
                }
                continue;
            }
            
            final payloadOffset = offset + 4 + 1;

            switch (packetType) {
              case EPacketType.GetSharedFilesRsp:
                try {
                  final filesRsp = GetSharedFilesRsp.fromBuffer(
                    Uint8List.sublistView(data, payloadOffset, payloadOffset + length),
                  );
                  print("FileSharingReceiver: GetSharedFilesRsp - Received with files: ${filesRsp.files.map((f) => f.fileName).toList()}");

                  Map<String, int> existingProgressMap = {}; 
                  for (var existingFileTuple in _sharedFiles) {
                      existingProgressMap["${existingFileTuple.$1.fileName}|${existingFileTuple.$1.fileSize}"] = existingFileTuple.$2;
                  }

                  List<(SharedFile, int)> newMasterList = [];
                  bool structureChanged = false; 

                  if (filesRsp.files.isEmpty && _sharedFiles.isEmpty) {
                      print("FileSharingReceiver: GetSharedFilesRsp - Both new and old lists are empty.");
                  } else {
                      for (var fileMetaFromRsp in filesRsp.files) {
                          String key = "${fileMetaFromRsp.fileName}|${fileMetaFromRsp.fileSize}";
                          int progress = existingProgressMap[key] ?? 0; 
                          newMasterList.add((fileMetaFromRsp, progress));
                      }

                      if (newMasterList.length != _sharedFiles.length) {
                          structureChanged = true;
                      } else {
                          for (int i = 0; i < newMasterList.length; i++) {
                              if (newMasterList[i].$1.fileName != _sharedFiles[i].$1.fileName ||
                                  newMasterList[i].$1.fileSize != _sharedFiles[i].$1.fileSize) {
                                  structureChanged = true;
                                  break;
                              }
                          }
                      }
                       _sharedFiles = newMasterList; 
                  }
                  
                  if (structureChanged) {
                      print("FileSharingReceiver: GetSharedFilesRsp - _sharedFiles list structure was updated or reordered.");
                  } else {
                      print("FileSharingReceiver: GetSharedFilesRsp - _sharedFiles list structure and progress preserved or initialized empty.");
                  }
                  onFileProgress?.call(List.from(_sharedFiles));

                } catch (e, s) {
                  print("FileSharingReceiver: Error parsing GetSharedFilesRsp: $e\n$s");
                  onError?.call("Error processing file list: $e");
                }
                break;

              case EPacketType.SharedFileContentNotify:
                if (_temporaryStoragePath == null) {
                  onError?.call("Temporary storage path not set. File chunk skipped.");
                  break;
                }
                try {
                  final fileChunk = SharedFileContentNotify.fromBuffer(
                    Uint8List.sublistView(data, payloadOffset, payloadOffset + length),
                  );
                  final SharedFile sharedFileInfoFromChunk = fileChunk.file;
                  final String originalFileName = sharedFileInfoFromChunk.fileName;
                  final fileContent = fileChunk.content;

                  final fileIdx = _sharedFiles.indexWhere(
                    (f) => f.$1.fileName == originalFileName && f.$1.fileSize == sharedFileInfoFromChunk.fileSize,
                  );

                  if (fileIdx != -1) {
                    final String tempFilePath = p.join(_temporaryStoragePath!, '$originalFileName.part');
                    IOSink sink = _fileSinks[originalFileName] ??= File(tempFilePath).openWrite(mode: FileMode.append);
                    sink.add(fileContent);

                    var (sharedFileFromList, receivedBytes) = _sharedFiles[fileIdx];
                    receivedBytes += fileContent.length;
                    _sharedFiles[fileIdx] = (sharedFileFromList, receivedBytes);
                    
                    onFileProgress?.call(List.from(_sharedFiles));

                    if (receivedBytes >= sharedFileFromList.fileSize) {
                      print('FileSharingReceiver: File $originalFileName received completely to temp. Path: $tempFilePath');
                      await sink.flush();
                      await sink.close();
                      _fileSinks.remove(originalFileName);
                      onFileReceivedToTemp?.call([sharedFileFromList, tempFilePath]);
                    }
                  } else {
                     print("FileSharingReceiver: Received chunk for unknown file: '$originalFileName'. Current files: ${_sharedFiles.map((f)=>f.$1.fileName).toList()}");
                  }
                } catch (e, s) {
                  print("FileSharingReceiver: Error processing SharedFileContentNotify: $e\n$s");
                  onError?.call("Error saving file chunk to temp: $e");
                }
                break;
              default:
                print("FileSharingReceiver: Invalid EPacketType received: $packetType (byte: $packetTypeByte)");
                break;
            }
            offset += headerAndPacketLength;
            if (offset >= bytes.lengthInBytes) {
                tempBuf = null; break;
            }
          }
        },
        onDone: () {
          print('FileSharingReceiver: Connection closed by client: ${socket.remoteAddress.address}:${socket.remotePort}');
        },
        onError: (error, stackTrace) {
          print('FileSharingReceiver: Socket error: $error\n$stackTrace');
          socket.destroy();
          onError?.call("Network connection error: $error");
        },
        cancelOnError: true,
      );

      try {
        print("FileSharingReceiver: Sending GetSharedFilesReq to ${socket.remoteAddress.address}");
        final packet = makePacket(EPacketType.GetSharedFilesReq);
        socket.add(Uint8List.sublistView(packet));
      } catch (e) {
        print("FileSharingReceiver: Error sending GetSharedFilesReq: $e");
        onError?.call("Failed to request file list: $e");
      }
    });
  }

  // _getMimeType was used by FileSaver, can be removed if not used elsewhere.
  // String _getMimeType(String fileName) { ... }


  Future<String?> finalizeSave(String tempFilePathWithPart, String originalFileName) async {
    final File tempFile = File(tempFilePathWithPart);
    if (!await tempFile.exists()) {
      onError?.call("Temporary file '$tempFilePathWithPart' not found for '$originalFileName'.");
      return null;
    }

    try {
      Directory? downloadsDir;
      if (Platform.isIOS) {
        // getDownloadsDirectory() returns null on iOS. 
        // You'll need a different strategy for iOS, e.g., save to app documents or use a picker.
        print("FileSharingReceiver: getDownloadsDirectory() is not supported on iOS. File cannot be saved to Downloads automatically.");
        onError?.call("Saving to Downloads directory is not supported on iOS. File: '$originalFileName'.");
        return null; 
      } else {
        downloadsDir = await getDownloadsDirectory();
      }
      
      if (downloadsDir == null) {
        // This might happen on other platforms if the directory can't be determined.
        print("FileSharingReceiver: Could not determine downloads directory for '$originalFileName'.");
        onError?.call("Could not determine downloads directory. Save failed for '$originalFileName'.");
        return null;
      }

      // Ensure the downloads directory exists (it usually does, but good for robustness)
      if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
      }
      
      String finalFilePath = p.join(downloadsDir.path, originalFileName);
      int count = 1;
      String tempName = originalFileName;
      String extension = p.extension(originalFileName);
      String baseName = p.basenameWithoutExtension(originalFileName);

      // Basic name collision handling: appends (1), (2), etc.
      while (await File(finalFilePath).exists()) {
          tempName = '$baseName ($count)$extension';
          finalFilePath = p.join(downloadsDir.path, tempName);
          count++;
      }
      // If tempName changed, originalFileName for logging/return should reflect the new name.
      // However, we'll use finalFilePath for actual saving and return.
      if (tempName != originalFileName) {
          print("FileSharingReceiver: File name collision. Saving as '$tempName' instead of '$originalFileName'.");
      }


      print("FileSharingReceiver: Reading temporary file '$tempFilePathWithPart' into bytes.");
      final Uint8List fileBytes = await tempFile.readAsBytes();
      print("FileSharingReceiver: Temporary file read successfully. Byte length: ${fileBytes.length}");

      print("FileSharingReceiver: Attempting to save '$tempName' to: '$finalFilePath'");
      
      final File finalFile = File(finalFilePath);
      await finalFile.writeAsBytes(fileBytes);

      print("FileSharingReceiver: File '$tempName' saved successfully to: '$finalFilePath'");
      await tempFile.delete();
      print("FileSharingReceiver: Temporary file '$tempFilePathWithPart' deleted.");
      return finalFilePath; // Return the actual path where the file was saved

    } catch (e, s) {
      print("FileSharingReceiver: Error during finalizeSave to downloads directory for '$originalFileName': $e\n$s");
      String errorMessage = "Failed to save '$originalFileName' to Downloads: $e";
      if (Platform.isAndroid && e is FileSystemException) {
        if (e.osError?.errorCode == 13 || e.osError?.errorCode == 1) { // EACCES (Permission denied) or EPERM (Operation not permitted)
            errorMessage = "Failed to save '$originalFileName'. Permission denied. On modern Android, direct writes to public Downloads are restricted. The file might be in an app-specific 'Downloads' folder if available, or this operation failed.";
        }
      }
      onError?.call(errorMessage);
      return null;
    }
  }
}