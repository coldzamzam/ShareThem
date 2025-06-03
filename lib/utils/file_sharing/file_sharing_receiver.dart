import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_shareit/protos/packet.pbenum.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';

class FileSharingReceiver {
  final int listenPort;
  ValueChanged<List<(SharedFile, int)>>? onFileProgress;
  List<(SharedFile, int)> _sharedFiles = [];
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
          case EPacketType.GetSharedFilesRsp:
            _sharedFiles = GetSharedFilesRsp.fromBuffer(
              Uint8List.sublistView(data, offset, length + offset),
            ).files.map((f) => (f, 0)).toList();
            print("got file list: $_sharedFiles");
            if (onFileProgress != null) {
              onFileProgress!(_sharedFiles);
            }

            break;
          case EPacketType.SharedFileContentNotify:
            final fileChunk = SharedFileContentNotify.fromBuffer(
              Uint8List.sublistView(data, offset, length + offset),
            );

            final fileIdx = _sharedFiles.indexWhere(
              (f) => f.$1 == fileChunk.file,
            );

            _sharedFiles[fileIdx] = (
              _sharedFiles[fileIdx].$1,
              _sharedFiles[fileIdx].$2 + fileChunk.content.length,
            );

            if (onFileProgress != null) {
              onFileProgress!(_sharedFiles);
            }

            break;
          default:
            print(
              "invalid EPacketType received for receiver: ${packetType ?? bytes.getUint8(4)}",
            );
            break;
        }

        if (offset + length < bytes.lengthInBytes) {
          tempBuf = Uint8List.sublistView(bytes, offset + length);
          print("buffer overreading, returning to tempBuf");
        }
      });

      final packet = makePacket(EPacketType.GetSharedFilesReq);
      socket.add(Uint8List.sublistView(packet));
    });
  }
}
