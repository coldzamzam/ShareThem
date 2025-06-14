import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

// Firebase Firestore imports
import 'package:cloud_firestore/cloud_firestore.dart';
// Your project-specific imports
import 'package:flutter_shareit/utils/auth_utils.dart'; // For AuthenticationService and getDownloadDirectoryForUser
import 'package:flutter_shareit/models/received_file_entry.dart'; // For the ReceivedFileEntry model

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<List<ReceivedFileEntry>>? _savedFilesFuture;
  final AuthenticationService _authService = AuthenticationService();
  String? _currentUserId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _appId = 'flutter_shareit_app'; // !!! IMPORTANT: Match this with FileSharingReceiver

  // --- Search Functionality Variables ---
  bool _isSearching = false; // Controls visibility of search bar
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; // Stores the current search query

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.getCurrentUserId();
    if (_currentUserId != null) {
      _loadSavedFiles();
    }

    // Listen to changes in the search text field
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); // Dispose the controller when the widget is removed
    super.dispose();
  }

  /// Triggers the loading of saved files from Firestore.
  void _loadSavedFiles() {
    if (_currentUserId == null) return;
    setState(() {
      _savedFilesFuture = _getReceivedFilesFromFirestore(_currentUserId!);
    });
  }

  /// Fetches received file metadata from Firestore for the current user.
  /// It also verifies if the corresponding local file still exists.
  Future<List<ReceivedFileEntry>> _getReceivedFilesFromFirestore(String userId) async {
  List<ReceivedFileEntry> receivedFiles = [];
  try {
    final QuerySnapshot querySnapshot = await _firestore
        // CHANGE START
        .collection('users') // Match FileSharingReceiver's collection
        .doc(userId)          // Match FileSharingReceiver's user document
        .collection('savedFiles') // Match FileSharingReceiver's subcollection
        // CHANGE END
        .orderBy('modifiedDate', descending: true)
        .get();

    for (var doc in querySnapshot.docs) {
      final entry = ReceivedFileEntry.fromFirestore(doc);
      final localFile = File(entry.filePath);
      if (await localFile.exists()) {
        receivedFiles.add(entry);
      } else {
        print("Local file ${entry.filePath} not found for Firestore entry ${entry.id}. Skipping.");
        // Optionally, you might want to delete this stale Firestore entry here
        // doc.reference.delete();
      }
    }
  } catch (e) {
    print("Error fetching received files from Firestore: $e");
  }
  return receivedFiles;
}

  /// Filters the list of files based on the current search query.
  List<ReceivedFileEntry> _filterFiles(List<ReceivedFileEntry> files) {
    if (_searchQuery.isEmpty) {
      return files;
    }
    final queryLower = _searchQuery.toLowerCase();
    return files.where((file) {
      // Check if file name or sender name contains the search query
      return file.fileName.toLowerCase().contains(queryLower) ||
             file.senderName.toLowerCase().contains(queryLower);
    }).toList();
  }

  /// Opens a file using the package:open_file.
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

  /// Helper function to convert bytes to a human-readable format.
  String fileSizeToHuman(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(
        child: Text(
          "Please log in to view your history.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration( // Changed to const as no dynamic theme color here
                  hintText: 'Search by file or sender name...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.black54), // Black hint text
                ),
                style: const TextStyle(color: Colors.black), // Black input text
                cursorColor: Colors.black, // Black cursor
              )
            : const Text('Saved Files History'),
        actions: [
          _isSearching
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black), // Black icon
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear(); // Clear search query
                    });
                  },
                  tooltip: 'Clear Search',
                )
              : IconButton(
                  icon: const Icon(Icons.search, color: Colors.black), // Black icon
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                  tooltip: 'Search',
                ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black), // Black icon
            onPressed: _loadSavedFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<ReceivedFileEntry>>(
        future: _savedFilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading files: ${snapshot.error}"));
          }
          if (snapshot.hasData) {
            final filteredFiles = _filterFiles(snapshot.data!);

            if (filteredFiles.isNotEmpty) {
              return ListView.builder(
                itemCount: filteredFiles.length,
                itemBuilder: (context, index) {
                  final file = filteredFiles[index];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
                    title: Text(file.fileName),
                    subtitle: Text('Sent by: ${file.senderName} - Size: ${fileSizeToHuman(file.fileSize)}'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _openFile(file.filePath, file.fileName),
                  );
                },
              );
            } else if (_searchQuery.isNotEmpty && snapshot.data!.isNotEmpty) {
              return const Center(
                child: Text(
                  "No matching files found.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            } else {
              return const Center(
                child: Text(
                  "No saved files found for this account.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }
          }
          return const Center(
            child: Text(
              "No saved files found.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}