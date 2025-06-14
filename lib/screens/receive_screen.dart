import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

// Your project-specific imports
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:flutter_shareit/utils/file_sharing/file_sharing_receiver.dart';
import 'package:flutter_shareit/utils/auth_utils.dart';
import 'package:flutter_shareit/models/received_file_item.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _discoverable = SharingDiscoveryService.isDiscoverable;
  List<ReceivedFileItem> _receivedFiles = [];
  bool _receivingBegun = false;
  bool _transferComplete = false;
  late FileSharingReceiver _receiver;

  String _errorMessage = "";

  final AuthenticationService _authService = AuthenticationService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.getCurrentUserId();

    _receiver = FileSharingReceiver(
      onFileProgress: (fileProgressList) {
        if (!mounted) return;
        setState(() {
          _receivingBegun = true;
          _errorMessage = "";
          _transferComplete = false;

          Map<String, ReceivedFileItem> existingFilesMap = {
            for (var item in _receivedFiles) item.sharedFile.fileName: item
          };

          List<ReceivedFileItem> newReceivedFilesList = [];
          for (var tuple in fileProgressList) {
            final SharedFile sharedFile = tuple.$1;
            final int receivedBytes = tuple.$2;

            ReceivedFileItem? existingItem = existingFilesMap[sharedFile.fileName];
            if (existingItem != null) {
              // Ensure we copy from the *existing* item in the map,
              // preserving any 'isSaving' or 'errorMessage' flags that might have been set
              newReceivedFilesList.add(existingItem.copyWith(
                receivedBytes: receivedBytes,
                // Do not reset isSaving or errorMessage here;
                // _saveFilePermanently handles those for its specific item
              ));
            } else {
              newReceivedFilesList.add(ReceivedFileItem(
                sharedFile: sharedFile,
                receivedBytes: receivedBytes,
              ));
            }
          }
          _receivedFiles = newReceivedFilesList;
        });
      },
      onFileReceivedToTemp: (fileData) {
        if (!mounted) return;
        SharedFile fileMeta = fileData[0] as SharedFile;
        String tempPath = fileData[1] as String;

        // Find the item by its unique properties, not by object reference
        final index = _receivedFiles.indexWhere((item) =>
            item.sharedFile.fileName == fileMeta.fileName &&
            item.sharedFile.fileSize == fileMeta.fileSize);

        if (index != -1) {
          // Copy from the current item in the list
          _receivedFiles[index] = _receivedFiles[index].copyWith(
            tempFilePath: tempPath,
            receivedBytes: fileMeta.fileSize.toInt(),
          );
          setState(() {
            // State updated, now UI will rebuild to show 'Save' button.
          });
          print("ReceiveScreen: File '${fileMeta.fileName}' ready to save, temp path set.");
        } else {
          print("ReceiveScreen: onFileReceivedToTemp: Received file meta for unknown file: ${fileMeta.fileName}");
        }
      },
      onTransferComplete: () {
        if (!mounted) return;
        setState(() {
          _transferComplete = true;
          _receivingBegun = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All files received!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        SharingDiscoveryService.stopBroadcast();
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
          _transferComplete = false;
          // Optionally, set error state for specific file if possible, e.g.,
          // if (message.contains("for file X")) {
          //   final fileName = extractFileNameFromMessage(message);
          //   final index = _receivedFiles.indexWhere((item) => item.sharedFile.fileName == fileName);
          //   if (index != -1) {
          //     _receivedFiles[index] = _receivedFiles[index].copyWith(
          //       isSaving: false,
          //       errorMessage: message,
          //     );
          //   }
          // }
        });
      },
    );
  }

  Future<void> _saveFilePermanently(ReceivedFileItem itemToSave) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in. Cannot save file.")),
      );
      return;
    }
    if (itemToSave.tempFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Temporary file path is missing.")),
      );
      return;
    }
    if (itemToSave.isSaving) { // Check the passed item's saving state
      print("ReceiveScreen: Already saving ${itemToSave.sharedFile.fileName}");
      return;
    }

    // Find the item in the current list using a unique identifier
    // This is crucial because _receivedFiles might have been rebuilt by other callbacks
    final int initialIndex = _receivedFiles.indexWhere(
      (element) => element.sharedFile.fileName == itemToSave.sharedFile.fileName &&
                   element.sharedFile.fileSize == itemToSave.sharedFile.fileSize,
    );

    if (initialIndex != -1) {
      setState(() {
        _receivedFiles[initialIndex] = _receivedFiles[initialIndex].copyWith(
          isSaving: true,
          errorMessage: null,
        );
      });
    } else {
      print("ReceiveScreen: Warning: Item to save not found in _receivedFiles list for initial state update.");
      // Potentially add a snackbar for this unexpected case if it happens often.
      return; // Abort if we can't find the item to update its state
    }


    final ui.RootIsolateToken? rootIsolateToken = ServicesBinding.rootIsolateToken;

    if (rootIsolateToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Could not obtain RootIsolateToken. Cannot save file.")),
      );
      // Ensure saving state is reset if we abort here
      if (initialIndex != -1) {
        setState(() {
          _receivedFiles[initialIndex] = _receivedFiles[initialIndex].copyWith(
            isSaving: false,
            errorMessage: "Missing isolate token",
          );
        });
      }
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    String? finalPathResult = await _receiver.finalizeSave(
      itemToSave.tempFilePath!, // Use the passed item's temp path
      itemToSave.sharedFile.fileName,
      itemToSave.sharedFile.fileSize.toInt(),
      itemToSave.sharedFile.senderId,
      itemToSave.sharedFile.senderName,
      _currentUserId!,
      rootIsolateToken,
    );

    if (!mounted) return;

    // Find the item again after save completes, as list might have changed
    final int finalIndex = _receivedFiles.indexWhere(
      (element) => element.sharedFile.fileName == itemToSave.sharedFile.fileName &&
                   element.sharedFile.fileSize == itemToSave.sharedFile.fileSize,
    );

    setState(() {
      if (finalIndex != -1) {
        if (finalPathResult != null && !finalPathResult.startsWith("Error:")) {
          _receivedFiles[finalIndex] = _receivedFiles[finalIndex].copyWith(
            finalPath: finalPathResult,
            isSaving: false, // <-- Set to false
            errorMessage: null,
          );
          messenger.showSnackBar(
              SnackBar(content: Text("${p.basename(finalPathResult)} saved!")));
        } else {
          _receivedFiles[finalIndex] = _receivedFiles[finalIndex].copyWith(
            isSaving: false, // <-- Set to false
            errorMessage: finalPathResult?.substring(7) ?? "Unknown save error",
          );
          messenger.showSnackBar(
              SnackBar(content: Text("Failed to save ${itemToSave.sharedFile.fileName}.")),
          );
        }
      } else {
          print("ReceiveScreen: Error: Item to save not found in _receivedFiles list for final state update.");
          // If the item somehow disappeared, the UI might be out of sync.
      }
    });
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

  String fileSizeToHuman(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  void dispose() {
    SharingDiscoveryService.stopBroadcast();
    _receiver.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(
        child: Text(
          "Please log in to receive files.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    String statusText;
    if (_errorMessage.isNotEmpty) {
      statusText = "Error: $_errorMessage";
    } else if (_transferComplete) {
      statusText = "Transfer Complete!";
    } else if (_receivingBegun) {
      statusText = "Receiving files...";
    } else if (_discoverable) {
      statusText = "Waiting for sender...";
    } else {
      statusText = "Press 'Start Receiving'";
    }

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
                statusText,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text("Incoming Files:", style: Theme.of(context).textTheme.titleSmall),
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 2,
                  child: _receivedFiles.isEmpty
                      ? const Center(child: Text("Ready to receive. Files will appear here."))
                      : ListView.builder(
                          itemCount: _receivedFiles.length,
                          itemBuilder: (_, i) {
                            final item = _receivedFiles[i];

                            Widget trailingWidget;
                            if (item.hasError) {
                              trailingWidget = const Icon(Icons.error, color: Colors.red);
                            } else if (item.isPermanentlySaved) {
                              trailingWidget = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Saved ", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                                ],
                              );
                            } else if (item.isSaving) { // This is the state we are trying to manage
                              trailingWidget = const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            } else if (item.isTempComplete) {
                              trailingWidget = ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                                onPressed: () => _saveFilePermanently(item),
                                child: const Text("Save"),
                              );
                            } else {
                              trailingWidget = Text("${(item.progress * 100).toStringAsFixed(0)}%");
                            }

                            return ListTile(
                              leading: const Icon(Icons.description),
                              title: Text(item.sharedFile.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  'Sent from: ${item.sharedFile.senderName} - Size: ${fileSizeToHuman(item.sharedFile.fileSize.toInt())} ${item.hasError ? "(Error: ${item.errorMessage})" : ""}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                              ),
                              trailing: trailingWidget,
                              onTap: item.isPermanentlySaved
                                  ? () => _openFile(item.finalPath!, p.basename(item.finalPath!))
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
                      _transferComplete = false;
                      _errorMessage = "";
                      _receivedFiles.clear();
                    });
                    await SharingDiscoveryService.stopBroadcast();
                    await _receiver.stop();
                  } else {
                    setState(() {
                      _receivedFiles.clear();
                      _receivingBegun = false;
                      _transferComplete = false;
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