import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_shareit/protos/packet.pbenum.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:archive/archive.dart';
import 'package:collection/collection.dart'; // <<< TAMBAHKAN INI UNTUK firstWhereOrNull

// Definisikan tipe alias untuk tuple agar lebih mudah dibaca dan diakses
typedef FileProcessingTuple = (IOSink sink, int receivedBytes, Crc32 crc, File tempFile);

class FileSharingReceiver {
  final int listenPort;
  ValueChanged<List<(SharedFile, int)>>? onFileProgress;
  ValueChanged<String>? onError;
  ValueChanged<List<dynamic>>? onFileReceivedToTemp;

  List<(SharedFile, int)> _sharedFiles = [];
  ServerSocket? _serverSocket;
  String? _temporaryStoragePath;

  final Map<String, FileProcessingTuple> _fileProcessingInfo = {};
  Socket? _currentSenderSocket;

  Uint8List? _tempBuffer;

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
    // Perbaikan: Tambahkan null check di sini juga
    if (_serverSocket == null && _fileProcessingInfo.isEmpty && _currentSenderSocket == null) {
      print("FileSharingReceiver: Already stopped or nothing to stop.");
      return;
    }
    try {
      await _serverSocket?.close();
      print("FileSharingReceiver: Server socket closed.");
    } catch (e) {
      print("FileSharingReceiver: Error closing server socket: $e");
    }
    _serverSocket = null;

    try {
      await _currentSenderSocket?.close();
      print("FileSharingReceiver: Current sender socket closed.");
    } catch (e) {
      print("FileSharingReceiver: Error closing sender socket: $e");
    }
    _currentSenderSocket = null;

    final List<String> processingKeys = _fileProcessingInfo.keys.toList();
    for (final key in processingKeys) {
      final info = _fileProcessingInfo[key];
      // Perbaikan: Tambahkan null check '!' karena info tidak mungkin null jika ada di map
      try {
        await info!.$1.close(); // Akses sink dengan .$1
        print("FileSharingReceiver: Closed sink for $key.");
        // Perbaikan: Tambahkan null check '!'
        if (info!.$4.existsSync()) { // Akses tempFile dengan .$4 dan cek eksistensi
            await info.$4.delete(); // Akses tempFile
            print("FileSharingReceiver: Deleted incomplete temp file: ${info.$4.path}"); // Akses tempFile path
        }
      } catch (e) {
        print("FileSharingReceiver: Error closing sink for $key: $e");
      }
    }
    _fileProcessingInfo.clear();
    _sharedFiles.clear();
    _tempBuffer = null;
    print("FileSharingReceiver: All resources cleaned. Receiver stopped.");
  }

  Future<void> start() async {
    print("FileSharingReceiver: start() called.");
    if (_serverSocket != null) {
      print("FileSharingReceiver: Receiver already running.");
      return;
    }

    await _prepareStoragePaths();
    if (_temporaryStoragePath == null) {
      onError?.call("Temporary storage path not available. Cannot start receiver.");
      return;
    }
    _sharedFiles.clear();
    _fileProcessingInfo.clear();
    _tempBuffer = null;

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
      _currentSenderSocket?.destroy();
      _currentSenderSocket = socket;

      _tempBuffer = null;

      _currentSenderSocket!.listen(
        (data) async {
          if (_tempBuffer != null) {
            data = Uint8List.fromList([..._tempBuffer!, ...data]);
            _tempBuffer = null;
          } else {
            data = Uint8List.fromList(data);
          }

          final bytes = data.buffer.asByteData();
          var offset = 0;

          while(true) {
            if (offset + 4 > bytes.lengthInBytes) {
              _tempBuffer = Uint8List.sublistView(data, offset);
              break;
            }

            final length = bytes.getUint32(offset);
            final headerAndPacketLength = 4 + 1 + length;

            if (offset + headerAndPacketLength > bytes.lengthInBytes) {
              _tempBuffer = Uint8List.sublistView(data, offset);
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
                    _tempBuffer = null; break;
                }
                continue;
            }
            
            final payloadOffset = offset + 4 + 1;
            final payload = Uint8List.sublistView(data, payloadOffset, payloadOffset + length);

            switch (packetType) {
              case EPacketType.GetSharedFilesReq:
                print("FileSharingReceiver: Received GetSharedFilesReq.");
                final rsp = GetSharedFilesRsp();
                final packet = makePacket(
                  EPacketType.GetSharedFilesRsp,
                  payload: rsp.writeToBuffer(),
                );
                _currentSenderSocket?.add(Uint8List.sublistView(packet));
                await _currentSenderSocket?.flush();
                print("FileSharingReceiver: Sent GetSharedFilesRsp.");
                break;

              case EPacketType.GetSharedFilesRsp:
                print("FileSharingReceiver: Received unexpected GetSharedFilesRsp.");
                break;

              case EPacketType.SharedFileContentNotify:
                if (_temporaryStoragePath == null) {
                  onError?.call("Temporary storage path not set. File chunk skipped.");
                  break;
                }
                try {
                  final fileChunk = SharedFileContentNotify.fromBuffer(payload);
                  
                  final SharedFile sharedFileInfoFromChunk = fileChunk.file;
                  final String originalFileName = sharedFileInfoFromChunk.fileName;
                  final fileContent = fileChunk.content;
                  
                  final String uniqueFileId = originalFileName; 

                  FileProcessingTuple? info = _fileProcessingInfo[uniqueFileId];

                  if (info == null) {
                    final tempFilePath = p.join(_temporaryStoragePath!, '$uniqueFileId.part');
                    final file = File(tempFilePath);
                    final sink = file.openWrite(mode: FileMode.writeOnlyAppend);
                    final crc = Crc32();
                    
                    info = (sink, 0, crc, file);
                    _fileProcessingInfo[uniqueFileId] = info;

                    if (!_sharedFiles.any((f) => f.$1.fileName == originalFileName)) {
                        _sharedFiles.add((sharedFileInfoFromChunk, 0));
                    }
                    print("FileSharingReceiver: Started receiving new file: $originalFileName to $tempFilePath");
                  }

                  // Akses elemen tuple dengan indeks
                  info.$1.add(fileContent);
                  info.$3.add(fileContent);
                  
                  // Buat tuple baru dengan byte yang diupdate
                  info = (info.$1, info.$2 + fileContent.length, info.$3, info.$4);
                  _fileProcessingInfo[uniqueFileId] = info;

                  final indexInSharedFiles = _sharedFiles.indexWhere((f) => f.$1.fileName == originalFileName);
                  if (indexInSharedFiles != -1) {
                    _sharedFiles[indexInSharedFiles] = (sharedFileInfoFromChunk, info.$2);
                  } else {
                    _sharedFiles.add((sharedFileInfoFromChunk, info.$2));
                  }
                  onFileProgress?.call(List.from(_sharedFiles));

                  // Cek jika file selesai
                  if (info.$2 >= sharedFileInfoFromChunk.fileSize) {
                    print('FileSharingReceiver: File $originalFileName received completely to temp. Path: ${info.$4.path}');
                    await info.$1.flush();
                    await info.$1.close();
                    _fileProcessingInfo.remove(uniqueFileId);
                    
                    final calculatedCrc = info.$3.hash;
                    final isCrcMatch = calculatedCrc == sharedFileInfoFromChunk.fileCrc;
                    print("File ${sharedFileInfoFromChunk.fileName} completed. Calculated CRC: $calculatedCrc, Expected CRC: ${sharedFileInfoFromChunk.fileCrc}. Match: $isCrcMatch");

                    final completedNotify = SharedFileCompletedNotify(
                      fileName: originalFileName,
                      success: isCrcMatch,
                      message: isCrcMatch ? "File received successfully." : "CRC mismatch, file corrupted.",
                    );
                    final packet = makePacket(
                      EPacketType.SharedFileCompletedNotify,
                      payload: completedNotify.writeToBuffer(),
                    );
                    _currentSenderSocket?.add(Uint8List.sublistView(packet));
                    await _currentSenderSocket?.flush();
                    print("FileSharingReceiver: Sent SharedFileCompletedNotify for $originalFileName (Success: $isCrcMatch).");

                    if (isCrcMatch) {
                      onFileReceivedToTemp?.call([sharedFileInfoFromChunk, info.$4.path]);
                    } else {
                      onError?.call("File '$originalFileName' corrupted due to CRC mismatch. Deleted temporary file.");
                      try {
                        await info.$4.delete();
                        print("FileSharingReceiver: Deleted corrupted file: ${info.$4.path}");
                      } catch (e) {
                        print("FileSharingReceiver: Error deleting corrupted file: $e");
                      }
                    }
                  }
                  
                } catch (e, s) {
                  print("FileSharingReceiver: Error processing SharedFileContentNotify for chunk: $e\n$s");
                  onError?.call("Error processing file chunk: $e");
                }
                break;

              case EPacketType.SharedFileCompletedNotify:
                print("FileSharingReceiver: Received unexpected SharedFileCompletedNotify by receiver from sender.");
                break;

              default:
                print("FileSharingReceiver: Invalid EPacketType received: $packetType (byte: $packetTypeByte)");
                break;
            }
            offset += headerAndPacketLength;
            if (offset >= bytes.lengthInBytes) {
                _tempBuffer = null; break;
            }
          }
        },
        onDone: () {
          print('FileSharingReceiver: Connection closed by client: ${_currentSenderSocket?.remoteAddress.address}:${_currentSenderSocket?.remotePort}');
          _currentSenderSocket = null;
          _fileProcessingInfo.forEach((key, info) async {
            // Perbaikan: Gunakan firstWhereOrNull untuk menghindari error jika file tidak ditemukan
            final SharedFile? originalFileMeta = _sharedFiles.firstWhereOrNull((f) => f.$1.fileName == key)?.$1;

            if (originalFileMeta != null && info.$2 < originalFileMeta.fileSize) {
                print("FileSharingReceiver: Incomplete file '$key' detected on connection done. Closing sink.");
                await info.$1.close();
                try {
                    final tempFile = info.$4;
                    if (await tempFile.existsSync()) { // Perbaikan: Tambahkan .existsSync()
                        await tempFile.delete();
                        print("FileSharingReceiver: Deleted incomplete file '${tempFile.path}'.");
                    }
                } catch (e) {
                    print("FileSharingReceiver: Error deleting incomplete file '$key': $e");
                }
            } else if (originalFileMeta == null) {
                print("FileSharingReceiver: Processing info for '$key' exists, but sharedFileMeta not found. Closing sink.");
                await info.$1.close();
                 try {
                    final tempFile = info.$4;
                    if (await tempFile.existsSync()) { // Perbaikan: Tambahkan .existsSync()
                        await tempFile.delete();
                        print("FileSharingReceiver: Deleted temp file with no meta: '${tempFile.path}'.");
                    }
                } catch (e) {
                    print("FileSharingReceiver: Error deleting temp file with no meta '$key': $e");
                }
            }
          });
          _fileProcessingInfo.clear();
          _sharedFiles.clear();
          onFileProgress?.call(List.from(_sharedFiles));
        },
        onError: (error, stackTrace) {
          print('FileSharingReceiver: Socket error: $error\n$stackTrace');
          _currentSenderSocket?.destroy();
          _currentSenderSocket = null;
          onError?.call("Network connection error: $error");
          _fileProcessingInfo.clear();
          _sharedFiles.clear();
          onFileProgress?.call(List.from(_sharedFiles));
        },
        cancelOnError: true,
      );
    });
  }

  Future<String?> finalizeSave(String tempFilePathWithPart, String originalFileName) async {
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

  Future<List<Map<String, String>>> finalizeSaveAll(Map<String, String> tempPaths) async {
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
}