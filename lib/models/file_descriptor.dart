// lib/models/file_descriptor.dart

/// A local model to hold metadata about a file selected for sending.
class FileDescriptor {
  final String fileName;
  final String filePath; // Actual path on the device
  final int fileSize;
  final int fileCrc; // CRC32 hash of the file content

  FileDescriptor({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fileCrc,
  });
}
