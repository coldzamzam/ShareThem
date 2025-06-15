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
import 'package:collection/collection.dart';

typedef FileProcessingTuple = (IOSink sink, int receivedBytes, Crc32 crc, File tempFile);

class FileSharingReceiver {
  final int listenPort;
  ValueChanged<List<(SharedFile, int)>>? onFileProgress;
  ValueChanged<String>? onError;
  ValueChanged<List<dynamic>>? onFileReceivedToTemp;

  // _sharedFiles ini akan dikelola oleh ReceiveScreen, bukan oleh Receiver itu sendiri.
  // Receiver hanya akan memanggil onFileProgress untuk memberi tahu ReceiveScreen tentang update.
  // List<(SharedFile, int)> _sharedFiles = []; // Ini dihapus dari Receiver

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
      try {
        await info!.$1.close(); // Akses sink dengan .$1
        print("FileSharingReceiver: Closed sink for $key.");
        // Hapus hanya file yang TIDAK selesai atau ada error
        // File yang sudah sukses harusnya sudah dihapus dari _fileProcessingInfo
        // atau sudah dipindahkan/ditandai di ReceiveScreen.
        if (info!.$4.existsSync()) {
            await info.$4.delete();
            print("FileSharingReceiver: Deleted incomplete/error temp file: ${info.$4.path}");
        }
      } catch (e) {
        print("FileSharingReceiver: Error closing sink for $key: $e");
      }
    }
    _fileProcessingInfo.clear(); // Bersihkan map untuk file yang masih diproses
    // _sharedFiles.clear(); // Hapus baris ini dari Receiver! ReceiveScreen yang akan mengelolanya
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
    // _sharedFiles.clear(); // Hapus ini dari Receiver
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

    _serverSocket!.listen((socket) async {
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
                print("FileSharingReceiver: Received GetSharedFilesReq from sender.");
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
                try {
                  final filesRsp = GetSharedFilesRsp.fromBuffer(payload);
                  print("FileSharingReceiver: GetSharedFilesRsp - Received with files: ${filesRsp.files.map((f) => f.fileName).toList()}");

                  // Kirim daftar file ini ke ReceiveScreen melalui onFileProgress
                  // Biarkan ReceiveScreen yang mengelola _sharedFiles-nya sendiri
                  onFileProgress?.call(filesRsp.files.map((f) => (f, 0)).toList()); 

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
                  final fileChunk = SharedFileContentNotify.fromBuffer(payload);
                  
                  final SharedFile sharedFileInfoFromChunk = fileChunk.file;
                  final String originalFileName = sharedFileInfoFromChunk.fileName;
                  final fileContent = fileChunk.content;
                  
                  final String uniqueFileKey = originalFileName; 

                  FileProcessingTuple? info = _fileProcessingInfo[uniqueFileKey];

                  if (info == null) {
                    final tempFilePath = p.join(_temporaryStoragePath!, '$uniqueFileKey.part');
                    final file = File(tempFilePath);
                    final sink = file.openWrite(mode: FileMode.writeOnlyAppend);
                    final crc = Crc32();
                    
                    info = (sink, 0, crc, file);
                    _fileProcessingInfo[uniqueFileKey] = info;

                    // Tidak menambahkan ke _sharedFiles di sini. ReceiveScreen akan mengelolanya saat menerima GetSharedFilesRsp.
                    print("FileSharingReceiver: Started receiving new file: $originalFileName to $tempFilePath");
                  }
                  
                  info.$1.add(fileContent);
                  info.$3.add(fileContent);
                  
                  info = (info.$1, info.$2 + fileContent.length, info.$3, info.$4);
                  _fileProcessingInfo[uniqueFileKey] = info;

                  // Update progress ke ReceiveScreen
                  onFileProgress?.call([(sharedFileInfoFromChunk, info.$2)]); // Hanya kirim update untuk file ini

                  if (info.$2 >= sharedFileInfoFromChunk.fileSize) {
                    print('FileSharingReceiver: File $originalFileName received completely to temp. Path: ${info.$4.path}');
                    await info.$1.flush();
                    await info.$1.close();
                    _fileProcessingInfo.remove(uniqueFileKey); // Hapus dari map pemrosesan

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
                        if (await info.$4.exists()) {
                            await info.$4.delete();
                            print("FileSharingReceiver: Deleted corrupted file: ${info.$4.path}");
                        }
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
                onError?.call("Invalid data received.");
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
          // Di sini kita masih membersihkan _fileProcessingInfo untuk file yang BELUM SELESAI
          _fileProcessingInfo.forEach((key, info) async {
             print("FileSharingReceiver: Incomplete file '$key' detected on connection done. Closing sink and deleting temp file.");
             await info.$1.close();
             try {
                 final tempFile = info.$4;
                 if (await tempFile.exists()) {
                     await tempFile.delete();
                     print("FileSharingReceiver: Deleted incomplete file '${tempFile.path}'.");
                 }
             } catch (e) {
                 print("FileSharingReceiver: Error deleting incomplete file '$key': $e");
             }
          });
          _fileProcessingInfo.clear();
          // _sharedFiles.clear(); // Hapus ini dari sini juga
          // onFileProgress?.call(List.from(_sharedFiles)); // Tidak memanggil ini dengan clear
        },
        onError: (error, stackTrace) {
          print('FileSharingReceiver: Socket error: $error\n$stackTrace');
          _currentSenderSocket?.destroy();
          _currentSenderSocket = null;
          onError?.call("Network connection error: $error");
          _fileProcessingInfo.forEach((key, info) async { // Hapus incomplete files juga pada error
             print("FileSharingReceiver: Incomplete file '$key' detected on error. Closing sink and deleting temp file.");
             await info.$1.close();
             try {
                 final tempFile = info.$4;
                 if (await tempFile.exists()) {
                     await tempFile.delete();
                     print("FileSharingReceiver: Deleted incomplete file '${tempFile.path}'.");
                 }
             } catch (e) {
                 print("FileSharingReceiver: Error deleting incomplete file '$key': $e");
             }
          });
          _fileProcessingInfo.clear();
          // _sharedFiles.clear(); // Hapus ini juga
          // onFileProgress?.call(List.from(_sharedFiles)); // Tidak memanggil ini dengan clear
        },
        cancelOnError: true,
      );

      try {
        print("FileSharingReceiver: Sending GetSharedFilesReq to ${_currentSenderSocket?.remoteAddress.address}");
        final packet = makePacket(EPacketType.GetSharedFilesReq);
        _currentSenderSocket?.add(Uint8List.sublistView(packet));
        await _currentSenderSocket?.flush();
      } catch (e) {
        print("FileSharingReceiver: Error sending GetSharedFilesReq: $e");
        onError?.call("Failed to request file list: $e");
      }
    });
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
      await tempFile.delete(); // File sementara dihapus setelah berhasil disimpan
      print("FileSharingReceiver: Temporary file '$tempFilePathWithPart' deleted.");
      return finalPath;

    } catch (e, s) {
      print("FileSharingReceiver: Error during finalizeSave: $e\n$s");
      String errorMessage = "Failed to save '$originalFileName': $e";
       if (Platform.isAndroid && e is FileSystemException) {
         if (e.osError?.errorCode == 13 || e.osError?.errorCode == 1) {
           errorMessage = "Failed to save '$originalFileName' due to permission issues on Android.";
         }
       }
      onError?.call(errorMessage);
      return null;
    }
  }
}