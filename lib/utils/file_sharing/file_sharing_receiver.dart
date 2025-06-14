import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_shareit/utils/file_utils.dart';
import 'package:flutter_shareit/protos/packet.pbenum.dart';
import 'package:flutter_shareit/utils/file_sharing/packet.dart';


// --- Definition for ReceiveScreen ---

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _discoverable = SharingDiscoveryService.isDiscoverable;
  List<(SharedFile, int)> _sharedFiles = [];
  bool _receivingBegun = false;
  late FileSharingReceiver _receiver;

  final Map<String, String> _tempFilePaths = {};
  // State untuk file yang berhasil disimpan
  final List<Map<String, String>> _successfullySavedFilesData = [];
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _receiver = FileSharingReceiver(
      onFileProgress: (files) {
        if (!mounted) return;
        setState(() {
          _receivingBegun = true;
          _sharedFiles = files;
          _errorMessage = "";
        });
      },
      onFileReceivedToTemp: (fileData) {
        if (!mounted) return;
        SharedFile file = fileData[0] as SharedFile;
        String tempPath = fileData[1] as String;
        setState(() {
          _tempFilePaths[file.fileName] = tempPath;
          final index = _sharedFiles.indexWhere((f) => f.$1.fileName == file.fileName);
          if (index != -1) {
            if (_sharedFiles[index].$2 < file.fileSize) {
              _sharedFiles[index] = (file, file.fileSize.toInt());
            }
          } else {
            _sharedFiles.add((file, file.fileSize.toInt()));
          }
        });
      },
      onError: (message) {
        if (!mounted) return;
        print("ReceiveScreen Error: $message");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $message'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _errorMessage = message;
        });
      },
    );
  }
  
  // ADDED: Helper function to open a file.
  Future<void> _openFile(String filePath, String fileName) async {
    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open file $fileName: ${result.message}'),
        backgroundColor: Colors.orange,
      ));
    }
  }


  @override
  void dispose() {
    SharingDiscoveryService.stopBroadcast();
    _receiver.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The AppBar is managed by HomePage, so it's removed from here.
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Durations.short2,
                child: _discoverable
                    ? const Icon(Icons.wifi_tethering, size: 100, key: ValueKey(1), color: Colors.blue)
                    : Icon(Icons.wifi_tethering_off, size: 100, color: Colors.grey[400], key: const ValueKey(0)),
              ),
              const SizedBox(height: 10),
              Text(
                _discoverable
                    ? "Waiting for sender..."
                    : (_receivingBegun ? "Receiving files..." : "Press 'Start Receiving'"),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              Text("Incoming Files:", style: Theme.of(context).textTheme.titleSmall),
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 2,
                  child: _sharedFiles.isEmpty
                      ? const Center(child: Text("Ready to receive. Files will appear here."))
                      : ListView.builder(
                          itemCount: _sharedFiles.length,
                          itemBuilder: (_, i) {
                            final fileTuple = _sharedFiles[i];
                            final sharedFile = fileTuple.$1;
                            final receivedBytes = fileTuple.$2;
                            final progress = (sharedFile.fileSize == 0)
                                ? 0.0
                                : (receivedBytes / sharedFile.fileSize);
                            final bool isSaved = _successfullySavedFilesData.any((savedFile) => savedFile['name'] == sharedFile.fileName);
                            final bool isReadyToSave = _tempFilePaths.containsKey(sharedFile.fileName);

                            Widget trailingWidget;
                            if (isSaved) {
                              trailingWidget = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Saved ", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                                ],
                              );
                            } else if (isReadyToSave) {
                              trailingWidget = ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                                onPressed: () async {
                                  String? tempPath = _tempFilePaths[sharedFile.fileName];
                                  if (tempPath == null) return;

                                  final messenger = ScaffoldMessenger.of(context);
                                  String? finalPath = await _receiver.finalizeSave(tempPath, sharedFile.fileName);

                                  if (finalPath != null && finalPath.isNotEmpty) {
                                    messenger.showSnackBar(SnackBar(content: Text("${p.basename(finalPath)} saved!")));
                                    if (!mounted) return;
                                    setState(() {
                                      // Use the original file name as the key, but store the final path.
                                      if (!_successfullySavedFilesData.any((f) => f['name'] == sharedFile.fileName)) {
                                        _successfullySavedFilesData.add({'name': sharedFile.fileName, 'path': finalPath});
                                      }
                                    });
                                  } else {
                                    messenger.showSnackBar(SnackBar(content: Text("Failed to save ${sharedFile.fileName}.")));
                                  }
                                },
                                child: const Text("Save"),
                              );
                            } else {
                              trailingWidget = Text("${(progress * 100).toStringAsFixed(0)}%");
                            }

                            return ListTile(
                              leading: const Icon(Icons.description),
                              title: Text(sharedFile.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Size: ${fileSizeToHuman(sharedFile.fileSize.toInt())}'),
                              trailing: trailingWidget,
                              onTap: isSaved
                                  ? () {
                                      final savedFile = _successfullySavedFilesData.firstWhere((f) => f['name'] == sharedFile.fileName);
                                      _openFile(savedFile['path']!, p.basename(savedFile['path']!));
                                    }
                                  : null, 
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_discoverable) {
                    setState(() {
                      _discoverable = false;
                      _receivingBegun = false;
                    });
                    await SharingDiscoveryService.stopBroadcast();
                    await _receiver.stop();
                  } else {
                    setState(() {
                      _sharedFiles.clear();
                      _tempFilePaths.clear();
                      _successfullySavedFilesData.clear(); // Clear saved files for new session
                      _receivingBegun = false;
                      _errorMessage = "";
                    });
                    await _receiver.start();
                    await SharingDiscoveryService.beginBroadcast();
                    setState(() {
                      _discoverable = true;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: _discoverable ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(
                  _discoverable ? 'Stop Receiving' : 'Start Receiving',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Definition for FileSharingReceiver ---

class FileSharingReceiver {
  final int listenPort;
  ValueChanged<List<(SharedFile, int)>>? onFileProgress;
  ValueChanged<String>? onError;
  ValueChanged<List<dynamic>>? onFileReceivedToTemp;

  List<(SharedFile, int)> _sharedFiles = [];
  ServerSocket? _serverSocket;
  String? _temporaryStoragePath;

  final Map<String, IOSink> _fileSinks = {};

  FileSharingReceiver({
    this.listenPort = SharingDiscoveryService.servicePort,
    this.onFileProgress,
    this.onError,
    this.onFileReceivedToTemp,
  });

  Future<void> _prepareStoragePaths() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _temporaryStoragePath = tempDir.path;
      print('FileSharingReceiver: Temporary files will be stored in: $_temporaryStoragePath');
    } catch (e) {
      print("FileSharingReceiver: Error preparing temporary storage path: $e");
      onError?.call("Failed to prepare temporary storage directory: $e");
      _temporaryStoragePath = null;
    }
  }

  Future<void> stop() async {
    print("FileSharingReceiver: stop() called.");
    if (_serverSocket == null && _fileSinks.isEmpty) {
      print("FileSharingReceiver: Already stopped or nothing to stop.");
    }
    try {
      await _serverSocket?.close();
      print("FileSharingReceiver: Server socket closed.");
    } catch (e) {
      print("FileSharingReceiver: Error closing server socket: $e");
    }
    _serverSocket = null;

    final List<String> sinkKeys = _fileSinks.keys.toList();
    for (final key in sinkKeys) {
      final sink = _fileSinks[key];
      try {
        await sink?.close();
        print("FileSharingReceiver: Closed sink for $key.");
      } catch (e) {
        print("FileSharingReceiver: Error closing sink for $key: $e");
      }
    }
    _fileSinks.clear();
    print("FileSharingReceiver: All sinks closed and cleared. Receiver stopped.");
  }

  Future<void> start() async {
    print("FileSharingReceiver: start() called.");
    if (_serverSocket != null) {
      print("FileSharingReceiver: Receiver already running.");
      return;
    }

    await _prepareStoragePaths();
    if (_temporaryStoragePath == null) {
      print("FileSharingReceiver: Temporary storage path not available. Receiver cannot start.");
      onError?.call("Temporary storage path not available. Cannot start receiver.");
      return;
    }
    _sharedFiles.clear();
    if (_fileSinks.isNotEmpty) {
        print("FileSharingReceiver: Warning - _fileSinks was not empty at start. Clearing now.");
        final List<String> sinkKeys = _fileSinks.keys.toList();
        for (final key in sinkKeys) {
            try {
                await _fileSinks[key]?.close();
            } catch (e) {/* ignore */}
        }
        _fileSinks.clear();
    }

    print("FileSharingReceiver: Attempting to bind server socket on port $listenPort.");
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        listenPort,
      );
      print('FileSharingReceiver: Server socket bound successfully on port $listenPort. Listening for connections...');
    } catch (e) {
      print("FileSharingReceiver: Error binding server socket: $e");
      onError?.call("Failed to start receiver: $e");
      return;
    }

    _serverSocket!.listen((socket) {
      print('FileSharingReceiver: Connection received from ${socket.remoteAddress.address}:${socket.remotePort}');
      Uint8List? tempBuf;

      socket.listen(
        (data) async {
          if (tempBuf != null) {
            data = Uint8List.fromList([...tempBuf!, ...data]);
            tempBuf = null;
          } else {
            data = Uint8List.fromList(data);
          }

          final bytes = data.buffer.asByteData();
          var offset = 0;

          while(true) {
            if (offset + 4 > bytes.lengthInBytes) {
              tempBuf = Uint8List.sublistView(data, offset);
              break;
            }

            final length = bytes.getUint32(offset);
            final headerAndPacketLength = 4 + 1 + length;

            if (offset + headerAndPacketLength > bytes.lengthInBytes) {
              tempBuf = Uint8List.sublistView(data, offset);
              break;
            }

            final packetTypeByte = bytes.getUint8(offset + 4);
            EPacketType? packetType;
            try {
                packetType = EPacketType.valueOf(packetTypeByte);
            } catch (e) {
                print("FileSharingReceiver: Unknown EPacketType byte: $packetTypeByte. Skipping.");
                offset += headerAndPacketLength;
                if (offset >= bytes.lengthInBytes) {
                    tempBuf = null; break;
                }
                continue;
            }
            
            final payloadOffset = offset + 4 + 1;

            switch (packetType) {
              case EPacketType.GetSharedFilesRsp:
                try {
                  final filesRsp = GetSharedFilesRsp.fromBuffer(
                    Uint8List.sublistView(data, payloadOffset, payloadOffset + length),
                  );
                  print("FileSharingReceiver: GetSharedFilesRsp - Received with files: ${filesRsp.files.map((f) => f.fileName).toList()}");

                  Map<String, int> existingProgressMap = {}; 
                  for (var existingFileTuple in _sharedFiles) {
                      existingProgressMap["${existingFileTuple.$1.fileName}|${existingFileTuple.$1.fileSize}"] = existingFileTuple.$2;
                  }

                  List<(SharedFile, int)> newMasterList = [];
                  bool structureChanged = false; 

                  if (filesRsp.files.isEmpty && _sharedFiles.isEmpty) {
                      print("FileSharingReceiver: GetSharedFilesRsp - Both new and old lists are empty.");
                  } else {
                      for (var fileMetaFromRsp in filesRsp.files) {
                          String key = "${fileMetaFromRsp.fileName}|${fileMetaFromRsp.fileSize}";
                          int progress = existingProgressMap[key] ?? 0; 
                          newMasterList.add((fileMetaFromRsp, progress));
                      }

                      if (newMasterList.length != _sharedFiles.length) {
                          structureChanged = true;
                      } else {
                          for (int i = 0; i < newMasterList.length; i++) {
                              if (newMasterList[i].$1.fileName != _sharedFiles[i].$1.fileName ||
                                  newMasterList[i].$1.fileSize != _sharedFiles[i].$1.fileSize) {
                                  structureChanged = true;
                                  break;
                              }
                          }
                      }
                       _sharedFiles = newMasterList; 
                  }
                  
                  if (structureChanged) {
                      print("FileSharingReceiver: GetSharedFilesRsp - _sharedFiles list structure was updated or reordered.");
                  } else {
                      print("FileSharingReceiver: GetSharedFilesRsp - _sharedFiles list structure and progress preserved or initialized empty.");
                  }
                  onFileProgress?.call(List.from(_sharedFiles));

                } catch (e, s) {
                  print("FileSharingReceiver: Error parsing GetSharedFilesRsp: $e\n$s");
                  onError?.call("Error processing file list: $e");
                }
                break;

              case EPacketType.SharedFileContentNotify:
                if (_temporaryStoragePath == null) {
                  onError?.call("Temporary storage path not set. File chunk skipped.");
                  break;
                }
                try {
                  final fileChunk = SharedFileContentNotify.fromBuffer(
                    Uint8List.sublistView(data, payloadOffset, payloadOffset + length),
                  );
                  final SharedFile sharedFileInfoFromChunk = fileChunk.file;
                  final String originalFileName = sharedFileInfoFromChunk.fileName;
                  final fileContent = fileChunk.content;

                  final fileIdx = _sharedFiles.indexWhere(
                    (f) => f.$1.fileName == originalFileName && f.$1.fileSize == sharedFileInfoFromChunk.fileSize,
                  );

                  if (fileIdx != -1) {
                    final String tempFilePath = p.join(_temporaryStoragePath!, '$originalFileName.part');
                    IOSink sink = _fileSinks[originalFileName] ??= File(tempFilePath).openWrite(mode: FileMode.append);
                    sink.add(fileContent);

                    var (sharedFileFromList, receivedBytes) = _sharedFiles[fileIdx];
                    receivedBytes += fileContent.length;
                    _sharedFiles[fileIdx] = (sharedFileFromList, receivedBytes);
                    
                    onFileProgress?.call(List.from(_sharedFiles));

                    if (receivedBytes >= sharedFileFromList.fileSize) {
                      print('FileSharingReceiver: File $originalFileName received completely to temp. Path: $tempFilePath');
                      await sink.flush();
                      await sink.close();
                      _fileSinks.remove(originalFileName);
                      onFileReceivedToTemp?.call([sharedFileFromList, tempFilePath]);
                    }
                  } else {
                     print("FileSharingReceiver: Received chunk for unknown file: '$originalFileName'. Current files: ${_sharedFiles.map((f)=>f.$1.fileName).toList()}");
                  }
                } catch (e, s) {
                  print("FileSharingReceiver: Error processing SharedFileContentNotify: $e\n$s");
                  onError?.call("Error saving file chunk to temp: $e");
                }
                break;
              default:
                print("FileSharingReceiver: Invalid EPacketType received: $packetType (byte: $packetTypeByte)");
                break;
            }
            offset += headerAndPacketLength;
            if (offset >= bytes.lengthInBytes) {
                tempBuf = null; break;
            }
          }
        },
        onDone: () {
          print('FileSharingReceiver: Connection closed by client: ${socket.remoteAddress.address}:${socket.remotePort}');
        },
        onError: (error, stackTrace) {
          print('FileSharingReceiver: Socket error: $error\n$stackTrace');
          socket.destroy();
          onError?.call("Network connection error: $error");
        },
        cancelOnError: true,
      );

      try {
        print("FileSharingReceiver: Sending GetSharedFilesReq to ${socket.remoteAddress.address}");
        final packet = makePacket(EPacketType.GetSharedFilesReq);
        socket.add(Uint8List.sublistView(packet));
      } catch (e) {
        print("FileSharingReceiver: Error sending GetSharedFilesReq: $e");
        onError?.call("Failed to request file list: $e");
      }
    });
  }

  // MODIFIED: This function now handles file name collisions.
  Future<String?> finalizeSave(String tempFilePathWithPart, String originalFileName) async {
    final File tempFile = File(tempFilePathWithPart);
    if (!await tempFile.exists()) {
      onError?.call("Temporary file '$tempFilePathWithPart' not found for '$originalFileName'.");
      return null;
    }

    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = await getDownloadsDirectory();
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        downloadsDir = await getDownloadsDirectory();
      }
      
      if (downloadsDir == null) {
        print("FileSharingReceiver: Could not determine a writable directory.");
        onError?.call("Could not determine a writable directory for '$originalFileName'.");
        return null;
      }

      // --- MODIFIED: Renaming Logic ---
      String finalPath = p.join(downloadsDir.path, originalFileName);
      String baseName = p.basenameWithoutExtension(originalFileName);
      String extension = p.extension(originalFileName);
      int count = 1;

      // Loop to find a unique file name.
      while (await File(finalPath).exists()) {
        String newName = '$baseName ($count)$extension';
        finalPath = p.join(downloadsDir.path, newName);
        count++;
      }
      // --- End of Renaming Logic ---
      
      print("FileSharingReceiver: Reading temporary file '$tempFilePathWithPart'.");
      final Uint8List fileBytes = await tempFile.readAsBytes();
      
      print("FileSharingReceiver: Attempting to save file to: '$finalPath'");
      final File finalFile = File(finalPath);
      await finalFile.writeAsBytes(fileBytes);

      print("FileSharingReceiver: File saved successfully to: '$finalPath'");
      await tempFile.delete();
      print("FileSharingReceiver: Temporary file '$tempFilePathWithPart' deleted.");
      return finalPath; // Return the actual path where the file was saved

    } catch (e, s) {
      print("FileSharingReceiver: Error during finalizeSave: $e\n$s");
      String errorMessage = "Failed to save '$originalFileName': $e";
       if (Platform.isAndroid && e is FileSystemException) {
         if (e.osError?.errorCode == 13 || e.osError?.errorCode == 1) { // EACCES or EPERM
             errorMessage = "Failed to save '$originalFileName' due to permission issues on Android.";
         }
       }
      onError?.call(errorMessage);
      return null;
    }
  }
}
