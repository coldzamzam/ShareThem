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
import '../utils/sharing_discovery_service.dart';

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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File selection cancelled.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
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
              padding: const EdgeInsets.all(10),
              child: const SizedBox(
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
                  GestureDetector(
                    onTap: _pickFiles,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_file, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _selectedFiles.isNotEmpty ? 'Add More Files' : 'Select Files',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_selectedFiles.isNotEmpty && !_loading)
                  GestureDetector(
                    onTap: () async {
                      final receiver = await showSelectReceiverDialog(context: context);
                      if (receiver is ResolvedBonsoirService) {
                        fileSharingSender = FileSharingSender(
                          files: _selectedFiles,
                          serverHost: receiver.host!,
                          serverPort: receiver.port,
                        );
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Send Files',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
