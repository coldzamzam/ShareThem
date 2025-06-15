import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_shareit/protos/packet.pbenum.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';

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
                  
                  var fileIdx = _sharedFiles.indexWhere((f) =>
                      f.$1.fileName == originalFileName &&
                      f.$1.fileSize == sharedFileInfoFromChunk.fileSize &&
                      f.$2 < f.$1.fileSize);

                  if (fileIdx == -1) {
                    print("FileSharingReceiver: Received chunk for an unknown or already completed file '$originalFileName'. Discarding.");
                    break; 
                  }
                  
                  final String uniqueFileKey = '${originalFileName}_$fileIdx';
                  final String tempFilePath = p.join(_temporaryStoragePath!, '$uniqueFileKey.part');
                  
                  IOSink sink = _fileSinks[uniqueFileKey] ??= File(tempFilePath).openWrite(mode: FileMode.append);
                  sink.add(fileContent);

                  var (sharedFileFromList, receivedBytes) = _sharedFiles[fileIdx];
                  receivedBytes += fileContent.length;
                  _sharedFiles[fileIdx] = (sharedFileFromList, receivedBytes);
                  
                  onFileProgress?.call(List.from(_sharedFiles));

                  if (receivedBytes >= sharedFileFromList.fileSize) {
                    print('FileSharingReceiver: File $originalFileName (index: $fileIdx) received completely to temp. Path: $tempFilePath');
                    await sink.flush();
                    await sink.close();
                    _fileSinks.remove(uniqueFileKey);
                    
                    onFileReceivedToTemp?.call([sharedFileFromList, tempFilePath]);
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

  Future<List<Map<String, String>>> finalizeSaveAll(Map<String, String> tempPaths) async {
    // ADDED: Diagnostic log.
    print("FileSharingReceiver LOG: Starting finalizeSaveAll for ${tempPaths.length} files.");
    
    final List<Future<Map<String, String>?>> saveFutures = [];

    for (final entry in tempPaths.entries) {
      final tempFilePath = entry.key;
      final originalFileName = entry.value;

      final future = finalizeSave(tempFilePath, originalFileName).then((finalPath) {
        if (finalPath != null) {
          return {'name': originalFileName, 'path': finalPath};
        }
        return null;
      }).catchError((e) {
        print("Error saving $originalFileName from finalizeSaveAll: $e");
        return null;
      });
      
      saveFutures.add(future);
    }

    final results = await Future.wait(saveFutures);
    final successfulSaves = results.whereType<Map<String, String>>().toList();
    
    if (successfulSaves.length != tempPaths.length) {
      print("FileSharingReceiver: Some files failed to save.");
    }
    
    return successfulSaves;
  }

  Future<String?> finalizeSave(String tempFilePathWithPart, String originalFileName) async {
    // ADDED: Diagnostic log.
    print("FileSharingReceiver LOG: Starting finalizeSave for '$originalFileName' from path '$tempFilePathWithPart'.");

    final File tempFile = File(tempFilePathWithPart);
    if (!await tempFile.exists()) {
      onError?.call("Temporary file '$tempFilePathWithPart' not found for '$originalFileName'.");
      return null;
    }

    try {
      Directory? downloadsDir;
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        downloadsDir = await getDownloadsDirectory();
      } else {
         downloadsDir = await getApplicationDocumentsDirectory();
      }
      
      if (downloadsDir == null) {
        print("FileSharingReceiver: Could not determine a writable directory.");
        onError?.call("Could not determine a writable directory for '$originalFileName'.");
        return null;
      }

      String finalPath = p.join(downloadsDir.path, originalFileName);
      String baseName = p.basenameWithoutExtension(originalFileName);
      String extension = p.extension(originalFileName);
      int count = 1;

      while (await File(finalPath).exists()) {
        String newName = '$baseName ($count)$extension';
        finalPath = p.join(downloadsDir.path, newName);
        count++;
      }
      
      final Uint8List fileBytes = await tempFile.readAsBytes();
      final File finalFile = File(finalPath);
      await finalFile.writeAsBytes(fileBytes);

      print("FileSharingReceiver: File saved successfully to: '$finalPath'");
      await tempFile.delete();
      print("FileSharingReceiver: Temporary file '$tempFilePathWithPart' deleted.");
      return finalPath;

    } catch (e, s) {
      print("FileSharingReceiver: Error during finalizeSave: $e\n$s");
      String errorMessage = "Failed to save '$originalFileName': $e";
       if (Platform.isAndroid && e is FileSystemException) {
         if (e.osError?.errorCode == 13 || e.osError?.errorCode == 1) { // EACCES or EPERM
           errorMessage = "Failed to save '$originalFileName' due to permission issues on Android.";
         }
       }
      onError?.call(errorMessage);
      return null;
    }
  }
}
