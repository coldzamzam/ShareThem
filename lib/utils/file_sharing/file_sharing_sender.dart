import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_shareit/protos/packet.pb.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:collection/collection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

typedef FileProgressCallback = void Function(SharedFile sharedFile, int sentBytes, bool isCompleted);

class FileSharingSender {
  final List<(SharedFile, Stream<List<int>>)> files;
  final String serverHost;
  final int serverPort;
  final FileProgressCallback? onProgressUpdate;
  Socket? _connection;
  bool _isSending = false;

  final Map<String, int> _sentBytesMap = {};
  String? _cacheDirectoryPath;

  FileSharingSender({
    required this.serverHost,
    required this.files,
    this.serverPort = SharingDiscoveryService.servicePort,
    this.onProgressUpdate,
  }) {
    _initializeCachePath();
  }

  Future<void> _initializeCachePath() async {
    _cacheDirectoryPath = p.join((await getTemporaryDirectory()).uri.toFilePath(), "send_cache");
    if (!Directory(_cacheDirectoryPath!).existsSync()) {
      Directory(_cacheDirectoryPath!).create();
    }
    print("FileSharingSender: Cache directory set to $_cacheDirectoryPath");
  }

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

    if (_cacheDirectoryPath != null && Directory(_cacheDirectoryPath!).existsSync()) {
      try {
        await Directory(_cacheDirectoryPath!).delete(recursive: true);
        print("FileSharingSender: Cache directory $_cacheDirectoryPath deleted successfully.");
      } catch (e) {
        print("FileSharingSender: Error deleting cache directory $_cacheDirectoryPath: $e");
      }
    }

    print("FileSharingSender: Stopped.");
  }

  Future<void> sendFile((SharedFile, Stream<List<int>>) fileTuple) async {
    final sharedFile = fileTuple.$1;
    final fileStream = fileTuple.$2;
    print("FileSharingSender: begin sending file ${sharedFile.fileName}");
    _sentBytesMap[sharedFile.fileName] = 0;
    onProgressUpdate?.call(sharedFile, 0, false);

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
        await _connection?.flush();

        _sentBytesMap[sharedFile.fileName] = (_sentBytesMap[sharedFile.fileName] ?? 0) + chunk.length;
        onProgressUpdate?.call(sharedFile, _sentBytesMap[sharedFile.fileName]!, false);
      }
      print("FileSharingSender: All chunks for ${sharedFile.fileName} sent to socket.");
    } catch (e, s) {
      print("FileSharingSender: Error sending chunks for ${sharedFile.fileName}: $e\n$s");
      onProgressUpdate?.call(sharedFile, _sentBytesMap[sharedFile.fileName] ?? 0, false);
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
      int currentFileIndex = 0;

      _connection!.listen((data) async {
        if (!_isSending) return;

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

              if (files.isNotEmpty && currentFileIndex < files.length) {
                await sendFile(files[currentFileIndex]);
              } else {
                print("FileSharingSender: No files to send or currentFileIndex out of bounds after GetSharedFilesReq.");
                await stop();
              }
              break;

            case EPacketType.SharedFileCompletedNotify:
              final SharedFileCompletedNotify notify = SharedFileCompletedNotify.fromBuffer(payload);
              print("FileSharingSender: Received SharedFileCompletedNotify for ${notify.fileName}. Success: ${notify.success}. Message: ${notify.message}");

              final completedFile = files.firstWhereOrNull((f) => f.$1.fileName == notify.fileName);
              if (completedFile != null && notify.success) {
                onProgressUpdate?.call(completedFile.$1, completedFile.$1.fileSize.toInt(), true); // Konfirmasi selesai
              } else if (completedFile != null && !notify.success) {
                onProgressUpdate?.call(completedFile.$1, _sentBytesMap[completedFile.$1.fileName] ?? 0, false); // Mark as failed
              }


              currentFileIndex++;
              if (currentFileIndex < files.length) {
                print("FileSharingSender: Proceeding to send next file: ${files[currentFileIndex].$1.fileName}");
                await sendFile(files[currentFileIndex]);
              } else {
                print("FileSharingSender: All files sent and confirmed by receiver.");
                await stop();
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
        stop();
      },
      onError: (error, stackTrace) {
        print("FileSharingSender: Socket error: $error\n$stackTrace");
        _isSending = false;
        _connection?.destroy();
        stop();
      },
      cancelOnError: true,
      );
    } catch (e, s) {
      print("FileSharingSender: Failed to connect or start sending: $e\n$s");
      _isSending = false;
      stop();
    }
  }
}