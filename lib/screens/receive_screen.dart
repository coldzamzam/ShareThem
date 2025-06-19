import 'dart:async';
import 'dart:io';
import 'dart:math'; // For fileSizeToHuman utility
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/file_sharing_receiver.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';
import 'package:flutter_shareit/utils/file_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _discoverable = SharingDiscoveryService.isDiscoverable;
  List<(SharedFile, int)> _sharedFiles = [];
  bool _receivingBegun = false;
  late FileSharingReceiver _receiver;

  final Map<String, String> _tempFilePaths = {};
  final List<Map<String, String>> _successfullySavedFilesData = [];
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _receiver = FileSharingReceiver(
      onFileProgress: (updatedFilesProgress) {
        if (!mounted) return;
        setState(() {
          _receivingBegun = true;
          _errorMessage = "";

          for (var newFileTuple in updatedFilesProgress) {
            final SharedFile newSharedFile = newFileTuple.$1;
            final int newReceivedBytes = newFileTuple.$2;

            final int index = _sharedFiles.indexWhere((f) => f.$1.fileName == newSharedFile.fileName);

            if (index != -1) {
              _sharedFiles[index] = (newSharedFile, newReceivedBytes);
            } else {
              _sharedFiles.add((newSharedFile, newReceivedBytes));
            }
          }
          _sharedFiles = List.from(_sharedFiles);
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
            _sharedFiles[index] = (file, file.fileSize.toInt());
          } else {
            _sharedFiles.add((file, file.fileSize.toInt()));
          }
          _sharedFiles = List.from(_sharedFiles);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file $fileName: ${result.message}'),
          backgroundColor: Colors.orange,
        ),
      );
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
    const Color primaryLight = Color(0xFFAA88CC);
    const Color primaryDark = Color(0xFF554DDE);
    const Color backgroundStart = Color(0xFFF9F5FF);
    const Color backgroundEnd = Color(0xFFEEEBFF);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundStart, backgroundEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: _discoverable
                      ? const Icon(
                          Icons.wifi_tethering,
                          size: 120,
                          key: ValueKey(1),
                          color: primaryDark,
                        )
                      : Icon(
                          Icons.wifi_tethering_off,
                          size: 120,
                          color: primaryLight.withOpacity(0.6),
                          key: const ValueKey(0),
                        ),
                ),
                const SizedBox(height: 20),
                Text(
                  _discoverable
                      ? "Waiting for sender..."
                      : (_receivingBegun ? "Receiving files..." : "Press 'Start Receiving'"),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryDark.withOpacity(0.8),
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                Text(
                  "Incoming Files:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryDark.withOpacity(0.9),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    elevation: 10,
                    shadowColor: primaryDark.withOpacity(0.1),
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20.0),
                      child: _sharedFiles.isEmpty
                          ? Center(
                              child: Text(
                                "Ready to receive. Files will appear here.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _sharedFiles.length,
                              itemBuilder: (_, i) {
                                final fileTuple = _sharedFiles[i];
                                final sharedFile = fileTuple.$1;
                                final receivedBytes = fileTuple.$2;
                                final progress = (sharedFile.fileSize == 0)
                                    ? 0.0
                                    : (receivedBytes / sharedFile.fileSize);
                                final bool isSaved = _successfullySavedFilesData
                                    .any((savedFile) => savedFile['name'] == sharedFile.fileName);
                                final bool isReadyToSave = _tempFilePaths.containsKey(sharedFile.fileName);

                                Widget trailingWidget;
                                if (isSaved) {
                                  trailingWidget = Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Saved ",
                                        style: TextStyle(
                                          color: primaryDark.withOpacity(0.8),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Icon(Icons.check_circle, color: primaryDark),
                                    ],
                                  );
                                } else if (isReadyToSave) {
                                  trailingWidget = ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      backgroundColor: primaryLight,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 3,
                                    ),
                                    onPressed: () async {
                                      String? tempPath = _tempFilePaths[sharedFile.fileName];
                                      if (tempPath == null) return;

                                      final messenger = ScaffoldMessenger.of(context);
                                      String? finalPath = await _receiver.finalizeSave(tempPath, sharedFile.fileName);

                                      if (finalPath != null && finalPath.isNotEmpty) {
                                        final user = _auth.currentUser;
                                        if (user != null) {
                                          try {
                                            final file = File(finalPath);
                                            final fileStat = await file.stat();
                                            final fileSize = fileStat.size;

                                            await _firestore
                                                .collection('users')
                                                .doc(user.uid)
                                                .collection('saved_files')
                                                .add({
                                              'name': sharedFile.fileName,
                                              'path': finalPath,
                                              'size': fileSize.toString(),
                                              'timestamp': FieldValue.serverTimestamp(),
                                              'modified': DateTime.now().toIso8601String(),
                                            });
                                            print("File metadata saved to Firestore for ${user.uid}: ${sharedFile.fileName}");
                                          } catch (e) {
                                            print("Error saving file metadata to Firestore: $e");
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text("Error saving history for ${sharedFile.fileName}."),
                                              ),
                                            );
                                          }
                                        } else {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text("Not logged in. File saved locally but not to history."),
                                            ),
                                          );
                                        }
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text("${sharedFile.fileName} saved! Path: $finalPath"),
                                          ),
                                        );
                                        if (!mounted) return;
                                        setState(() {
                                          if (!_successfullySavedFilesData.any((f) => f['name'] == sharedFile.fileName)) {
                                            _successfullySavedFilesData.add({
                                              'name': sharedFile.fileName,
                                              'path': finalPath,
                                            });
                                          }
                                        });
                                      } else {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text("Failed to save ${sharedFile.fileName}."),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text("Save"),
                                  );
                                } else {
                                  trailingWidget = SizedBox(
                                    width: 90,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: backgroundEnd,
                                          valueColor: const AlwaysStoppedAnimation<Color>(primaryDark),
                                          minHeight: 4,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${(progress * 100).toStringAsFixed(0)}%",
                                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[100]!,
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: primaryLight.withOpacity(0.1),
                                      child: const Icon(Icons.file_present, color: primaryDark, size: 28),
                                    ),
                                    title: Text(
                                      sharedFile.fileName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: Color(0xFF333333),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      'Size: ${fileSizeToHuman(sharedFile.fileSize)}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                    trailing: trailingWidget,
                                    onTap: isSaved
                                        ? () {
                                            final savedFile = _successfullySavedFilesData.firstWhere((f) => f['name'] == sharedFile.fileName);
                                            _openFile(savedFile['path']!, savedFile['name']!);
                                          }
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        colors: _discoverable
                            ? [Colors.grey[400]!, Colors.grey[600]!]
                            : [primaryLight, primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _discoverable ? Colors.grey[400]!.withOpacity(0.3) : primaryDark.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      _discoverable ? 'Stop Receiving' : 'Start Receiving',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
