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
  // Firebase instances
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
            // Update progress if file is already in list
            if (_sharedFiles[index].$2 < file.fileSize) {
              _sharedFiles[index] = (file, file.fileSize.toInt());
            }
          } else {
            // Add new file to list
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

  /// Opens a file using the open_file package.
  Future<void> _openFile(String filePath, String fileName) async {
    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open file $fileName: ${result.message}'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  /// Helper function to convert bytes to human-readable format.
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
    // Definisi warna utama aplikasi Anda
    const Color primaryLight = Color(0xFFAA88CC); // Ungu muda keunguan
    const Color primaryDark = Color(0xFF554DDE);  // Biru tua keunguan
    // Warna background baru yang Anda pilih
    const Color backgroundStart = Color(0xFFF9F5FF); // Lavender muda
    const Color backgroundEnd = Color(0xFFEEEBFF);   // Ungu sangat pucat

    return Container( // Mengganti Scaffold dengan Container untuk background
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundStart, backgroundEnd], // Menggunakan warna background yang Anda pilih
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold( // Menggunakan Scaffold di dalam Container agar tetap memiliki AppBar/Drawer dll.
        backgroundColor: Colors.transparent, // Membuat Scaffold transparan agar gradien terlihat
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0), // Padding sedikit lebih besar
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300), // Durasi animasi lebih halus
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child); // Animasi skala
                  },
                  child: _discoverable
                      ? Icon(
                          Icons.wifi_tethering,
                          size: 120, // Ukuran lebih besar
                          key: const ValueKey(1),
                          color: primaryDark, // Warna primaryDark saat discoverable
                        )
                      : Icon(
                          Icons.wifi_tethering_off,
                          size: 120, // Ukuran lebih besar
                          color: primaryLight.withOpacity(0.6), // Warna primaryLight dengan opacity saat off
                          key: const ValueKey(0),
                        ),
                ),
                const SizedBox(height: 20), // Spasi lebih besar
                Text(
                  _discoverable
                      ? "Waiting for sender..."
                      : (_receivingBegun ? "Receiving files..." : "Press 'Start Receiving'"),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18, // Ukuran font lebih besar
                    fontWeight: FontWeight.w600, // Lebih tebal
                    color: primaryDark.withOpacity(0.8), // Warna teks dari primaryDark
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500), // Warna merah yang lebih cerah
                  ),
                ],
                const SizedBox(height: 30), // Spasi lebih besar
                Text(
                  "Incoming Files:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryDark.withOpacity(0.9), // Warna teks dari primaryDark
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0), // Sudut Card lebih membulat
                    ),
                    elevation: 10, // Elevasi lebih tinggi
                    shadowColor: primaryDark.withOpacity(0.1), // Shadow dari primaryDark dengan opacity
                    margin: const EdgeInsets.symmetric(vertical: 10), // Margin vertikal
                    child: ClipRRect( // Penting untuk border radius pada ListView
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
                                final bool isSaved = _successfullySavedFilesData.any((savedFile) => savedFile['name'] == sharedFile.fileName);
                                final bool isReadyToSave = _tempFilePaths.containsKey(sharedFile.fileName);

                                Widget trailingWidget;
                                if (isSaved) {
                                  trailingWidget = Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Saved ",
                                        style: TextStyle(color: primaryDark.withOpacity(0.8), fontWeight: FontWeight.w600), // Warna teks Saved
                                      ),
                                      Icon(Icons.check_circle, color: primaryDark), // Icon check dengan primaryDark
                                    ],
                                  );
                                } else if (isReadyToSave) {
                                  trailingWidget = ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Padding tombol lebih besar
                                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), // Font lebih tebal
                                      backgroundColor: primaryLight, // Warna tombol Save dari primaryLight
                                      foregroundColor: Colors.white, // Warna teks tombol
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10), // Sudut tombol Save
                                      ),
                                      elevation: 3,
                                    ),
                                    onPressed: () async {
                                      String? tempPath = _tempFilePaths[sharedFile.fileName];
                                      if (tempPath == null) return;

                                      final messenger = ScaffoldMessenger.of(context);
                                      String? finalPath = await _receiver.finalizeSave(tempPath, sharedFile.fileName);

                                      if (finalPath != null && finalPath.isNotEmpty) {
                                        // --- START: Save file metadata to Firestore ---
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
                                            messenger.showSnackBar(SnackBar(content: Text("Error saving history for ${sharedFile.fileName}.")));
                                          }
                                        } else {
                                          messenger.showSnackBar(SnackBar(content: Text("Not logged in. File saved locally but not to history.")));
                                        }
                                        // --- END: Save file metadata to Firestore ---

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
                                  // Menggunakan LinearProgressIndicator dan Text
                                  trailingWidget = SizedBox(
                                    width: 90, // Lebar progress bar sedikit lebih lebar
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: backgroundEnd, // Background progress bar dari backgroundEnd
                                          valueColor: const AlwaysStoppedAnimation<Color>(primaryDark), // Warna progress bar dari primaryDark
                                          minHeight: 4, // Ketebalan progress bar
                                        ),
                                        const SizedBox(height: 4), // Spasi kecil
                                        Text(
                                          "${(progress * 100).toStringAsFixed(0)}%",
                                          style: TextStyle(fontSize: 12, color: Colors.grey[700]), // Warna teks persentase
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Container( // Membungkus ListTile untuk garis pemisah
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[100]!, // Garis pemisah yang sangat halus
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: primaryLight.withOpacity(0.1), // Background lingkaran icon file
                                      child: const Icon(Icons.file_present, color: primaryDark, size: 28), // Icon file yang lebih menonjol
                                    ),
                                    title: Text(
                                      sharedFile.fileName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF333333)),
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

                // Tombol Start/Stop Receiving
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
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14), // Padding lebih besar
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30), // Bentuk pil/capsule
                      gradient: LinearGradient(
                        colors: _discoverable ?
                          [Colors.grey[400]!, Colors.grey[600]!] : // Warna abu-abu saat stop
                          const [primaryLight, primaryDark], // Warna utama saat start
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _discoverable ?
                            Colors.grey[400]!.withOpacity(0.3) :
                            primaryDark.withOpacity(0.3),
                          blurRadius: 12, // Blur radius lebih besar
                          offset: const Offset(0, 6), // Offset shadow lebih besar
                        ),
                      ],
                    ),
                    child: Text(
                      _discoverable ? 'Stop Receiving' : 'Start Receiving',
                      style: const TextStyle(
                        fontSize: 16, // Ukuran font lebih besar
                        color: Colors.white,
                        fontWeight: FontWeight.w700, // Lebih tebal
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