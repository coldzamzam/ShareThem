import 'dart:typed_data';

import 'package:flutter_shareit/protos/packettype.pb.dart';

ByteData makePacket(EPacketType type, {Uint8List? payload}) {
  final payloadLen = payload?.length ?? 0;
  final data = ByteData(5 + payloadLen);
  data.setUint32(0, payloadLen);
  data.setUint8(4, type.value);

  if (payload != null) {
    // Create a Uint8List view that corresponds to the ByteData object.
    // This view respects the ByteData's own offset and length within its underlying buffer.
    Uint8List targetView = Uint8List.sublistView(data);

    // Now, targetStartOffsetInByteData is a direct offset into this targetView.
    targetView.setRange(5, 5 + payloadLen, payload);
  }

  return data;
}
