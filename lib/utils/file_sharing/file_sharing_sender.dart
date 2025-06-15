import 'dart:async';
import 'dart:io';
import 'dart:math'; // Added for min function
import 'dart:typed_data';
import 'package:path/path.dart' as p;

import 'package:flutter_shareit/protos/packet.pb.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart'; // Ensure this uses the corrected makePacket function
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';

class FileSharingSender {
  // Define a smaller, more manageable chunk size for network packets
  static const int customChunkSize = 512 * 1024; // 512 KB

  final List<(SharedFile, File)> filesToSend; // Changed Stream<List<int>> to File
  final String serverHost;
  final int serverPort;
  Socket? _connection;

  final Completer<void> _sendCompleter = Completer<void>();
  StreamSubscription<Uint8List>? _socketSubscription;

  FileSharingSender({
    required this.serverHost,
    required this.filesToSend, // Now expects a List of (SharedFile, File) tuples
    this.serverPort = SharingDiscoveryService.servicePort,
  });

  /// Stops the file sending process and attempts to gracefully close the connection.
  Future<void> stop() async {
    print("FileSharingSender: stop() called. Closing connection.");
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    try {
      if (_connection != null) {
        await _connection?.flush(); // Ensure any pending data is sent before closing
        await _connection?.close();
        _connection = null;
      }
    } catch (e) {
      print("FileSharingSender: Error closing connection: $e");
    }
    if (!_sendCompleter.isCompleted) {
      _sendCompleter.completeError("Sending stopped externally.");
    }
    print("FileSharingSender: Connection fully stopped.");
  }

  /// The core logic for sending file metadata and then streaming file contents.
  /// It completes `_sendCompleter` when all files have been *sent from the sender's side*.
  Future<void> _performSendFilesAndComplete() async {
    try {
      if (_connection == null) {
        throw Exception("Socket connection is null, cannot send files.");
      }

      await _connection!.flush(); // Ensure any initial writes are sent (like GetSharedFilesRsp)

      for (final fileEntry in filesToSend) {
        final sharedFileMeta = fileEntry.$1;
        final File originalFile = fileEntry.$2; // Now directly a File object

        print('FileSharingSender: Sending file: ${sharedFileMeta.fileName} (Size: ${sharedFileMeta.fileSize})');

        // --- NEW CHUNKING LOGIC ---
        final RandomAccessFile raf = await originalFile.open(mode: FileMode.read);
        int bytesReadTotal = 0;
        final int fileSize = sharedFileMeta.fileSize.toInt(); // Convert Int64 to int

        while (bytesReadTotal < fileSize) {
          final int bytesToReadInChunk = min(customChunkSize, fileSize - bytesReadTotal);
          final Uint8List chunkBuffer = Uint8List(bytesToReadInChunk); // Pre-allocate buffer for chunk

          final int actualBytesRead = await raf.readInto(chunkBuffer);

          if (actualBytesRead == 0) {
            // End of file unexpectedly or corrupted file
            print('FileSharingSender: Warning: Unexpected end of file for ${sharedFileMeta.fileName} at $bytesReadTotal bytes out of $fileSize. Breaking chunk loop.');
            break;
          }

          final Uint8List currentChunk = chunkBuffer.sublist(0, actualBytesRead); // Get actual read bytes
          
          final fileContentNotify = SharedFileContentNotify(
            content: currentChunk,
            file: sharedFileMeta,
          );
          final packet = makePacket(
            EPacketType.SharedFileContentNotify,
            payload: fileContentNotify.writeToBuffer(),
          );
          
          _connection?.add(packet.buffer.asUint8List());
          // Flush after each chunk for better flow control and immediate network send.
          // For very high-speed local transfers, this could be batched, but for
          // typical wireless, flushing per chunk helps responsiveness.
          await _connection?.flush(); 

          bytesReadTotal += actualBytesRead;
          print('FileSharingSender: Sent ${bytesReadTotal}/${fileSize} bytes for ${sharedFileMeta.fileName}.');

          // Optional: Add a small delay for very fast local networks to prevent overwhelming receiver
          // await Future.delayed(Duration(milliseconds: 1));
        }
        await raf.close(); // Close RandomAccessFile after reading all chunks
        // --- END NEW CHUNKING LOGIC ---

        print('FileSharingSender: Finished sending file: ${sharedFileMeta.fileName}. All chunks flushed.');
      }

      print('FileSharingSender: All files sent. Sending FileTransferCompleteNotify.');

      final completionPacket = makePacket(EPacketType.FileTransferCompleteNotify);
      _connection?.add(completionPacket.buffer.asUint8List());
      await _connection?.flush(); // Ensure completion packet is sent

      if (!_sendCompleter.isCompleted) {
        _sendCompleter.complete(); // Transfer of all files is successfully completed.
      }
      print('FileSharingSender: All files sent successfully. Waiting for receiver to close connection.');

    } catch (e, s) {
      print('FileSharingSender: Error during overall file sending process: $e\n$s');
      if (!_sendCompleter.isCompleted) {
        _sendCompleter.completeError(e);
      }
      await stop(); // Aggressively stop on error
    }
  }

  /// Starts the connection and listening process.
  /// Returns a Future that completes when the transfer is fully acknowledged
  /// (by the receiver closing the connection) or fails.
  Future<void> start() async {
    try {
      print("FileSharingSender: Attempting to connect to $serverHost:$serverPort");
      _connection = await Socket.connect(serverHost, serverPort);
      print("FileSharingSender: Connected to receiver.");

      Uint8List _incomingBuffer = Uint8List(0); // Use a local buffer for incoming data
      
      _socketSubscription = _connection!.listen(
        (data) async {
          _incomingBuffer = Uint8List.fromList([..._incomingBuffer, ...data]);
          print('FileSharingSender: Received ${data.length} bytes from socket listener. Total buffer size: ${_incomingBuffer.length}');
          
          int bytesConsumedInLoop = 0; // Tracks bytes parsed in this iteration

          while(true) {
            // Check if there are enough bytes for length header (4 bytes)
            if (bytesConsumedInLoop + 4 > _incomingBuffer.lengthInBytes) {
              print('FileSharingSender: Not enough bytes for length header. Remaining: ${_incomingBuffer.lengthInBytes - bytesConsumedInLoop}. Breaking loop.');
              break;
            }

            // Read packet length with explicit Endian.little (consistent with receiver)
            final ByteData lengthView = ByteData.view(
              _incomingBuffer.buffer,
              _incomingBuffer.offsetInBytes + bytesConsumedInLoop,
              4
            );
            final int length = lengthView.getUint32(0, Endian.little);

            final int headerAndPacketLength = 4 + 1 + length;

            // Basic validation for length to prevent extreme values
            if (length < 0 || length > 10 * 1024 * 1024) { // Max 10MB payload for incoming from receiver
                print("FileSharingSender: Invalid incoming packet length from receiver: $length. Discarding remaining buffer.");
                _incomingBuffer = Uint8List(0); // Clear buffer on severe corruption
                return; // Stop processing this batch of data
            }

            // Check if there are enough bytes for the full packet
            if (bytesConsumedInLoop + headerAndPacketLength > _incomingBuffer.lengthInBytes) {
              print('FileSharingSender: Not enough bytes for full packet. Remaining: ${_incomingBuffer.lengthInBytes - bytesConsumedInLoop}. Expected: $headerAndPacketLength. Breaking loop.');
              break;
            }

            final packetTypeByte = _incomingBuffer[bytesConsumedInLoop + 4];
            EPacketType? packetType;
            try {
                packetType = EPacketType.valueOf(packetTypeByte);
            } catch (e) {
                print("FileSharingSender: Unknown EPacketType byte from receiver: $packetTypeByte at offset $bytesConsumedInLoop. Skipping.");
                bytesConsumedInLoop += 1; // Try to resynchronize
                continue;
            }

            final payloadOffset = bytesConsumedInLoop + 4 + 1;
            final Uint8List payload = _incomingBuffer.sublist(payloadOffset, payloadOffset + length);

            print('FileSharingSender: Processed incoming packet of type $packetType, length $length at offset $bytesConsumedInLoop.');

            switch (packetType) {
              case EPacketType.GetSharedFilesReq:
                print("FileSharingSender: Received GetSharedFilesReq from receiver. Sending response and starting file transfer.");
                final rsp = GetSharedFilesRsp(files: filesToSend.map((e) => e.$1));
                final packet = makePacket(
                  EPacketType.GetSharedFilesRsp,
                  payload: rsp.writeToBuffer(),
                );
                // Ensure makePacket uses Endian.little when creating the packet
                _connection?.add(packet.buffer.asUint8List());
                await _connection?.flush(); // Flush the response immediately

                // Start the actual file sending in the background.
                // The _sendCompleter will handle its completion/error.
                _performSendFilesAndComplete();
                break;
              default:
                print("FileSharingSender: Invalid or unhandled EPacketType received from receiver: $packetType (byte: $packetTypeByte)");
                break;
            }
            bytesConsumedInLoop += headerAndPacketLength; // Advance offset
          }

          // After the loop, trim the buffer to remove processed bytes
          if (bytesConsumedInLoop > 0) {
            _incomingBuffer = _incomingBuffer.sublist(bytesConsumedInLoop);
            print('FileSharingSender: Trimmed incoming buffer by $bytesConsumedInLoop bytes. New buffer size: ${_incomingBuffer.length}');
          } else {
            print('FileSharingSender: No full packets parsed in this incoming data event. Buffer size: ${_incomingBuffer.length}');
          }
        },
        onDone: () {
          print('FileSharingSender: Socket listener onDone: Connection closed by receiver.');
          if (!_sendCompleter.isCompleted) {
            _sendCompleter.completeError('Receiver closed connection unexpectedly before all files were sent.');
          }
          _connection = null;
          _socketSubscription?.cancel();
          _socketSubscription = null;
        },
        onError: (error, stackTrace) {
          print('FileSharingSender: Socket listener onError: $error\n$stackTrace');
          if (!_sendCompleter.isCompleted) {
            _sendCompleter.completeError('Socket error during send: $error');
          }
          _connection?.destroy();
          _connection = null;
          _socketSubscription?.cancel();
          _socketSubscription = null;
        },
        cancelOnError: true,
      );

      return _sendCompleter.future;

    } catch (e, s) {
      print("FileSharingSender: Initial connection or setup error: $e\n$s");
      if (!_sendCompleter.isCompleted) {
        _sendCompleter.completeError(e);
      }
      return _sendCompleter.future;
    }
  }
}