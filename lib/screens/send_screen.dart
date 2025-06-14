// lib/screens/send_screen.dart

import 'dart:io';
import 'package:archive/archive.dart'; // For CRC32 calculation
import 'package:bonsoir/bonsoir.dart'; // For Bonsoir service discovery
import 'package:collection/collection.dart'; // For mapIndexed
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For current user ID
import 'package:cloud_firestore/cloud_firestore.dart'; // For username from Firestore
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Your project-specific imports
import 'package:flutter_shareit/protos/sharethem.pb.dart'; // Will contain senderId, senderName
import 'package:flutter_shareit/screens/dialogs/select_receiver_dialog.dart'; // Assuming this dialog works
import 'package:flutter_shareit/utils/file_sharing/file_sharing_sender.dart';
import 'package:flutter_shareit/utils/file_utils.dart'; // For fileSizeToHuman
import 'package:flutter_shareit/utils/sharing_discovery_service.dart'; // Your provided service
import 'package:flutter_shareit/utils/auth_utils.dart';
import 'package:flutter_shareit/models/file_descriptor.dart';
import 'package:flutter_shareit/models/user.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  bool _loading = false; // Indicates if picking/sending is in progress
  final List<FileDescriptor> _selectedFileDescriptors = []; // Stores local file info
  FileSharingSender? fileSharingSender;

  // Real sender information
  final AuthenticationService _authService = AuthenticationService();
  String? _currentSenderUserId;
  String _currentSenderUsername = 'Loading User...';
  
  String _statusMessage = "Select files to send.";


  @override
  void initState() {
    super.initState();
    _loadSenderInfo(); // Fetch sender details on init
    // No need to stop discovery here explicitly unless it's managed globally.
    // The dialog itself should handle starting/stopping for its duration.
  }

  /// Fetches the current authenticated user's ID and username from Firebase/Firestore.
  Future<void> _loadSenderInfo() async {
    _currentSenderUserId = _authService.getCurrentUserId();
    if (_currentSenderUserId != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users') // Assuming your user profiles are stored here
            .doc(_currentSenderUserId!)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userProfile = UserProfile.fromMap(userDoc.data() as Map<String, dynamic>);
          setState(() {
            _currentSenderUsername = userProfile.username;
          });
        } else {
          setState(() {
            _currentSenderUsername = 'Anonymous User (Profile missing)';
          });
        }
      } catch (e) {
        print("Error fetching sender username from Firestore: $e");
        setState(() {
          _currentSenderUsername = 'Anonymous User (Error)';
        });
      }
    } else {
      setState(() {
        _currentSenderUsername = 'Not Logged In';
      });
    }
  }

  Future<void> _pickFiles() async {
    if (_currentSenderUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to select files for sending.")),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withReadStream: true,
      );

      if (result != null) {
        setState(() {
          _loading = true;
          _statusMessage = "Processing selected files...";
        });

        final List<FileDescriptor> newFileDescriptors = [];

        for (var file in result.files) {
          if (file.path != null) {
            final fFile = File(file.path!);
            final crc = Crc32();
            
            await for (final chunk in fFile.openRead()) {
              crc.add(chunk);
            }
            
            newFileDescriptors.add(
              FileDescriptor(
                fileName: file.name!,
                filePath: file.path!,
                fileSize: file.size!,
                fileCrc: crc.hash,
              ),
            );
          }
        }

        setState(() {
          _selectedFileDescriptors.addAll(newFileDescriptors);
          _statusMessage = "${_selectedFileDescriptors.length} files selected.";
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File selection cancelled.'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _statusMessage = "File selection cancelled.";
        });
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
      setState(() {
        _statusMessage = "Error during file selection: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _startSending() async {
    if (_currentSenderUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to send files.")),
      );
      return;
    }
    if (_selectedFileDescriptors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select files to send first.")),
      );
      return;
    }

    setState(() {
      _statusMessage = "Searching for receivers...";
      // Discovery for the dialog is handled internally by showSelectReceiverDialog
    });
    
    // Show receiver selection dialog. It should handle its own Bonsoir discovery.
    final receiver = await showSelectReceiverDialog(context: context);
    print("select receiver dialog ret: $receiver");

    if (receiver is ResolvedBonsoirService) {
      setState(() {
        _loading = true;
        _statusMessage = "Connecting to ${receiver.name}...";
      });

      final List<(SharedFile, Stream<List<int>>)> filesToTransmit = [];
      for (var descriptor in _selectedFileDescriptors) {
        final sharedFile = SharedFile(
          fileName: descriptor.fileName,
          fileSize: descriptor.fileSize,
          fileCrc: descriptor.fileCrc,
          senderId: _currentSenderUserId!,
          senderName: _currentSenderUsername,
        );
        filesToTransmit.add((sharedFile, File(descriptor.filePath).openRead()));
      }

      fileSharingSender = FileSharingSender(
        filesToSend: filesToTransmit,
        serverHost: receiver.host!,
        serverPort: receiver.port,
      );

      print("starting filesharingsender");
      try {
        await fileSharingSender?.start(); // This now awaits the full send process
        setState(() {
          _statusMessage = "Files sent successfully!";
          _selectedFileDescriptors.clear();
        });
      } catch (e) {
        print("Error sending files: $e");
        setState(() {
          _statusMessage = "Failed to send files: ${e.toString()}";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send files: ${e.toString()}')),
        );
      } finally {
        // fileSharingSender.stop() is handled internally by FileSharingSender
        setState(() {
          _loading = false;
        });
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No receiver selected or found.'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _statusMessage = "No receiver selected.";
      });
    }
  }

  @override
  void dispose() {
    // If your dialog ensures Bonsoir is stopped after it closes, this might not be strictly necessary here.
    // However, it's good practice to ensure no lingering discoveries.
    SharingDiscoveryService.stopDiscovery();
    // fileSharingSender?.stop() is called internally within FileSharingSender's start method
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
            Text('Sender: $_currentSenderUsername (ID: ${_currentSenderUserId ?? 'N/A'})',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _loading
                ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                      height: 80,
                      width: 80,
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Icon(Icons.upload_file, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(_statusMessage, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                elevation: 2,
                child: _selectedFileDescriptors.isEmpty
                    ? const Center(child: Text("No files selected."))
                    : ListView.builder(
                        itemCount: _selectedFileDescriptors.length,
                        itemBuilder: (context, index) {
                          final descriptor = _selectedFileDescriptors[index];
                          return ListTile(
                            leading: const Icon(Icons.description),
                            title: Text(
                              descriptor.fileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Size: ${fileSizeToHuman(descriptor.fileSize)}',
                            ),
                            trailing: IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFileDescriptors.removeAt(index);
                                  _statusMessage = "${_selectedFileDescriptors.length} files selected.";
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _selectedFileDescriptors.isNotEmpty
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
                if (_selectedFileDescriptors.isNotEmpty && !_loading)
                  ElevatedButton.icon(
                    onPressed: _startSending,
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
            const SizedBox(height: 20),
            const Text(
              'Select a file to send to other devices, ensure both sender and receiver are logged in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
