import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // State yang dipindahkan dari ReceiveScreen
  late Future<List<Map<String, String>>> _savedFilesFuture;

  @override
  void initState() {
    super.initState();
    _loadSavedFiles();
  }

  /// Memuat daftar file yang sudah ada dari direktori penyimpanan.
  void _loadSavedFiles() {
    setState(() {
      _savedFilesFuture = _getFilesInDownloadDirectory();
    });
  }

  /// Fungsi terpusat untuk mendapatkan path unduhan yang benar.
  Future<Directory?> _getDownloadDirectory() async {
    return await getExternalStorageDirectory();
  }

  /// Membaca isi direktori unduhan.
  Future<List<Map<String, String>>> _getFilesInDownloadDirectory() async {
    final baseDir = await _getDownloadDirectory();
    if (baseDir == null) {
      print("Error: External storage directory is not available.");
      throw Exception("Could not access storage directory.");
    }

    final downloadDir = Directory(p.join(baseDir.path, 'downloads'));
    print("Reading saved files from: ${downloadDir.path}");

    if (await downloadDir.exists()) {
      final List<FileSystemEntity> entities = await downloadDir.list().toList();
      final List<Map<String, String>> filesData = [];
      for (var entity in entities) {
        if (entity is File) {
          final stat = await entity.stat();
          filesData.add({
            'name': p.basename(entity.path),
            'path': entity.path,
            'size': stat.size.toString(), // Simpan ukuran file
            'modified': stat.modified.toIso8601String(), // Simpan waktu modifikasi
          });
        }
      }
      // Urutkan berdasarkan waktu modifikasi, yang terbaru di atas
      filesData.sort((a, b) => b['modified']!.compareTo(a['modified']!));
      return filesData;
    } else {
      print("Directory does not exist: ${downloadDir.path}");
      return []; // Kembalikan list kosong jika direktori tidak ada
    }
  }

  /// Membuka file menggunakan package open_file.
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

  /// Fungsi bantuan untuk mengubah byte menjadi format yang mudah dibaca.
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
        title: const Text('Saved Files History'),
        actions: [
          // Tambahkan tombol refresh untuk memuat ulang daftar file
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _savedFilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading files: ${snapshot.error}"));
          }
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final savedFiles = snapshot.data!;
            return ListView.builder(
              itemCount: savedFiles.length,
              itemBuilder: (context, index) {
                final file = savedFiles[index];
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