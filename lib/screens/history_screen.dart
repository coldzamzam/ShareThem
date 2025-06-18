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
    // Warna utama aplikasi
    const Color primaryLight = Color(0xFFAA88CC);
    const Color primaryDark = Color(0xFF554DDE);
    // Warna background
    const Color backgroundStart = Color(0xFFF9F5FF);
    const Color backgroundEnd = Color(0xFFEEEBFF);

    return Container( // Wrapper Container untuk background gradient halaman
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundStart, backgroundEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Penting agar background Container terlihat
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search file name...',
                    hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)), // Warna hint yang disesuaikan
                    border: const UnderlineInputBorder( // Menggunakan UnderlineInputBorder untuk border default
                      borderSide: BorderSide(color: Colors.black87, width: 1.0), // Warna border default
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black54, width: 2.0), // Warna border saat focused
                    ),
                    enabledBorder: const UnderlineInputBorder( // Warna border saat enabled
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                  ),
                  style: const TextStyle(color: Colors.black, fontSize: 18.0), // Warna teks input putih
                  cursorColor: Colors.white, // Warna kursor putih
                )
              : const Text(
                  'Saved Files History',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600), // Judul AppBar
                ),
          actions: [
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Colors.black, // Warna ikon hitam
              ),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
              tooltip: _isSearching ? 'Close Search' : 'Search Files',
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black), // Warna ikon putih
              onPressed: _loadSavedFiles,
              tooltip: 'Refresh',
            ),
          ],
          elevation: 0, // Penting: Set elevation AppBar menjadi 0
          backgroundColor: Colors.transparent, // Transparan agar shadow dari flexibleSpace terlihat
          
        ),
        body: _auth.currentUser == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0), // Padding lebih besar
                  child: Text(
                    "Please log in to view your saved files history.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18, // Ukuran font lebih besar
                      fontWeight: FontWeight.w600,
                      color: primaryDark.withOpacity(0.8), // Warna teks dari primaryDark
                    ),
                  ),
                ),
              )
            : FutureBuilder<List<Map<String, String>>>(
                future: _allSavedFilesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryDark), // Warna dari primaryDark
                        strokeWidth: 5, // Ketebalan progress bar
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          "Error loading files: ${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    );
                  }
                  // Check if data is loaded and if filtered list is empty or not
                  if (snapshot.hasData && _filteredSavedFiles.isNotEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0), // Padding listview
                      itemCount: _filteredSavedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _filteredSavedFiles[index];
                        final fileSize = int.tryParse(file['size'] ?? '0') ?? 0;
                        final String modifiedDate = file['modified'] != null
                            ? DateTime.tryParse(file['modified']!)?.toLocal().toString().split(' ')[0] ?? ''
                            : ''; // Format tanggal

                        return Card( // Menggunakan Card untuk setiap item
                          margin: const EdgeInsets.symmetric(vertical: 5.0), // Margin antar card
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0), // Sudut Card lebih membulat
                          ),
                          elevation: 5, // Elevasi untuk efek floating
                          shadowColor: primaryLight.withOpacity(0.1), // Shadow dari primaryLight
                          child: Container( // Tambahkan Container untuk padding konten dalam Card
                            decoration: BoxDecoration(
                              // Tambahkan border di sini jika diperlukan, atau biarkan Card yang menangani
                              borderRadius: BorderRadius.circular(15.0),
                              color: Colors.white, // Background putih untuk setiap item
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), // Padding konten ListTile
                              leading: CircleAvatar( // CircleAvatar untuk ikon
                                backgroundColor: primaryLight.withOpacity(0.15), // Background lingkaran dari primaryLight
                                child: const Icon(Icons.insert_drive_file, color: primaryDark, size: 28), // Ikon file dari primaryDark
                              ),
                              title: Text(
                                file['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700, // Lebih tebal
                                  fontSize: 17,
                                  color: Color(0xFF333333), // Warna teks lebih gelap
                                ),
                                overflow: TextOverflow.ellipsis, // Menangani nama file panjang
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4), // Spasi kecil
                                  Text(
                                    'Size: ${fileSizeToHuman(fileSize)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (modifiedDate.isNotEmpty)
                                    Text(
                                      'Last Modified: $modifiedDate',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton( // Mengubah icon open_in_new menjadi IconButton
                                icon: const Icon(Icons.open_in_new, color: primaryLight), // Icon dengan primaryLight
                                onPressed: () => _openFile(file['path']!, file['name']!),
                                tooltip: 'Open file',
                              ),
                              onTap: () => _openFile(file['path']!, file['name']!), // Tap pada ListTile juga membuka file
                            ),
                          ),
                        );
                      },
                    );
                  }
                  // If there's no data or filtered list is empty
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _searchController.text.isNotEmpty
                            ? "No files found matching '${_searchController.text}'."
                            : "No saved files found for this account.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryDark.withOpacity(0.8),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}