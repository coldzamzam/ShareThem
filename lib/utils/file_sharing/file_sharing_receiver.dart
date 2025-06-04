import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart'; // ValueChanged
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // Import package path
import 'package:permission_handler/permission_handler.dart';
import 'package:file_saver/file_saver.dart'; // Import file_saver

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

                  // Buat map dari progres file yang sudah ada untuk mempertahankan progres
                  Map<String, int> existingProgressMap = {}; // Key: "fileName|fileSize"
                  for (var existingFileTuple in _sharedFiles) {
                      existingProgressMap["${existingFileTuple.$1.fileName}|${existingFileTuple.$1.fileSize}"] = existingFileTuple.$2;
                  }

                  List<(SharedFile, int)> newMasterList = [];
                  bool structureChanged = false; // Untuk melacak apakah struktur list (item atau urutan) berubah

                  if (filesRsp.files.isEmpty && _sharedFiles.isEmpty) {
                      print("FileSharingReceiver: GetSharedFilesRsp - Both new and old lists are empty.");
                      // Tidak ada perubahan, _sharedFiles sudah kosong
                  } else {
                      for (var fileMetaFromRsp in filesRsp.files) {
                          String key = "${fileMetaFromRsp.fileName}|${fileMetaFromRsp.fileSize}";
                          int progress = existingProgressMap[key] ?? 0; // Ambil progres yang ada atau 0 jika file baru
                          newMasterList.add((fileMetaFromRsp, progress));
                      }

                      // Periksa apakah daftar baru berbeda secara struktural (jumlah item atau item itu sendiri)
                      // dari daftar lama, bukan hanya nilai progres.
                      if (newMasterList.length != _sharedFiles.length) {
                          structureChanged = true;
                      } else {
                          for (int i = 0; i < newMasterList.length; i++) {
                              // Bandingkan metadata file, bukan progres di sini untuk perubahan struktural
                              if (newMasterList[i].$1.fileName != _sharedFiles[i].$1.fileName ||
                                  newMasterList[i].$1.fileSize != _sharedFiles[i].$1.fileSize) {
                                  structureChanged = true;
                                  break;
                              }
                              // Jika file sama tapi progresnya berbeda dari yang disimpan (misal, dari 0 menjadi x), itu bukan perubahan struktural
                              // tapi update progres yang harusnya sudah ditangani oleh SharedFileContentNotify.
                              // Di sini kita hanya fokus pada apakah daftar file dari server berubah.
                          }
                      }
                       _sharedFiles = newMasterList; // Update _sharedFiles dengan daftar yang baru dibangun
                  }
                  
                  if (structureChanged) {
                      print("FileSharingReceiver: GetSharedFilesRsp - _sharedFiles list structure was updated or reordered.");
                  } else {
                      print("FileSharingReceiver: GetSharedFilesRsp - _sharedFiles list structure and progress preserved or initialized empty.");
                  }
                  // Selalu panggil onFileProgress untuk merefleksikan daftar (yang mungkin diurutkan ulang atau metadata diperbarui).
                  // UI harus cukup tangguh untuk menangani ini.
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

  Future<String?> _requestPermissions() async {
    // Dengan FileSaver (SAF), izin storage eksplisit mungkin kurang diperlukan
    // karena pengguna memilih lokasi. Namun, bisa diminta sebagai fallback atau praktik umum.
    if (Platform.isAndroid) {
        var storageStatus = await Permission.storage.request();
        print("FileSharingReceiver: Permission status storage: $storageStatus");
        if (!storageStatus.isGranted && !storageStatus.isPermanentlyDenied) {
             // Jika tidak di-grant tapi tidak permanen ditolak, mungkin pengguna akan diminta lagi oleh SAF.
             // Jika permanen ditolak, SAF mungkin juga tidak berfungsi.
             print("FileSharingReceiver: Storage permission not fully granted. SAF will handle user choice.");
        }
        if(storageStatus.isPermanentlyDenied){
            print("FileSharingReceiver: Storage permission permanently denied. Saving may fail.");
            return "Storage permission permanently denied. Cannot save file.";
        }
    }
    // Untuk iOS, FileSaver juga akan membuka dialog sistem.
    return null;
  }

  String _getMimeType(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    // Daftar MIME type dasar, bisa diperluas
    switch (extension) {
      case '.pdf': return 'application/pdf';
      case '.jpg': case '.jpeg': return 'image/jpeg';
      case '.png': return 'image/png';
      case '.gif': return 'image/gif';
      case '.mp4': return 'video/mp4';
      case '.mov': return 'video/quicktime';
      case '.txt': return 'text/plain';
      case '.doc': return 'application/msword';
      case '.docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls': return 'application/vnd.ms-excel';
      case '.xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt': return 'application/vnd.ms-powerpoint';
      case '.pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default: return 'application/octet-stream'; // Tipe default jika tidak diketahui
    }
  }

  Future<String?> finalizeSave(String tempFilePathWithPart, String originalFileName) async {
    // Izin diminta di sini, tapi FileSaver (SAF) akan memiliki dialognya sendiri.
    // final String? permissionError = await _requestPermissions();
    // if (permissionError != null) {
    //   onError?.call(permissionError);
    //   return null;
    // }

    final File tempFile = File(tempFilePathWithPart);
    if (!await tempFile.exists()) {
      onError?.call("Temporary file '$tempFilePathWithPart' not found for '$originalFileName'.");
      return null;
    }

    try {
      print("FileSharingReceiver: Reading temporary file '$tempFilePathWithPart' into bytes.");
      final Uint8List fileBytes = await tempFile.readAsBytes();
      print("FileSharingReceiver: Temporary file read successfully. Byte length: ${fileBytes.length}");

      final String mimeType = _getMimeType(originalFileName);
      print("FileSharingReceiver: Attempting to save '$originalFileName' (MIME: $mimeType) using FileSaver (SAF).");

      // Menggunakan FileSaver.saveFile yang akan membuka dialog sistem
      // Pengguna akan memilih lokasi dan bisa mengganti nama file.
      // `saveFile` mengembalikan path jika berhasil, null jika dibatalkan atau gagal.
      String? savedPath = await FileSaver.instance.saveFile(
          name: originalFileName, // Nama file awal yang disarankan
          bytes: fileBytes,
          // ext: p.extension(originalFileName).replaceFirst('.', ''), // Ekstensi tanpa titik
          mimeType: MimeType.custom, // Menggunakan custom untuk memberikan string MIME type lengkap
          customMimeType: mimeType,
      );


      if (savedPath != null && savedPath.isNotEmpty) {
        print("FileSharingReceiver: File '$originalFileName' saved successfully via FileSaver to: '$savedPath'");
        await tempFile.delete();
        print("FileSharingReceiver: Temporary file '$tempFilePathWithPart' deleted.");
        return savedPath;
      } else {
        print("FileSharingReceiver: File save cancelled by user or failed via FileSaver for '$originalFileName'.");
        onError?.call("File save cancelled or failed for '$originalFileName'."); // Pesan lebih umum
        return null;
      }
    } catch (e, s) {
      print("FileSharingReceiver: Error during finalizeSave with FileSaver for '$originalFileName': $e\n$s");
      onError?.call("Failed to save '$originalFileName': $e");
      return null;
    }
  }
}
