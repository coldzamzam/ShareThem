import 'dart:typed_data';
import 'package:flutter_shareit/protos/packet.pbenum.dart'; // Assuming EPacketType is here

// Helper function to create a packet with length and type header
ByteData makePacket(EPacketType type, {Uint8List? payload}) {
  final payloadLen = payload?.length ?? 0;
  // Total packet size = 4 bytes (length) + 1 byte (type) + payload length
  final data = ByteData(5 + payloadLen); 

  // --- CRITICAL: Set packet length using Endian.little ---
  data.setUint32(0, payloadLen, Endian.little); // <--- ENSURE THIS IS Endian.little
  // --- END CRITICAL ---

  data.setUint8(4, type.value); // Set packet type

  // Copy payload if it exists
  if (payload != null) {
    final Uint8List bufferView = data.buffer.asUint8List();
    bufferView.setRange(5, 5 + payloadLen, payload);
  }
  return data;
}