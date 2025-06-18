import 'package:flutter/material.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_utils.dart';

class SendingProgressData {
  final SharedFile file;
  final int sentBytes;
  final bool isCompleted;

  SendingProgressData({
    required this.file,
    required this.sentBytes,
    this.isCompleted = false,
  });
}

class SendingProgressBottomSheet extends StatefulWidget {
  final ValueNotifier<List<SendingProgressData>> progressNotifier;

  const SendingProgressBottomSheet({
    super.key,
    required this.progressNotifier,
  });

  @override
  State<SendingProgressBottomSheet> createState() => _SendingProgressBottomSheetState();
}

class _SendingProgressBottomSheetState extends State<SendingProgressBottomSheet> {
  @override
  void initState() {
    super.initState();
    widget.progressNotifier.addListener(_onProgressChanged);
  }

  void _onProgressChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.progressNotifier.removeListener(_onProgressChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Definisi warna utama aplikasi
    const Color primaryLight = Color(0xFFAA88CC); // Ungu muda keunguan
    const Color primaryDark = Color(0xFF554DDE);  // Biru tua keunguan
    // Warna background untuk bottom sheet
    const Color cardColor = Colors.white; // Umumnya bottom sheet menggunakan warna card/putih

    return PopScope(
      canPop: false, // Mempertahankan agar tidak bisa ditutup secara default
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: cardColor, // Menggunakan warna putih bersih
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)), // Sudut lebih membulat
          boxShadow: [ // Menambahkan shadow yang lebih jelas
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20.0,
              spreadRadius: 5.0,
              offset: Offset(0, -5), // Shadow di bagian atas
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0), // Padding yang lebih lapang
              child: Text(
                "Sending Files...",
                style: TextStyle(
                  fontSize: 22, // Ukuran font lebih besar
                  fontWeight: FontWeight.bold,
                  color: primaryDark, // Warna judul dari primaryDark
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1.5, color: Colors.grey), // Divider yang lebih tebal dan berwarna
            Expanded(
              child: widget.progressNotifier.value.isEmpty
                  ? Center(
                      child: Text(
                        "Waiting to send files...",
                        style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0), // Padding ListView
                      itemCount: widget.progressNotifier.value.length,
                      itemBuilder: (context, index) {
                        final data = widget.progressNotifier.value[index];
                        final progress = (data.file.fileSize == 0)
                            ? 0.0
                            : (data.sentBytes / data.file.fileSize);
                        final isCompleted = data.isCompleted;

                        Widget trailingWidget;
                        if (isCompleted) {
                          trailingWidget = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Sent ",
                                style: TextStyle(color: primaryDark, fontWeight: FontWeight.w600), // Warna teks Sent dari primaryDark
                              ),
                              Icon(Icons.check_circle, color: primaryDark, size: 24), // Ikon check dengan primaryDark, ukuran lebih besar
                            ],
                          );
                        } else {
                          trailingWidget = SizedBox(
                            width: 100, // Lebar progress bar lebih besar
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[300], // Background progress bar
                                  valueColor: const AlwaysStoppedAnimation<Color>(primaryLight), // Warna progress dari primaryLight
                                  minHeight: 6, // Ketebalan progress bar
                                  borderRadius: BorderRadius.circular(3), // Sudut progress bar membulat
                                ),
                                const SizedBox(height: 6), // Spasi kecil
                                Text(
                                  "${(progress * 100).toStringAsFixed(0)}%",
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]), // Warna teks persentase
                                ),
                              ],
                            ),
                          );
                        }

                        return Container( // Membungkus ListTile untuk border bawah
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!, // Garis pemisah yang halus
                                width: 1.0,
                              ),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Padding konten
                            leading: CircleAvatar( // CircleAvatar untuk ikon
                              backgroundColor: primaryLight.withOpacity(0.1), // Background lingkaran dari primaryLight
                              child: const Icon(Icons.insert_drive_file, color: primaryDark, size: 28), // Ikon file dari primaryDark
                            ),
                            title: Text(
                              data.file.fileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600, // Lebih tebal
                                fontSize: 16,
                                color: Color(0xFF333333), // Warna teks judul
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Size: ${fileSizeToHuman(data.file.fileSize)}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13), // Warna teks subtitle
                            ),
                            trailing: trailingWidget,
                          ),
                        );
                      },
                    ),
            ),
            if (widget.progressNotifier.value.isNotEmpty && widget.progressNotifier.value.every((data) => data.isCompleted))
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0), // Padding tombol lebih lapang
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDark, // Warna tombol Close dari primaryDark
                    foregroundColor: Colors.white, // Warna teks tombol
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), // Padding tombol lebih besar
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // Sudut tombol lebih membulat
                    ),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), // Ukuran dan tebal font
                    elevation: 8, // Elevation lebih tinggi
                    shadowColor: primaryDark.withOpacity(0.4), // Shadow dari primaryDark
                  ),
                  child: const Text('Close'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}