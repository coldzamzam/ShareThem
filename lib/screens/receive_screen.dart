import 'package:flutter/material.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart'; // Sesuaikan path jika perlu
import 'package:flutter_shareit/utils/file_sharing/file_sharing_receiver.dart'; // Sesuaikan path jika perlu
import 'package:flutter_shareit/utils/file_utils.dart'; // Sesuaikan path jika perlu
import 'package:flutter_shareit/utils/sharing_discovery_service.dart'; // Sesuaikan path jika perlu
import 'package:open_file/open_file.dart'; // Import open_file

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

  // State untuk file yang sedang ditransfer dan siap disimpan
  final Map<String, String> _tempFilePaths = {}; // fileName -> tempPath

  // State untuk file yang telah berhasil disimpan
  // Setiap map akan berisi {'name': fileName, 'path': filePath}
  final List<Map<String, String>> _successfullySavedFilesData = []; 

  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _receiver = FileSharingReceiver(
      onFileProgress: (files) {
        if (!mounted) return;
        // Tidak mengubah _discoverable di sini agar user bisa stop manual jika mau
        setState(() {
          _receivingBegun = true;
          _sharedFiles = files;
          _errorMessage = "";
        });
      },
      onFileReceivedToTemp: (fileData) {
        // fileData adalah [SharedFile, String tempPath]
        if (!mounted) return;
        SharedFile file = fileData[0] as SharedFile;
        String tempPath = fileData[1] as String;
        setState(() {
          _tempFilePaths[file.fileName] = tempPath;
          // Pastikan progress 100% di UI untuk file yang selesai ke temp
          final index = _sharedFiles.indexWhere((f) => f.$1.fileName == file.fileName);
          if (index != -1) {
            if (_sharedFiles[index].$2 < file.fileSize) {
               _sharedFiles[index] = (file, file.fileSize.toInt());
            }
          } else {
            // Jika file tidak ada di _sharedFiles, tambahkan dengan progress 100%
            // Ini seharusnya tidak terjadi jika GetSharedFilesRsp sudah diproses dengan benar
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

  @override
  void dispose() {
    SharingDiscoveryService.stopBroadcast();
    _receiver.stop();
    super.dispose();
  }

  Future<void> _openFile(String filePath, String fileName) async {
    print("Attempting to open file: $filePath");
    final OpenResult result = await OpenFile.open(filePath);
    print("OpenFile result: ${result.type}, message: ${result.message}");

    if (result.type != ResultType.done) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file $fileName: ${result.message}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Files')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Durations.short2,
                child: _discoverable
                    ? const Icon(
                        Icons.wifi_tethering,
                        size: 100,
                        key: ValueKey(1),
                        color: Colors.blue,
                      )
                    : Icon(
                        Icons.wifi_tethering_off,
                        size: 100,
                        color: Colors.grey[400],
                        key: ValueKey(0),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                _discoverable ? "Waiting for sender..." : (_receivingBegun ? "Receiving files..." : "Press 'Start Receiving'"),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_errorMessage, style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              Text("Incoming Files:", style: Theme.of(context).textTheme.titleSmall),
              Expanded(
                flex: 2, // Beri lebih banyak ruang untuk daftar incoming
                child: Card(
                  elevation: 2,
                  child: _sharedFiles.isEmpty && _receivingBegun && !_discoverable
                    ? const Center(child: Text("No files announced by sender yet."))
                    : _sharedFiles.isEmpty && !_receivingBegun
                        ? const Center(child: Text("Ready to receive. Files will appear here."))
                        : ListView.builder(
                            itemCount: _sharedFiles.length,
                            itemBuilder: (_, i) {
                              final fileTuple = _sharedFiles[i];
                              final sharedFile = fileTuple.$1;
                              final receivedBytes = fileTuple.$2;
                              final progress = (sharedFile.fileSize == 0) ? 0.0 : (receivedBytes / sharedFile.fileSize);
                              final bool isSaved = _successfullySavedFilesData.any((savedFile) => savedFile['name'] == sharedFile.fileName);
                              final bool isReadyToSave = _tempFilePaths.containsKey(sharedFile.fileName);

                              Widget trailingWidget;
                              if (isSaved) {
                                trailingWidget = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Saved ", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary), // Ikon lebih jelas
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
                                      messenger.showSnackBar(
                                        SnackBar(content: Text("${sharedFile.fileName} saved! Path: $finalPath")),
                                      );
                                      if (!mounted) return;
                                      setState(() {
                                        // Tambahkan ke daftar file yang berhasil disimpan
                                        if (!_successfullySavedFilesData.any((f) => f['name'] == sharedFile.fileName)) {
                                          _successfullySavedFilesData.add({'name': sharedFile.fileName, 'path': finalPath});
                                        }
                                        // _tempFilePaths.remove(sharedFile.fileName); // Opsional: hapus agar tombol tidak muncul lagi jika hanya bisa disimpan sekali
                                      });
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text("Failed to save ${sharedFile.fileName}. User might have cancelled or an error occurred.")),
                                      );
                                    }
                                  },
                                  child: const Text("Save"),
                                );
                              } else {
                                trailingWidget = Text("${(progress * 100).toStringAsFixed(0)}%");
                              }

                              return ListTile(
                                leading: const Icon(Icons.description),
                                title: Text(
                                  sharedFile.fileName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  'Size: ${fileSizeToHuman(sharedFile.fileSize)} | Progress: ${(progress * 100).toStringAsFixed(0)}%',
                                ),
                                trailing: trailingWidget,
                              );
                            },
                          ),
                ),
              ),
              const SizedBox(height: 20),
              Text("Saved Files:", style: Theme.of(context).textTheme.titleSmall),
              Expanded(
                flex: 1, // Beri ruang untuk daftar file yang disimpan
                child: Card(
                  elevation: 2,
                  child: _successfullySavedFilesData.isEmpty
                      ? const Center(child: Text("No files saved yet in this session."))
                      : ListView.builder(
                          itemCount: _successfullySavedFilesData.length,
                          itemBuilder: (context, index) {
                            final savedFile = _successfullySavedFilesData[index];
                            final fileName = savedFile['name']!;
                            final filePath = savedFile['path']!;
                            return ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: Text(fileName),
                              subtitle: Text(filePath, style: const TextStyle(fontSize: 10)),
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new),
                                tooltip: 'Open File',
                                onPressed: () => _openFile(filePath, fileName),
                              ),
                              onTap: () => _openFile(filePath, fileName), // Juga bisa dibuka dengan tap
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
                       // _successfullySavedFilesData.clear(); // Opsional: bersihkan daftar file tersimpan saat memulai sesi baru
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
                  backgroundColor: _discoverable
                      ? Theme.of(context).colorScheme.error 
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
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
