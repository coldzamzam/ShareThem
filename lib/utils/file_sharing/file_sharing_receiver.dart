import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_shareit/protos/packettype.pb.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';

class FileSharingReceiver {
  final int listenPort;
  List<SharedFile> sharedFiles = [];
  ValueChanged<List<SharedFile>>? onFileProgress;
  ServerSocket? _serverSocket;

  FileSharingReceiver({
    this.listenPort = SharingDiscoveryService.servicePort,
    this.onFileProgress,
  });

  Future<void> stop() async {
    await _serverSocket?.close();
    _serverSocket = null;
  }

  Future<void> start() async {
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      listenPort,
    );

    _serverSocket!.listen((socket) {
      Uint8List? tempBuf;
      socket.listen((data) {
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
          case EPacketType.GetSharedFilesRsp:
            sharedFiles = GetSharedFilesRsp.fromBuffer(
              Uint8List.sublistView(data, offset),
            ).files;
            print("got file list: $sharedFiles");
            if (onFileProgress != null) {
              onFileProgress!(sharedFiles);
            }
            
            break;
          default:
            print(
              "invalid EPacketType received for receiver: ${packetType ?? bytes.getUint8(4)}",
            );
            break;
        }
      });

      final packet = makePacket(EPacketType.GetSharedFilesReq);
      socket.add(Uint8List.sublistView(packet));
    });
  }
}
