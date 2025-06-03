import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_shareit/protos/packettype.pb.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';

class FileSharingSender {
  final Map<String, SharedFile> files;
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

  Future<void> start() async {
    _connection = await Socket.connect(serverHost, serverPort);

    Uint8List? tempBuf;
    _connection!.listen((data) {
      data = Uint8List.fromList([...?tempBuf, ...data]);
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
          final rsp = GetSharedFilesRsp(files: files.values);
          final packet = makePacket(EPacketType.GetSharedFilesRsp, payload: rsp.writeToBuffer());
          _connection?.add(Uint8List.sublistView(packet));
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
