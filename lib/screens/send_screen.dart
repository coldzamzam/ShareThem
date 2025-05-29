import 'package:flutter/material.dart';
import 'dart:io'; // For File class
import 'package:file_picker/file_picker.dart';
import '../utils/sharing_discovery_service.dart'; // Adjust path if needed

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  SharedFileInfo? _selectedFileInfo;
  bool _isBroadcasting = false;

  Future<void> _pickFileAndBroadcast() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        PlatformFile platformFile = result.files.first;
        File file = File(platformFile.path!);
        int fileSize = await file.length();

        setState(() {
          _selectedFileInfo = SharedFileInfo(
            name: platformFile.name,
            size: fileSize,
            path: platformFile.path,
          );
        });

        await SharingDiscoveryService.beginBroadcast(_selectedFileInfo!);
        setState(() {
          _isBroadcasting = SharingDiscoveryService.isBroadcasting;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcasting file: ${_selectedFileInfo!.name}'),
            duration: const Duration(seconds: 3),
          ),
        );
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

  Future<void> _stopBroadcasting() async {
    await SharingDiscoveryService.stopBroadcast();
    setState(() {
      _isBroadcasting = SharingDiscoveryService.isBroadcasting;
      // _selectedFileInfo = null; // Optionally clear selected file info
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Broadcasting stopped.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    // Decide if you want to automatically stop broadcasting when SendScreen is disposed
    // If you want it to persist even if user navigates away (within the app session),
    // then don't call stopBroadcast() here.
    // For this example, let's stop it when the screen is disposed.
    if (_isBroadcasting) {
      SharingDiscoveryService.stopBroadcast();
    }
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
            Icon(
              _isBroadcasting ? Icons.wifi_tethering_off : Icons.upload_file,
              size: 100,
              color: _isBroadcasting ? Colors.green : Colors.grey[400],
            ),
            const SizedBox(height: 20),
            if (_selectedFileInfo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(_selectedFileInfo!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Size: ${(_selectedFileInfo!.size / 1024).toStringAsFixed(2)} KB\nStatus: ${_isBroadcasting ? "Broadcasting" : "Ready to broadcast"}'),
                    trailing: _isBroadcasting ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  ),
                ),
              ),
            if (!_isBroadcasting)
              ElevatedButton.icon(
                onPressed: _pickFileAndBroadcast,
                icon: const Icon(Icons.attach_file),
                label: const Text(
                  'Select File & Start Broadcasting',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            if (_isBroadcasting)
              ElevatedButton.icon(
                onPressed: _stopBroadcasting,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text(
                  'Stop Broadcasting',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            const SizedBox(height: 40),
            const Text(
              'Select a file to make it discoverable by other devices on the network.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}