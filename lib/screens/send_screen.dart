import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'dart:io'; // For File class
import 'package:file_picker/file_picker.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/screens/dialogs/select_receiver_dialog.dart';
import 'package:flutter_shareit/utils/file_utils.dart';
import '../utils/sharing_discovery_service.dart'; // Adjust path if needed

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final Map<String, SharedFile> _selectedFiles = {};

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);

      if (result != null) {
        setState(() {
          for (var file in result.files) {
            _selectedFiles[file.path!] = SharedFile(
              fileName: file.name,
              fileSize: file.size,
              fileCrc: file.hashCode,
            );
          }
        });
        print(_selectedFiles.values.map((x) => x.toProto3Json()));
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
      print("Error picking file or starting broadcast: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file,
              size: 100,
              color: Colors.grey[400],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Card(
                elevation: 2,
                child: Column(
                  children:
                      _selectedFiles.entries
                          .map(
                            (entry) => ListTile(
                              leading: const Icon(Icons.description),
                              title: Text(
                                entry.value.fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Size: ${fileSizeToHuman(entry.value.fileSize)}',
                              ),
                              trailing: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedFiles.remove(entry.key);
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
                      _selectedFiles.isNotEmpty ? 'Add More Files' : 'Select Files',
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
                if (_selectedFiles.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final receiver = await showSelectReceiverDialog(context: context);
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
