import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_shareit/protos/packet.pb.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';

class FileSharingSender {
  final List<(SharedFile, Stream<List<int>>)> files;
  final String serverHost;
  final int serverPort;
  Socket? _connection;

  FileSharingSender({
    required this.serverHost,
    required this.files,
    this.serverPort = SharingDiscoveryService.servicePort,
  });

  Future<void> stop() async {
    await _connection?.close();
    _connection = null;
  }

  Future<void> sendFile((SharedFile, Stream<List<int>>) file) async {
    print("begin sending file ${file.$1.fileName}");
    await for (final chunk in file.$2) {
      final chunkPacket = makePacket(
        EPacketType.SharedFileContentNotify,
        payload: SharedFileContentNotify(
          content: chunk,
          file: file.$1,
        ).writeToBuffer(),
      );

      _connection?.add(Uint8List.sublistView(chunkPacket));
      await _connection?.flush();
    }
  }

  Future<void> start() async {
    _connection = await Socket.connect(serverHost, serverPort);

    Uint8List? tempBuf;
    int fileProgress = 0;
    _connection!.listen((data) {
      data = Uint8List.fromList([...?tempBuf, ...data]);
      tempBuf = null;
      final bytes = data.buffer.asByteData();

      var offset = 0;
      final length = bytes.getUint32(offset);
      offset += 4;
      final packetType = EPacketType.valueOf(bytes.getUint8(offset++));
      if (bytes.lengthInBytes < length + offset) {
        print("not enough packet bytes, waiting for next onData");
        tempBuf = data;
        return;
      }

      switch (packetType) {
        case EPacketType.GetSharedFilesReq:
          final rsp = GetSharedFilesRsp(files: files.map((f) => f.$1));
          final packet = makePacket(
            EPacketType.GetSharedFilesRsp,
            payload: rsp.writeToBuffer(),
          );
          _connection?.add(Uint8List.sublistView(packet));
          
          var file = files[fileProgress++];
          sendFile(file);
          break;
        case EPacketType.SharedFileCompletedNotify:
          var file = files[fileProgress++];
          sendFile(file);
          break;
        default:
          print(
            "invalid EPacketType received for receiver: ${packetType ?? bytes.getUint8(4)}",
          );
          break;
      }
    });
  }
}
