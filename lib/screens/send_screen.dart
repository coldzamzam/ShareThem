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
import 'sending_progress_bottom_sheet.dart'; // Import widget baru

// --- PENTING: PASTIKAN DEFINISI SendingProgressData ADA DI SINI ATAU DI FILE TERPISAH DAN DIIMPOR DI KEDUA FILE ---
// Jika SendingProgressData sudah ada di 'sending_progress_bottom_sheet.dart' atau file terpisah,
// maka baris ini harus dihapus/tidak ada di sini untuk menghindari duplikasi dan error.
// Asumsi Anda memiliki definisinya di tempat lain yang diimpor dengan benar.
// --- AKHIR PENTING ---


class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  bool _loading = false;
  final List<(SharedFile, Stream<List<int>>)> _selectedFiles = [];
  FileSharingSender? fileSharingSender;

  // ValueNotifier untuk memperbarui UI bottom sheet
  final ValueNotifier<List<SendingProgressData>> _sendingProgressNotifier = ValueNotifier([]);

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
    _sendingProgressNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Definisi warna utama aplikasi
    const Color primaryLight = Color(0xFFAA88CC); // Ungu muda keunguan
    const Color primaryDark = Color(0xFF554DDE);  // Biru tua keunguan

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF9F5FF), Color(0xFFEEEBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon atau CircularProgressIndicator
              _loading
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: const SizedBox(
                        height: 90,
                        width: 90,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryDark), // Warna dari primaryDark
                        ),
                      ),
                    )
                  : Icon(
                      Icons.cloud_upload_rounded,
                      size: 120,
                      color: primaryLight.withOpacity(0.6), // Warna icon dari primaryLight dengan opacity
                    ),

              const SizedBox(height: 30),

              // File List Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    elevation: 10,
                    shadowColor: primaryDark.withOpacity(0.1), // Shadow dari primaryDark dengan opacity
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20.0),
                      child: ListView(
                        children: _selectedFiles
                            .mapIndexed(
                              (i, entry) => Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[200]!, // Tetap abu-abu terang untuk pemisah
                                      width: 0.8,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: primaryLight.withOpacity(0.15), // Background lingkaran dari primaryLight
                                    child: const Icon(Icons.insert_drive_file, color: primaryDark, size: 24), // Icon file dari primaryDark
                                  ),
                                  title: Text(
                                    entry.$1.fileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Color(0xFF333333), // Warna teks tetap gelap untuk keterbacaan
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Size: ${fileSizeToHuman(entry.$1.fileSize)}',
                                    style: TextStyle(
                                      color: Colors.grey[600], // Tetap abu-abu untuk subtitle
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedFiles.removeAt(i);
                                      });
                                    },
                                    icon: const Icon(Icons.delete_outline, color: Colors.red), // Merah untuk delete tetap efektif
                                    tooltip: 'Remove file',
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),

              // Action Buttons (Select Files / Add More Files & Send Files)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 5,
                runSpacing: 15,
                children: [
                  if (!SharingDiscoveryService.isSearching)
                    _buildActionButton(
                      onTap: _pickFiles,
                      icon: Icons.add_circle_outline,
                      label: _selectedFiles.isNotEmpty ? 'Add More Files' : 'Select Files',
                      // Gradien untuk tombol 'Select Files' dengan turunan dari warna utama
                      gradientColors: [primaryLight.withOpacity(0.8), primaryDark.withOpacity(0.7)],
                    ),
                  if (_selectedFiles.isNotEmpty && !_loading)
                    _buildActionButton(
                      onTap: () async {
                        final receiver = await showSelectReceiverDialog(context: context);
                        if (receiver is ResolvedBonsoirService) {
                          _sendingProgressNotifier.value = _selectedFiles.map((e) =>
                              SendingProgressData(
                                  file: e.$1,
                                  sentBytes: 0,
                                  isCompleted: false
                              )).toList();

                          showModalBottomSheet(
                            context: context,
                            isDismissible: false,
                            enableDrag: false,
                            backgroundColor: Colors.transparent,
                            builder: (context) => SendingProgressBottomSheet(
                              progressNotifier: _sendingProgressNotifier,
                            ),
                          );

                          fileSharingSender = FileSharingSender(
                            files: _selectedFiles,
                            serverHost: receiver.host!,
                            serverPort: receiver.port,
                            onProgressUpdate: (file, sentBytes, isCompleted) {
                              final currentList = _sendingProgressNotifier.value;
                              final index = currentList.indexWhere((data) => data.file.fileName == file.fileName);
                              if (index != -1) {
                                currentList[index] = SendingProgressData(
                                  file: file,
                                  sentBytes: sentBytes,
                                  isCompleted: isCompleted,
                                );
                                _sendingProgressNotifier.value = List.from(currentList);
                              }
                            },
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
                      icon: Icons.send_rounded,
                      label: 'Send Files',
                      // Gradien untuk tombol 'Send Files' menggunakan warna utama aplikasi
                      gradientColors: const [primaryLight, primaryDark],
                    ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'Select file(s) to share with other nearby devices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: primaryDark.withOpacity(0.7), // Warna teks instruksi dari primaryDark dengan opacity
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget pembantu untuk membuat tombol aksi
  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}