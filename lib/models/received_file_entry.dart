// lib/models/received_file_entry.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// A model class to represent a received file entry stored in Firestore.
/// This includes metadata like sender information.
class ReceivedFileEntry {
  final String id; // Document ID from Firestore
  final String fileName;
  final String filePath; // Local path where the file is saved on the device
  final int fileSize;
  final DateTime modifiedDate;
  final String senderId;
  final String senderName; // Display name of the sender

  ReceivedFileEntry({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.modifiedDate,
    required this.senderId,
    required this.senderName,
  });

  /// Factory constructor to create a `ReceivedFileEntry` from a Firestore `DocumentSnapshot`.
  factory ReceivedFileEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceivedFileEntry(
      id: doc.id,
      fileName: data['fileName'] ?? 'Unknown File',
      filePath: data['filePath'] ?? '',
      fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
      modifiedDate: (data['modifiedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      senderId: data['senderId'] ?? 'unknown',
      senderName: data['senderName'] ?? 'Unknown Sender',
    );
  }

  /// Converts a `ReceivedFileEntry` object into a map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'modifiedDate': Timestamp.fromDate(modifiedDate),
      'senderId': senderId,
      'senderName': senderName,
    };
  }
}