import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/screens/dialogs/select_receiver_dialog.dart';
import 'package:flutter_shareit/utils/file_sharing/file_sharing_sender.dart';
import 'package:flutter_shareit/utils/file_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../utils/sharing_discovery_service.dart'; // Adjust path if needed

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  bool _loading = false;
  final List<(SharedFile, Stream<List<int>>)> _selectedFiles = [];
  FileSharingSender? fileSharingSender;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withReadStream: true,
      );

      if (result != null) {
        setState(() {
          _loading = true;
        });

        final tmpDir = p.join((await getTemporaryDirectory()).uri.toFilePath(), "send_cache");
        if (!Directory(tmpDir).existsSync()) {
          Directory(tmpDir).create();
        }

        for (var file in result.files) {
          final tmpFile = p.join(tmpDir, file.name);
          final crc = Crc32();
          final fFile = File(file.path!);

          final ws = File(tmpFile).openWrite();
          await for (final chunk in fFile.openRead()) {
            crc.add(chunk);
            ws.add(chunk);
          }
          await ws.close();

          print("done crc: ${crc.hash}");

          setState(() {
            _selectedFiles.add((
              SharedFile(
                fileName: file.name,
                fileSize: file.size,
                fileCrc: crc.hash,
              ),
              File(tmpFile).openRead(),
            ));
          });
        }
      } else {
        // User canceled the picker
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File selection cancelled.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error picking file: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    SharingDiscoveryService.stopDiscovery();
    fileSharingSender?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _loading
                ? Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                      height: 80,
                      width: 80,
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Icon(Icons.upload_file, size: 100, color: Colors.grey[400]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Card(
                  elevation: 2,
                  child: ListView(
                    children: _selectedFiles
                        .mapIndexed(
                          (i, entry) => ListTile(
                            leading: const Icon(Icons.description),
                            title: Text(
                              entry.$1.fileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Size: ${fileSizeToHuman(entry.$1.fileSize)}',
                            ),
                            trailing: IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFiles.removeAt(i);
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 10,
              children: [
                if (!SharingDiscoveryService.isSearching)
                  ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _selectedFiles.isNotEmpty
                          ? 'Add More Files'
                          : 'Select Files',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (_selectedFiles.isNotEmpty && !_loading)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final receiver = await showSelectReceiverDialog(
                        context: context,
                      );
                      print("select receiver dialog ret: $receiver");
                      if (receiver is ResolvedBonsoirService) {
                        fileSharingSender = FileSharingSender(
                          files: _selectedFiles,
                          serverHost: receiver.host!,
                          serverPort: receiver.port,
                        );
                        print("starting filesharingsender");
                        await fileSharingSender?.start();
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select a receiver first!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      await SharingDiscoveryService.stopDiscovery();
                    },
                    icon: const Icon(Icons.send),
                    label: const Text(
                      'Send Files',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Select a file to send to other devices.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
