import 'package:flutter/material.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/file_sharing_receiver.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_shareit/utils/file_utils.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _discoverable = false; // Start as non-discoverable
  List<(SharedFile, int)> _sharedFiles = [];
  bool _receivingBegun = false;
  late FileSharingReceiver _receiver;

  final Map<String, String> _tempFilePaths = {};
  final List<Map<String, String>> _successfullySavedFilesData = [];
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    // Initialize receiver but don't start it automatically
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
          // Store the temp path against the file name for the "Save All" feature
          _tempFilePaths[file.fileName] = tempPath;
          
          final index = _sharedFiles.indexWhere((f) => f.$1.fileName == file.fileName);
          if (index != -1) {
            // Ensure progress is marked as 100%
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
  
  // ================= IMPROVEMENT START: "Save All" Logic =================
  Future<void> _saveAllReadyFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    final filesToSave = <String, String>{};

    // Collect all files that are ready to be saved but haven't been saved yet.
    _tempFilePaths.forEach((fileName, tempPath) {
      final isAlreadySaved = _successfullySavedFilesData.any((savedFile) => savedFile['name'] == fileName);
      if (!isAlreadySaved) {
        filesToSave[fileName] = tempPath;
      }
    });

    if (filesToSave.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text("No new files to save.")));
      return;
    }
    
    messenger.showSnackBar(SnackBar(content: Text("Saving ${filesToSave.length} files...")));

    // ============================ FIX START ============================
    // The new receiver expects a map of {fileName: tempPath}.
    // We no longer need to invert the map.
    final results = await _receiver.finalizeSaveAll(filesToSave);
    // ============================ FIX END ============================

    if (!mounted) return;

    if (results.isNotEmpty) {
      setState(() {
        for (final savedFile in results) {
          if (!_successfullySavedFilesData.any((f) => f['name'] == savedFile['name'])) {
            _successfullySavedFilesData.add(savedFile);
          }
        }
      });
       messenger.showSnackBar(SnackBar(
        content: Text("${results.length} files saved successfully!"),
        backgroundColor: Colors.green,
      ));
    }
    
    if (results.length < filesToSave.length) {
       messenger.showSnackBar(SnackBar(
        content: Text("Failed to save ${filesToSave.length - results.length} files."),
        backgroundColor: Colors.red,
      ));
    }
  }
  // ================= IMPROVEMENT END: "Save All" Logic =================

  @override
  Widget build(BuildContext context) {
    // Check if there are any files ready to be saved
    final bool canSaveAll = _tempFilePaths.isNotEmpty && _tempFilePaths.keys.any((fileName) => 
        !_successfullySavedFilesData.any((savedFile) => savedFile['name'] == fileName));

    return Scaffold(
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
                    // Check if file is fully downloaded but not necessarily saved yet
                    final bool isDownloadComplete = progress >= 1.0;

                    Widget trailingWidget;
                    if (isSaved) {
                      trailingWidget = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Saved ", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                          Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                        ],
                      );
                    } else if (isDownloadComplete) {
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text('Size: ${fileSizeToHuman(sharedFile.fileSize)}'),
                           if(progress > 0 && progress < 1)
                              LinearProgressIndicator(value: progress, minHeight: 6,),
                        ],
                      ),
                      trailing: trailingWidget,
                      onTap: isSaved
                          ? () {
                        final savedFile = _successfullySavedFilesData.firstWhere((f) => f['name'] == sharedFile.fileName);
                        _openFile(savedFile['path']!, savedFile['name']!);
                      }
                          : null,
                    );
                  },
                ),
                ),
              ),
              const SizedBox(height: 20),
              
              // ================= IMPROVEMENT START: Action Buttons =================
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   GestureDetector(
                      onTap: () async {
                        if (_discoverable) {
                          setState(() {
                            _discoverable = false;
                            // Do not clear files when stopping
                          });
                          await SharingDiscoveryService.stopBroadcast();
                          await _receiver.stop();
                        } else {
                          setState(() {
                            _sharedFiles.clear();
                            _tempFilePaths.clear();
                            _successfullySavedFilesData.clear();
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFAA88CC), Color(0xFF554DDE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Text(
                          _discoverable ? 'Stop Receiving' : 'Start Receiving',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Show "Save All" button if there are files ready to be saved
                    if(canSaveAll) ...[
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_alt),
                        label: const Text("Save All"),
                        onPressed: _saveAllReadyFiles,
                        style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.green[600],
                           foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                           textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600
                           )
                        ),
                      ),
                    ]
                ],
              ),
              // ================= IMPROVEMENT END: Action Buttons =================
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
