// lib/models/received_file_item.dart
import 'package:flutter_shareit/protos/sharethem.pb.dart'; // Import your SharedFile

class ReceivedFileItem {
  final SharedFile sharedFile;
  int receivedBytes;
  String? tempFilePath; // Path in temporary storage (e.g., cache)
  String? finalPath;    // Path after being moved to permanent storage
  bool isSaving;        // Flag for when finalizeSave is in progress
  String? errorMessage; // Store error specific to this file

  ReceivedFileItem({
    required this.sharedFile,
    this.receivedBytes = 0,
    this.tempFilePath,
    this.finalPath,
    this.isSaving = false,
    this.errorMessage,
  });

  // Helper for immutable updates (good practice)
  ReceivedFileItem copyWith({
    int? receivedBytes,
    String? tempFilePath,
    String? finalPath,
    bool? isSaving,
    String? errorMessage,
  }) {
    return ReceivedFileItem(
      sharedFile: sharedFile,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      tempFilePath: tempFilePath ?? this.tempFilePath,
      finalPath: finalPath ?? this.finalPath,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage, // Allow setting to null
    );
  }

  // Derived properties for UI
  double get progress =>
      (sharedFile.fileSize == 0) ? 0.0 : (receivedBytes / sharedFile.fileSize);
  bool get isTempComplete => receivedBytes >= sharedFile.fileSize && tempFilePath != null;
  bool get isPermanentlySaved => finalPath != null;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}