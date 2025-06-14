import 'package:flutter/material.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/file_sharing_receiver.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_shareit/utils/file_utils.dart';


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
                                    messenger.showSnackBar(SnackBar(content: Text("${sharedFile.fileName} saved! Path: $finalPath")));
                                    if (!mounted) return;
                                    setState(() {
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
                              subtitle: Text('Size: ${fileSizeToHuman(sharedFile.fileSize)}'),
                              trailing: trailingWidget,
                              // MODIFIED: Added onTap functionality
                              onTap: isSaved
                                  ? () {
                                      final savedFile = _successfullySavedFilesData.firstWhere((f) => f['name'] == sharedFile.fileName);
                                      _openFile(savedFile['path']!, savedFile['name']!);
                                    }
                                  : null, // ListTile is not tappable until the file is saved.
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
