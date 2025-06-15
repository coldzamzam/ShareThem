import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:collection'; // Import for Queue

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

  // Queue for files to be permanently saved (processed by a separate async task)
  final Queue<ReceivedFileItem> _filesToSaveQueue = Queue<ReceivedFileItem>();
  bool _isProcessingSaveQueue = false; // Flag to prevent multiple queue processors

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
              newReceivedFilesList.add(existingItem.copyWith(
                receivedBytes: receivedBytes,
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

        final int index = _receivedFiles.indexWhere((item) =>
            item.sharedFile.fileName == fileMeta.fileName &&
            item.sharedFile.fileSize == fileMeta.fileSize);

        if (index != -1) {
          // Update the item as temp complete
          ReceivedFileItem updatedItem = _receivedFiles[index].copyWith(
            tempFilePath: tempPath,
            receivedBytes: fileMeta.fileSize.toInt(), // Ensure full size is reflected
            isTempComplete: true, // Explicitly mark as temp complete
          );
          _receivedFiles[index] = updatedItem; // Update local state
          setState(() {
            // UI will rebuild, showing the "Save" button for this item
          });
          print("ReceiveScreen: File '${fileMeta.fileName}' received to temp. Temp path: $tempPath. Awaiting manual save.");
        } else {
          print("ReceiveScreen: onFileReceivedToTemp: Received file meta for unknown file: ${fileMeta.fileName}");
        }
      },
      onTransferComplete: () {
        if (!mounted) return;
        setState(() {
          _transferComplete = true;
          _receivingBegun = false; // Transfer is complete, not actively receiving data
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All files transferred to temporary storage!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        SharingDiscoveryService.stopBroadcast();
        // Saving is now manual, so we don't automatically trigger queue processing here.
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
        });
        // On a major error, stop any ongoing save queue processing to prevent further issues.
        _isProcessingSaveQueue = false;
      },
    );
  }

  // --- Queue processing logic ---
  void _startProcessingSaveQueue() {
    if (_isProcessingSaveQueue) {
      return; // Already processing
    }
    _isProcessingSaveQueue = true;
    _processSaveQueue(); // Start the async processing
  }

  Future<void> _processSaveQueue() async {
    while (_filesToSaveQueue.isNotEmpty && mounted) {
      final itemToSave = _filesToSaveQueue.removeFirst(); // Get next item from queue

      // Update UI to show 'Saving...' for this specific item BEFORE saving
      // This is important to give immediate feedback when the button is pressed.
      final int initialIndex = _receivedFiles.indexWhere(
        (element) => element.sharedFile.fileName == itemToSave.sharedFile.fileName &&
                     element.sharedFile.fileSize == itemToSave.sharedFile.fileSize,
      );

      if (initialIndex != -1) {
        setState(() {
          _receivedFiles[initialIndex] = _receivedFiles[initialIndex].copyWith(
            isSaving: true,
            errorMessage: null, // Clear previous error if retrying
          );
        });
      } else {
        print("ReceiveScreen: Warning: Item to save from queue not found in _receivedFiles list for initial state update.");
        continue; // Skip this item if not found, move to next in queue
      }

      await _saveFilePermanentlyLogic(itemToSave); // Call the actual save logic
    }
    // Only set to false if the queue is truly empty and no more processing is needed
    if (_filesToSaveQueue.isEmpty) {
        _isProcessingSaveQueue = false;
        print("ReceiveScreen: Save queue processing finished.");
    }
  }

  // This is the actual save logic, now triggered by the queue
  Future<void> _saveFilePermanentlyLogic(ReceivedFileItem itemToSave) async {
    if (_currentUserId == null) {
      _updateReceivedFileItemState(itemToSave, isSaving: false, errorMessage: "User not logged in. Cannot save file.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in. Cannot save file.")),
      );
      return;
    }
    if (itemToSave.tempFilePath == null) {
      _updateReceivedFileItemState(itemToSave, isSaving: false, errorMessage: "Temporary file path is missing.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Temporary file path is missing.")),
      );
      return;
    }

    final ui.RootIsolateToken? rootIsolateToken = ServicesBinding.rootIsolateToken;

    if (rootIsolateToken == null) {
      _updateReceivedFileItemState(itemToSave, isSaving: false, errorMessage: "Could not obtain RootIsolateToken. Cannot save file.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Could not obtain RootIsolateToken. Cannot save file.")),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    String? finalPathResult = await _receiver.finalizeSave(
      itemToSave.tempFilePath!,
      itemToSave.sharedFile.fileName,
      itemToSave.sharedFile.fileSize.toInt(),
      itemToSave.sharedFile.senderId,
      itemToSave.sharedFile.senderName,
      _currentUserId!,
      rootIsolateToken,
    );

    if (!mounted) return;

    if (finalPathResult != null && !finalPathResult.startsWith("Error:")) {
      _updateReceivedFileItemState(itemToSave, finalPath: finalPathResult, isSaving: false, errorMessage: null);
      messenger.showSnackBar(
          SnackBar(content: Text("${p.basename(finalPathResult)} saved successfully!")));
    } else {
      _updateReceivedFileItemState(itemToSave, isSaving: false, errorMessage: finalPathResult?.substring(7) ?? "Unknown save error");
      messenger.showSnackBar(
          SnackBar(content: Text("Failed to save ${itemToSave.sharedFile.fileName}. Please try again.")),
      );
    }
  }

  // Helper to safely update a specific item's state in _receivedFiles
  void _updateReceivedFileItemState(
    ReceivedFileItem originalItem, {
    String? finalPath,
    bool? isSaving,
    String? errorMessage,
    bool? isTempComplete, // Added for clarity, though current use case relies on initial setting
  }) {
    if (!mounted) return;
    final int index = _receivedFiles.indexWhere(
      (element) => element.sharedFile.fileName == originalItem.sharedFile.fileName &&
                   element.sharedFile.fileSize == originalItem.sharedFile.fileSize,
    );
    if (index != -1) {
      setState(() {
        _receivedFiles[index] = _receivedFiles[index].copyWith(
          finalPath: finalPath,
          isSaving: isSaving,
          errorMessage: errorMessage,
          isTempComplete: isTempComplete, // Update if provided
        );
      });
    } else {
      print("ReceiveScreen: Warning: Item to update state for not found: ${originalItem.sharedFile.fileName}");
    }
  }
  // --- END Queue processing logic ---


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
    // Clear queue on dispose to prevent processing after widget is gone
    _filesToSaveQueue.clear();
    _isProcessingSaveQueue = false;
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
      statusText = "Transfer Complete! Awaiting saves.";
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
                            } else if (item.isSaving) {
                              trailingWidget = const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            } else if (item.isTempComplete) {
                              // --- MODIFIED: Display Save button when temp complete ---
                              trailingWidget = TextButton(
                                onPressed: () {
                                  // Add this item to the save queue
                                  _filesToSaveQueue.add(item);
                                  // Trigger the queue processing
                                  _startProcessingSaveQueue();
                                  // Optionally, update UI immediately to show "Saving..."
                                  // This is handled by _processSaveQueue
                                },
                                child: const Text("Save"),
                              );
                              // --- END MODIFIED ---
                            } else {
                              // Display progress while receiving chunks
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
                              onTap: item.isPermanentlySaved && item.finalPath != null
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
                      // Clear save queue on stop
                      _filesToSaveQueue.clear();
                      _isProcessingSaveQueue = false;
                    });
                    await SharingDiscoveryService.stopBroadcast();
                    await _receiver.stop();
                  } else {
                    setState(() {
                      _receivedFiles.clear();
                      _receivingBegun = false;
                      _transferComplete = false;
                      _errorMessage = "";
                      // Ensure queue is clear on start
                      _filesToSaveQueue.clear();
                      _isProcessingSaveQueue = false;
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