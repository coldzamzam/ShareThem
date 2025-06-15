import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_shareit/protos/packet.pb.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart'; // Pastikan ini diimpor dengan benar
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:collection/collection.dart'; // Diperlukan untuk firstWhereOrNull

// Definisikan callback untuk progres
typedef FileProgressCallback = void Function(SharedFile sharedFile, int sentBytes, bool isCompleted);

class FileSharingSender {
  final List<(SharedFile, Stream<List<int>>)> files;
  final String serverHost;
  final int serverPort;
  final FileProgressCallback? onProgressUpdate; // <<< TAMBAHKAN INI
  Socket? _connection;
  bool _isSending = false; // Flag untuk status pengiriman

  // Map untuk melacak bytes yang sudah terkirim per file
  final Map<String, int> _sentBytesMap = {};

  FileSharingSender({
    required this.serverHost,
    required this.files,
    this.serverPort = SharingDiscoveryService.servicePort,
    this.onProgressUpdate, // <<< INI JUGA TAMBAHKAN
  });

  Future<void> stop() async {
    print("FileSharingSender: stop() called.");
    _isSending = false;
    try {
      await _connection?.close();
      print("FileSharingSender: Socket closed.");
    } catch (e) {
      print("FileSharingSender: Error closing socket: $e");
    }
    _connection = null;
    _sentBytesMap.clear();
    print("FileSharingSender: Stopped.");
  }

  Future<void> sendFile((SharedFile, Stream<List<int>>) fileTuple) async {
    final sharedFile = fileTuple.$1;
    final fileStream = fileTuple.$2;
    print("FileSharingSender: begin sending file ${sharedFile.fileName}");
    _sentBytesMap[sharedFile.fileName] = 0; // Reset progress untuk file ini
    onProgressUpdate?.call(sharedFile, 0, false); // Beri tahu UI bahwa pengiriman dimulai

    try {
      await for (final chunk in fileStream) {
        if (!_isSending || _connection == null) {
          print("FileSharingSender: Sending for ${sharedFile.fileName} cancelled or connection lost.");
          return;
        }

        final chunkPacket = makePacket(
          EPacketType.SharedFileContentNotify,
          payload: SharedFileContentNotify(
            content: chunk,
            file: sharedFile,
          ).writeToBuffer(),
        );

        _connection?.add(Uint8List.sublistView(chunkPacket));
        await _connection?.flush(); // Pastikan data terkirim

        // Update sentBytes dan panggil callback
        _sentBytesMap[sharedFile.fileName] = (_sentBytesMap[sharedFile.fileName] ?? 0) + chunk.length;
        onProgressUpdate?.call(sharedFile, _sentBytesMap[sharedFile.fileName]!, false);
        // print("SENDER: Sent ${chunk.length} bytes for ${sharedFile.fileName}. Total sent: ${_sentBytesMap[sharedFile.fileName]}"); // Debugging
      }
      print("FileSharingSender: All chunks for ${sharedFile.fileName} sent to socket.");
    } catch (e, s) {
      print("FileSharingSender: Error sending chunks for ${sharedFile.fileName}: $e\n$s");
      onProgressUpdate?.call(sharedFile, _sentBytesMap[sharedFile.fileName] ?? 0, false); // Tidak complete, mungkin error
    }
  }

  Future<void> start() async {
    print("FileSharingSender: start() called.");
    if (_isSending) {
      print("FileSharingSender: Already sending.");
      return;
    }
    _isSending = true;
    _sentBytesMap.clear();

    try {
      _connection = await Socket.connect(serverHost, serverPort);
      print("FileSharingSender: Connected to receiver at $serverHost:$serverPort");

      Uint8List? tempBuf;
      int currentFileIndex = 0; // Mengganti fileProgress dengan currentFileIndex

      _connection!.listen((data) async { // Make listen callback async
        if (!_isSending) return; // Hentikan pemrosesan jika sudah dihentikan

        if (tempBuf != null) {
          data = Uint8List.fromList([...tempBuf!, ...data]);
          tempBuf = null;
        } else {
          data = Uint8List.fromList(data);
        }

        final bytes = data.buffer.asByteData();
        var offset = 0;

        while(true) {
          if (offset + 4 > bytes.lengthInBytes) { // Cek jika ada cukup byte untuk panjang paket
            tempBuf = Uint8List.sublistView(data, offset);
            break;
          }

          final length = bytes.getUint32(offset);
          final headerAndPacketLength = 4 + 1 + length;

          if (offset + headerAndPacketLength > bytes.lengthInBytes) { // Cek jika paket belum lengkap
            tempBuf = Uint8List.sublistView(data, offset);
            break;
          }

          final packetTypeByte = bytes.getUint8(offset + 4);
          EPacketType? packetType;
          try {
              packetType = EPacketType.valueOf(packetTypeByte);
          } catch (e) {
              print("FileSharingSender: Unknown EPacketType byte received: $packetTypeByte. Skipping packet.");
              offset += headerAndPacketLength;
              if (offset >= bytes.lengthInBytes) {
                  tempBuf = null; break;
              }
              continue;
          }
          
          final payloadOffset = offset + 4 + 1;
          final payload = Uint8List.sublistView(data, payloadOffset, payloadOffset + length); // Payload perlu diekstrak

          switch (packetType) {
            case EPacketType.GetSharedFilesReq:
              print("FileSharingSender: Received GetSharedFilesReq from receiver. Responding with GetSharedFilesRsp.");
              final rsp = GetSharedFilesRsp(files: files.map((f) => f.$1));
              final packet = makePacket(
                EPacketType.GetSharedFilesRsp,
                payload: rsp.writeToBuffer(),
              );
              _connection?.add(Uint8List.sublistView(packet));
              await _connection?.flush(); // Pastikan respons terkirim

              // Setelah respons dikirim, mulai kirim file pertama
              if (files.isNotEmpty && currentFileIndex < files.length) {
                await sendFile(files[currentFileIndex]);
              } else {
                print("FileSharingSender: No files to send or currentFileIndex out of bounds after GetSharedFilesReq.");
                await stop(); // Hentikan jika tidak ada file untuk dikirim
              }
              break;

            case EPacketType.SharedFileCompletedNotify:
              // Receiver memberitahu bahwa file sudah selesai diterima
              final SharedFileCompletedNotify notify = SharedFileCompletedNotify.fromBuffer(payload);
              print("FileSharingSender: Received SharedFileCompletedNotify for ${notify.fileName}. Success: ${notify.success}. Message: ${notify.message}");

              final completedFile = files.firstWhereOrNull((f) => f.$1.fileName == notify.fileName);
              if (completedFile != null && notify.success) {
                onProgressUpdate?.call(completedFile.$1, completedFile.$1.fileSize.toInt(), true); // Konfirmasi selesai
              } else if (completedFile != null && !notify.success) {
                onProgressUpdate?.call(completedFile.$1, _sentBytesMap[completedFile.$1.fileName] ?? 0, false); // Mark as failed
              }


              currentFileIndex++; // Lanjut ke file berikutnya
              if (currentFileIndex < files.length) {
                print("FileSharingSender: Proceeding to send next file: ${files[currentFileIndex].$1.fileName}");
                await sendFile(files[currentFileIndex]);
              } else {
                print("FileSharingSender: All files sent and confirmed by receiver.");
                await stop(); // Semua file selesai, hentikan koneksi
              }
              break;

            default:
              print(
                "FileSharingSender: invalid EPacketType received: ${packetType ?? bytes.getUint8(4)}",
              );
              break;
          }
          offset += headerAndPacketLength;
          if (offset >= bytes.lengthInBytes) {
              tempBuf = null; break;
          }
        }
      },
      onDone: () {
        print("FileSharingSender: Socket disconnected.");
        _isSending = false;
        // Opsional: panggil onProgressUpdate untuk semua file yang belum selesai sebagai "gagal"
      },
      onError: (error, stackTrace) {
        print("FileSharingSender: Socket error: $error\n$stackTrace");
        _isSending = false;
        _connection?.destroy(); // Pastikan socket ditutup
        // Opsional: panggil onProgressUpdate untuk semua file sebagai "error"
      },
      cancelOnError: true,
      );
    } catch (e, s) {
      print("FileSharingSender: Failed to connect or start sending: $e\n$s");
      _isSending = false;
      // Handle error di UI SendScreen, misalnya melalui callback
    }
  }
}