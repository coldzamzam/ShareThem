import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

import 'package:flutter_shareit/protos/packet.pb.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';

class FileSharingSender {
  static const int chunkSize = 1_000_000;
  final List<(SharedFile, Stream<List<int>>)> filesToSend;
  final String serverHost;
  final int serverPort;
  Socket? _connection;

  // The completer now tracks the overall success/failure of the entire transfer.
  final Completer<void> _sendCompleter = Completer<void>();
  StreamSubscription<Uint8List>? _socketSubscription;

  FileSharingSender({
    required this.serverHost,
    required this.filesToSend,
    this.serverPort = SharingDiscoveryService.servicePort,
  });

  /// Stops the file sending process and attempts to gracefully close the connection.
  /// If it's called due to an external cancellation, it will mark the transfer as failed.
  Future<void> stop() async {
    print("FileSharingSender: stop() called. Closing connection.");
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    try {
      if (_connection != null) {
        // Attempt to flush and close gracefully.
        // For aggressive stop (e.g., user cancel), _connection?.destroy() might be preferred.
        // Using close() as per your current code.
        await _connection?.flush();
        await _connection?.close();
        _connection = null;
      }
    } catch (e) {
      print("FileSharingSender: Error closing connection: $e");
    }
    // Only complete with an error if the transfer hasn't already finished successfully or failed.
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

      await _connection!.flush(); // Ensure any initial writes are sent

      for (final fileEntry in filesToSend) {
        final sharedFileMeta = fileEntry.$1;
        final originalFileStream = fileEntry.$2;

        print('FileSharingSender: Sending file: ${sharedFileMeta.fileName} (Size: ${sharedFileMeta.fileSize})');

        final fileTransferCompleter = Completer<void>();
        StreamSubscription<List<int>>? currentFileSubscription;

        currentFileSubscription = originalFileStream.listen(
          (chunk) {
            final chunkPacket = makePacket(
              EPacketType.SharedFileContentNotify,
              payload: SharedFileContentNotify(
                content: chunk,
                file: sharedFileMeta,
              ).writeToBuffer(),
            );
            _connection?.add(Uint8List.sublistView(chunkPacket));
          },
          onDone: () {
            print('FileSharingSender: Stream for ${sharedFileMeta.fileName} completed.');
            if (!fileTransferCompleter.isCompleted) {
              fileTransferCompleter.complete();
            }
          },
          onError: (e, s) {
            print('FileSharingSender: Error in file stream for ${sharedFileMeta.fileName}: $e\n$s');
            if (!fileTransferCompleter.isCompleted) {
              fileTransferCompleter.completeError(e);
            }
          },
          cancelOnError: true,
        );

        // Await the completion of the current file's transfer before moving to the next
        await fileTransferCompleter.future;
        await currentFileSubscription?.cancel(); // Use ?. for safety

        await _connection!.flush(); // Ensure all chunks of THIS file are flushed
        print('FileSharingSender: Finished sending file: ${sharedFileMeta.fileName}. All chunks flushed.');
      }

      print('FileSharingSender: All files sent. Sending FileTransferCompleteNotify.');

      // 1. CREATE and SEND the completion packet
      final completionPacket = makePacket(EPacketType.FileTransferCompleteNotify);
      _connection?.add(Uint8List.sublistView(completionPacket));
      await _connection?.flush();

      // 2. Mark the sender's *sending process* as complete.
      // The overall connection lifecycle is managed by the socket listener.
      if (!_sendCompleter.isCompleted) {
        _sendCompleter.complete(); // Transfer of all files is successfully completed.
      }
      print('FileSharingSender: All files sent successfully. Waiting for receiver to close connection.');

    } catch (e, s) {
      print('FileSharingSender: Error during overall file sending process: $e\n$s');
      // If an error occurs, complete the main completer with the error.
      if (!_sendCompleter.isCompleted) {
        _sendCompleter.completeError(e);
      }
      // In case of an error, it's safe to stop aggressively to clean up.
      await stop();
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

      Uint8List? tempBuf;
      _socketSubscription = _connection!.listen(
        (data) async {
          print('FileSharingSender: Received ${data.length} bytes from socket listener.');
          Uint8List currentBuffer = data;
          if (tempBuf != null) {
            currentBuffer = Uint8List.fromList([...tempBuf!, ...currentBuffer]);
            tempBuf = null;
          }

          final bytes = currentBuffer.buffer.asByteData();
          var offset = 0;

          while(true) {
            if (offset + 4 > bytes.lengthInBytes) {
              tempBuf = Uint8List.sublistView(currentBuffer, offset);
              print('FileSharingSender: Not enough bytes for length header. Remaining: ${bytes.lengthInBytes - offset}. Storing in tempBuf.');
              break;
            }

            final length = bytes.getUint32(offset);
            final headerAndPacketLength = 4 + 1 + length;

            if (offset + headerAndPacketLength > bytes.lengthInBytes) {
              tempBuf = Uint8List.sublistView(currentBuffer, offset);
              print('FileSharingSender: Not enough bytes for full packet. Remaining: ${bytes.lengthInBytes - offset}. Expected: $headerAndPacketLength. Storing in tempBuf.');
              break;
            }

            final packetTypeByte = bytes.getUint8(offset + 4);
            EPacketType? packetType;
            try {
                packetType = EPacketType.valueOf(packetTypeByte);
            } catch (e) {
                print("FileSharingSender: Unknown EPacketType byte: $packetTypeByte at offset $offset. Skipping this packet.");
                offset += headerAndPacketLength;
                if (offset >= bytes.lengthInBytes) {
                    tempBuf = null; break;
                }
                continue;
            }

            final payloadOffset = offset + 4 + 1;
            print('FileSharingSender: Processed packet of type $packetType, length $length at offset $offset.');

            switch (packetType) {
              case EPacketType.GetSharedFilesReq:
                print("FileSharingSender: Received GetSharedFilesReq from receiver. Sending response and starting file transfer.");
                final rsp = GetSharedFilesRsp(files: filesToSend.map((e) => e.$1));
                final packet = makePacket(
                  EPacketType.GetSharedFilesRsp,
                  payload: rsp.writeToBuffer(),
                );
                _connection?.add(Uint8List.sublistView(packet));
                await _connection?.flush();

                // Start the actual file sending in the background.
                // The _sendCompleter will handle its completion/error.
                _performSendFilesAndComplete();
                break;
              default:
                print("FileSharingSender: Invalid EPacketType received: $packetType (byte: $packetTypeByte)");
                break;
            }
            offset += headerAndPacketLength;
            if (offset >= bytes.lengthInBytes) {
                tempBuf = null; break;
            }
          }
        },
        onDone: () {
          // This `onDone` means the receiver closed the connection.
          // If the _sendCompleter is already completed (i.e., all files were sent
          // and _performSendFilesAndComplete() called complete()), then this is a graceful closure.
          // Otherwise, it's an unexpected early closure from the receiver.
          print('FileSharingSender: Socket listener onDone: Connection closed by receiver.');
          if (!_sendCompleter.isCompleted) {
            // Unexpected closure from receiver
            _sendCompleter.completeError('Receiver closed connection unexpectedly before all files were sent.');
          }
          // Cleanup resources.
          _connection = null;
          _socketSubscription?.cancel();
          _socketSubscription = null;
        },
        onError: (error, stackTrace) {
          print('FileSharingSender: Socket listener onError: $error\n$stackTrace');
          // Always complete with an error if the connection had an error and completer is pending.
          if (!_sendCompleter.isCompleted) {
            _sendCompleter.completeError('Socket error during send: $error');
          }
          // Forcefully close connection and cleanup.
          _connection?.destroy(); // Use destroy for aggressive error cleanup
          _connection = null;
          _socketSubscription?.cancel();
          _socketSubscription = null;
        },
        cancelOnError: true,
      );

      // Return the future from the completer immediately.
      // This allows the caller to await the entire async operation.
      return _sendCompleter.future;

    } catch (e, s) {
      print("FileSharingSender: Initial connection or setup error: $e\n$s");
      // If an error occurs during initial connection, complete the completer with error.
      if (!_sendCompleter.isCompleted) {
        _sendCompleter.completeError(e);
      }
      // Always return the completer's future, even on initial error.
      return _sendCompleter.future;
    }
  }
}