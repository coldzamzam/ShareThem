import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_shareit/protos/packet.pb.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:collection/collection.dart';

// Definisikan callback untuk progres
// sharedFile: File yang sedang dikirim
// sentBytes: Jumlah byte yang sudah terkirim untuk file tersebut
// isCompleted: True jika file sudah selesai dikirim (dan diterima konfirmasi)
typedef FileProgressCallback = void Function(SharedFile sharedFile, int sentBytes, bool isCompleted);

class FileSharingSender {
  final List<(SharedFile, Stream<List<int>>)> files;
  final String serverHost;
  final int serverPort;
  final FileProgressCallback? onProgressUpdate;
  Socket? _connection;
  bool _isSending = false;

  // Map untuk melacak bytes yang sudah terkirim per file
  final Map<String, int> _sentBytesMap = {};

  FileSharingSender({
    required this.serverHost,
    required this.files,
    this.serverPort = SharingDiscoveryService.servicePort,
    this.onProgressUpdate,
  });

  Future<void> stop() async {
    _isSending = false;
    await _connection?.close();
    _connection = null;
    print("FileSharingSender stopped");
  }

  // Metode untuk mengirim satu file
  Future<void> _sendFileActual(SharedFile sharedFile, Stream<List<int>> fileStream) async {
    print("begin sending file ${sharedFile.fileName}");
    _sentBytesMap[sharedFile.fileName] = 0; // Reset progress untuk file ini

    await for (final chunk in fileStream) {
      if (!_isSending) { // Periksa apakah pengiriman dihentikan
        print("Sending for ${sharedFile.fileName} cancelled.");
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
      await _connection?.flush();

      // Update sentBytes dan panggil callback
      _sentBytesMap[sharedFile.fileName] = (_sentBytesMap[sharedFile.fileName] ?? 0) + chunk.length;
      onProgressUpdate?.call(sharedFile, _sentBytesMap[sharedFile.fileName]!, false);
    }
  }

  Future<void> start() async {
    if (_isSending) return; // Mencegah start ganda
    _isSending = true;

    try {
      _connection = await Socket.connect(serverHost, serverPort);
      print("Connected to receiver at $serverHost:$serverPort");

      Uint8List? tempBuf;
      int currentFileIndex = 0; // Indeks file yang sedang diproses

      // Kirim request awal GetSharedFilesReq
      final req = GetSharedFilesReq(); // Pastikan GetSharedFilesReq didefinisikan di protos
      final initialPacket = makePacket(
        EPacketType.GetSharedFilesReq,
        payload: req.writeToBuffer(),
      );
      _connection?.add(Uint8List.sublistView(initialPacket));
      await _connection?.flush();
      print("Sent initial GetSharedFilesReq");

      _connection!.listen(
        (data) async { // Mengubah menjadi async karena akan ada await di dalamnya
          data = Uint8List.fromList([...?tempBuf, ...data]);
          tempBuf = null;

          var offset = 0;
          while (data.lengthInBytes >= 4) { // Pastikan ada cukup byte untuk membaca panjang paket
            final length = ByteData.view(data.buffer).getUint32(offset);
            if (data.lengthInBytes - offset < length + 4) { // Cek jika paket belum lengkap
              tempBuf = data.sublist(offset);
              break; // Keluar dari loop, tunggu data berikutnya
            }

            final packetType = EPacketType.valueOf(ByteData.view(data.buffer).getUint8(offset + 4))!; // +4 karena offset pertama adalah panjang
            final payloadBytes = data.sublist(offset + 5, offset + 4 + length); // +5 untuk panjang + tipe
            
            switch (packetType) {
              case EPacketType.GetSharedFilesReq: // Seharusnya tidak terjadi di sender, tapi antisipasi
                print("Sender received GetSharedFilesReq unexpectedly.");
                break;
              case EPacketType.GetSharedFilesRsp: // Receiver merespons dengan daftar file yang diminta
                print("Sender received GetSharedFilesRsp.");
                // Setelah receiver tahu daftar file, kita bisa mulai mengirim file pertama
                if (files.isNotEmpty && currentFileIndex == 0) {
                  final fileTuple = files[currentFileIndex];
                  await _sendFileActual(fileTuple.$1, fileTuple.$2);
                }
                break;
              case EPacketType.SharedFileCompletedNotify:
                final SharedFileCompletedNotify notify = SharedFileCompletedNotify.fromBuffer(payloadBytes);
                print("Received SharedFileCompletedNotify for ${notify.fileName}");

                // Konfirmasi bahwa file sebelumnya sudah selesai diterima
                // Panggil callback dengan status completed untuk file yang baru selesai
                final completedFile = files.firstWhereOrNull((f) => f.$1.fileName == notify.fileName);
                if (completedFile != null) {
                    onProgressUpdate?.call(completedFile.$1, completedFile.$1.fileSize.toInt(), true);
                }

                currentFileIndex++; // Lanjut ke file berikutnya
                if (currentFileIndex < files.length) {
                  final nextFile = files[currentFileIndex];
                  await _sendFileActual(nextFile.$1, nextFile.$2);
                } else {
                  print("All files sent and confirmed.");
                  // Semua file sudah terkirim dan dikonfirmasi, hentikan koneksi
                  await stop();
                }
                break;
              default:
                print("Invalid EPacketType received by sender: ${packetType}");
                break;
            }
            offset += (length + 4); // Pindah ke awal paket berikutnya
          }
          if (offset < data.lengthInBytes) { // Jika ada sisa data yang bukan paket lengkap
            tempBuf = data.sublist(offset);
          }
        },
        onDone: () {
          print("Sender socket disconnected.");
          _isSending = false;
        },
        onError: (e) {
          print("Sender socket error: $e");
          _isSending = false;
          // Mungkin tambahkan callback onError ke SendScreen jika ada error jaringan
        },
      );
    } catch (e) {
      print("Failed to connect or start sending: $e");
      _isSending = false;
      // Handle error di UI SendScreen
    }
  }
}
