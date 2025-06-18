import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Future to hold the file data from Firestore. This will store ALL files.
  late Future<List<Map<String, String>>> _allSavedFilesFuture;

  // List to hold the unfiltered files fetched from Firestore
  List<Map<String, String>> _allSavedFiles = [];
  // List to hold the files after applying the search filter
  List<Map<String, String>> _filteredSavedFiles = [];

  // Controller for the search input field
  final TextEditingController _searchController = TextEditingController();
  // State to manage whether the search bar is active
  bool _isSearching = false;

  // Stream subscription for auth state changes
  StreamSubscription<User?>? _authStateChangesSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for authentication state changes
    _authStateChangesSubscription = _auth.authStateChanges().listen((user) {
      // When auth state changes (login/logout), reload the files
      _loadSavedFiles();
    });
    // Initial load of files based on current user
    _loadSavedFiles();

    // Listen for changes in the search input field
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _authStateChangesSubscription?.cancel(); // Cancel auth state subscription
    _searchController.removeListener(_onSearchChanged); // Remove search listener
    _searchController.dispose(); // Dispose the controller
    super.dispose();
  }

  /// Handles changes in the search text field.
  void _onSearchChanged() {
    setState(() {
      _filterFiles(); // Re-filter files whenever the search query changes
    });
  }

  /// Loads the list of saved files from Firestore for the current user.
  void _loadSavedFiles() {
    final user = _auth.currentUser;
    if (user == null) {
      // If no user is logged in, clear existing data and set an empty future
      setState(() {
        _allSavedFiles = [];
        _filteredSavedFiles = [];
        _allSavedFilesFuture = Future.value([]);
      });
      print("No user logged in. Cannot load saved files.");
      return;
    }

    // Set the future to fetch files for the logged-in user
    setState(() {
      _allSavedFilesFuture = _fetchUserFilesFromFirestore(user.uid)
          .then((files) {
        _allSavedFiles = files; // Store all fetched files
        _filterFiles();       // Apply initial filter (empty search query)
        return files;         // Return all files to the FutureBuilder
      });
    });
  }

  /// Fetches saved file metadata from Firestore for a given user ID.
  Future<List<Map<String, String>>> _fetchUserFilesFromFirestore(String uid) async {
    try {
      // Reference to the user's saved_files subcollection
      final collectionRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_files');

      // Query the collection, ordering by a timestamp field ('timestamp') descending
      // This assumes you save a 'timestamp' field using FieldValue.serverTimestamp() when saving metadata.
      final querySnapshot = await collectionRef.orderBy('timestamp', descending: true).get();

      final List<Map<String, String>> filesData = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        filesData.add({
          'name': data['name'] as String? ?? 'Unknown File',
          'path': data['path'] as String? ?? '',
          'size': data['size'] as String? ?? '0',
          'modified': (data['modified'] as String?) ?? DateTime.now().toIso8601String(),
        });
      }
      return filesData;
    } catch (e) {
      print("Error fetching files from Firestore: $e");
      throw Exception("Failed to load files from history. Please try again.");
    }
  }

  /// Filters the _allSavedFiles list based on the current search query.
  void _filterFiles() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredSavedFiles = List.from(_allSavedFiles); // Show all files if query is empty
    } else {
      _filteredSavedFiles = _allSavedFiles.where((file) {
        // Check if file name contains the search query (case-insensitive)
        return (file['name'] ?? '').toLowerCase().contains(query);
      }).toList();
    }
  }

  /// Opens a file using the open_file package.
  /// This assumes the file is present at the provided filePath on the local device.
  Future<void> _openFile(String filePath, String fileName) async {
    // Check if the file actually exists locally before attempting to open
    final file = File(filePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File not found locally: $fileName'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file $fileName: ${result.message}'),
          backgroundColor: Colors.orange,
        ),
      );
      print("Open file result: ${result.message}"); // Print message for debugging
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration( // Made const as hintStyle is const
                  hintText: 'Search file name...',
                  border: UnderlineInputBorder(),
                  // Changed border color to match the app theme
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54), // Changed focused border color to black
                  ),
                  hintStyle: TextStyle(color: Colors.black54), // Changed hint text color to black54
                ),
                style: const TextStyle(color: Colors.black, fontSize: 18.0), // Changed input text color to black
                cursorColor: Colors.black, // Changed cursor color to black
              )
            : const Text('Saved Files History'),
        actions: [
          // Search icon to toggle search bar visibility
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear(); // Clear search and re-filter
                }
              });
            },
            tooltip: _isSearching ? 'Close Search' : 'Search Files',
          ),
          // Refresh button to reload the file list
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _auth.currentUser == null
          ? const Center(
              child: Text(
                "Please log in to view your saved files history.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : FutureBuilder<List<Map<String, String>>>(
              future: _allSavedFilesFuture, // Use the future that fetches all files
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Error loading files: ${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                // Check if data is loaded and if filtered list is empty or not
                if (snapshot.hasData && _filteredSavedFiles.isNotEmpty) {
                  return ListView.builder(
                    itemCount: _filteredSavedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _filteredSavedFiles[index];
                      final fileSize = int.tryParse(file['size'] ?? '0') ?? 0;
                      return ListTile(
                        leading: const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
                        title: Text(file['name']!),
                        subtitle: Text(
                            'Size: ${fileSizeToHuman(fileSize)} - Path: ${file['path']!}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _openFile(file['path']!, file['name']!),
                      );
                    },
                  );
                }
                // If there's no data or filtered list is empty
                return Center(
                  child: Text(
                    _searchController.text.isNotEmpty
                        ? "No files found matching '${_searchController.text}'."
                        : "No saved files found for this account.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              },
            ),
    );
  }
}
