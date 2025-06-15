// lib/models/received_file_item.dart (Example, adjust as per your actual class)
import 'package:flutter_shareit/protos/sharethem.pb.dart';

class ReceivedFileItem {
  final SharedFile sharedFile;
  final int receivedBytes;
  final String? tempFilePath;
  final String? finalPath;
  final bool isSaving; // New field to indicate if it's currently being saved
  final bool isTempComplete; // New field to indicate if it's fully received to temp
  final String? errorMessage; // To display specific errors

  double get progress => receivedBytes / sharedFile.fileSize;
  bool get isPermanentlySaved => finalPath != null;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  ReceivedFileItem({
    required this.sharedFile,
    this.receivedBytes = 0,
    this.tempFilePath,
    this.finalPath,
    this.isSaving = false,
    this.isTempComplete = false, // Initialize as false
    this.errorMessage,
  });

  ReceivedFileItem copyWith({
    int? receivedBytes,
    String? tempFilePath,
    String? finalPath,
    bool? isSaving,
    bool? isTempComplete, // Include in copyWith
    String? errorMessage,
  }) {
    return ReceivedFileItem(
      sharedFile: sharedFile,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      tempFilePath: tempFilePath ?? this.tempFilePath,
      finalPath: finalPath ?? this.finalPath,
      isSaving: isSaving ?? this.isSaving,
      isTempComplete: isTempComplete ?? this.isTempComplete, // Copy it
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}