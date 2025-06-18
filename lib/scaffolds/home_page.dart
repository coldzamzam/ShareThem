import 'package:flutter/material.dart';

// Mengimpor halaman dari file terpisah
import 'package:flutter_shareit/screens/send_screen.dart';
import 'package:flutter_shareit/screens/receive_screen.dart';
import 'package:flutter_shareit/screens/history_screen.dart';
import 'package:flutter_shareit/screens/settings_screen.dart';
import 'package:flutter_shareit/screens/about_screen.dart';

// Layar utama aplikasi yang mengelola semua tampilan halaman.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // State untuk mengelola halaman dan judul yang sedang aktif.
  // Menggunakan widget SendScreen yang diimpor sebagai halaman awal.
  Widget _currentPage = const SendScreen();
  String _currentTitle = 'Kirim';

  // State untuk melacak indeks navigasi utama (Kirim/Terima).
  int _mainNavIndex = 0;

  // Fungsi untuk mengubah halaman yang ditampilkan.
  void _selectPage(Widget page, String title, {int? navIndex}) {
    setState(() {
      _currentPage = page;
      _currentTitle = title;
      // Jika navIndex disediakan, perbarui indeks navigasi utama.
      if (navIndex != null) {
        _mainNavIndex = navIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 1000.0;

    return Scaffold(
      appBar: AppBar(
        // Hapus backgroundColor agar tidak menutupi gradient di flexibleSpace
        // backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          _currentTitle, // Judul AppBar dinamis
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),

        // Gunakan flexibleSpace untuk menempatkan widget di belakang AppBar
        flexibleSpace: Container(
          // Di sini kita tempatkan dekorasi gradient Anda
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFAA88CC), Color(0xFF554DDE)],
            ),
          ),
        ),
      ),
      // Drawer untuk navigasi ke halaman sekunder.
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
                  colors: [Color(0xFFAA88CC), Color(0xFF554DDE)],
                ),
              ),
              child: const Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: _currentPage is SendScreen,
              onTap: () {
                // Menggunakan SendScreen yang diimpor.
                _selectPage(const SendScreen(), 'Kirim', navIndex: 0);
                Navigator.pop(context); // Tutup drawer
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Riwayat'),
              selected: _currentPage is HistoryScreen,
              onTap: () {
                // Menggunakan HistoryScreen yang diimpor.
                _selectPage(const HistoryScreen(), 'Riwayat');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Pengaturan Akun'),
              selected: _currentPage is SettingsScreen,
              onTap: () {
                // Menggunakan SettingsScreen yang diimpor.
                _selectPage(const SettingsScreen(), 'Pengaturan Akun');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Tentang Aplikasi'),
              onTap: () {
                _selectPage(const AboutScreen(), 'Tentang Aplikasi');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // Render NavigationRail untuk layar lebar.
          if (isWideScreen)
            NavigationRail(
              selectedIndex: _mainNavIndex,
              onDestinationSelected: (index) {
                if (index == 0) {
                  _selectPage(const SendScreen(), 'Kirim', navIndex: 0);
                } else if (index == 1) {
                  _selectPage(const ReceiveScreen(), 'Terima', navIndex: 1);
                }
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.upload_outlined),
                  selectedIcon: Icon(Icons.upload),
                  label: Text('Kirim'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.download_outlined),
                  selectedIcon: Icon(Icons.download),
                  label: Text('Terima'),
                ),
              ],
            ),

          if (isWideScreen) const VerticalDivider(thickness: 1, width: 1),

          // Konten utama yang berubah secara dinamis.
          Expanded(child: _currentPage),
        ],
      ),
      // Render BottomNavigationBar untuk layar sempit.
      bottomNavigationBar:
          isWideScreen
              ? null
              : NavigationBar(
                selectedIndex: _mainNavIndex,
                onDestinationSelected: (index) {
                  if (index == 0) {
                    _selectPage(const SendScreen(), 'Kirim', navIndex: 0);
                  } else if (index == 1) {
                    _selectPage(const ReceiveScreen(), 'Terima', navIndex: 1);
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.upload_outlined),
                    selectedIcon: Icon(Icons.upload),
                    label: 'Kirim',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.download_outlined),
                    selectedIcon: Icon(Icons.download),
                    label: 'Terima',
                  ),
                ],
              ),
    );
  }
}
