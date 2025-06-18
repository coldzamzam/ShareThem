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

    // Definisi warna utama aplikasi
    const Color primaryLight = Color(0xFFAA88CC); // Ungu muda keunguan
    const Color primaryDark = Color(0xFF554DDE);  // Biru tua keunguan
    // Warna background yang Anda pilih
    const Color backgroundStart = Color(0xFFF9F5FF); // Lavender muda
    const Color backgroundEnd = Color(0xFFEEEBFF);   // Ungu sangat pucat

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
          title: Text(
            _currentTitle, // Judul AppBar dinamis
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), // Warna teks putih, bold
          ),
          iconTheme: const IconThemeData(
            color: Colors.white, // Warna ikon putih
          ),
          elevation: 0, // Penting: Set elevation AppBar menjadi 0
          backgroundColor: Colors.transparent, // Transparan agar shadow dari flexibleSpace terlihat

          // Gunakan flexibleSpace untuk menempatkan widget di belakang AppBar
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [primaryLight, primaryDark], // Gradient warna utama aplikasi
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryDark.withOpacity(0.4), // Warna shadow dari primaryDark
                  blurRadius: 10.0, // Blur radius lebih besar
                  spreadRadius: 0.0,
                  offset: const Offset(0, 5), // Offset shadow lebih besar
                ),
              ],
            ),
          ),
        ),
        // Drawer untuk navigasi ke halaman sekunder.
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [primaryLight, primaryDark], // Konsisten dengan AppBar
                  ),
                ),
                child: const Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Icon(Icons.home, color: _currentPage is SendScreen ? primaryDark : Colors.grey[700]), // Warna icon sesuai selected
                title: Text('Home', style: TextStyle(color: _currentPage is SendScreen ? primaryDark : Colors.grey[800])),
                selected: _currentPage is SendScreen,
                selectedTileColor: primaryLight.withOpacity(0.1), // Warna latar belakang saat selected
                onTap: () {
                  _selectPage(const SendScreen(), 'Kirim', navIndex: 0);
                  Navigator.pop(context); // Tutup drawer
                },
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey[300]), // Divider yang lebih halus
              ListTile(
                leading: Icon(Icons.history, color: _currentPage is HistoryScreen ? primaryDark : Colors.grey[700]),
                title: Text('History', style: TextStyle(color: _currentPage is HistoryScreen ? primaryDark : Colors.grey[800])),
                selected: _currentPage is HistoryScreen,
                selectedTileColor: primaryLight.withOpacity(0.1),
                onTap: () {
                  _selectPage(const HistoryScreen(), 'History');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.account_circle_outlined, color: _currentPage is SettingsScreen ? primaryDark : Colors.grey[700]),
                title: Text('Account Settings', style: TextStyle(color: _currentPage is SettingsScreen ? primaryDark : Colors.grey[800])),
                selected: _currentPage is SettingsScreen,
                selectedTileColor: primaryLight.withOpacity(0.1),
                onTap: () {
                  _selectPage(const SettingsScreen(), 'Account Settings');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: _currentPage is AboutScreen ? primaryDark : Colors.grey[700]),
                title: Text('About Us', style: TextStyle(color: _currentPage is AboutScreen ? primaryDark : Colors.grey[800])),
                selected: _currentPage is AboutScreen,
                selectedTileColor: primaryLight.withOpacity(0.1),
                onTap: () {
                  _selectPage(const AboutScreen(), 'About Us');
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
                backgroundColor: backgroundStart, // Background NavigationRail
                indicatorColor: primaryLight.withOpacity(0.2), // Warna indikator saat selected
                selectedIconTheme: const IconThemeData(color: primaryDark), // Icon selected
                unselectedIconTheme: IconThemeData(color: Colors.grey[600]), // Icon unselected
                selectedLabelTextStyle: const TextStyle(color: primaryDark, fontWeight: FontWeight.bold), // Label selected
                unselectedLabelTextStyle: TextStyle(color: Colors.grey[700]), // Label unselected
                minWidth: 72, // Lebar minimum NavigationRail
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

            if (isWideScreen) const VerticalDivider(thickness: 1, width: 1, color: Colors.grey), // Garis pemisah lebih kontras

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
                    backgroundColor: backgroundStart, // Background NavigationBar
                    indicatorColor: primaryLight.withOpacity(0.2), // Warna indikator saat selected
                    shadowColor: primaryDark.withOpacity(0.1), // Shadow
                    elevation: 5, // Elevation
                    destinations: [
                      NavigationDestination(
                        icon: Icon(Icons.upload_outlined, color: _mainNavIndex == 0 ? primaryDark : Colors.grey[600]),
                        selectedIcon: const Icon(Icons.upload, color: primaryDark),
                        label: 'Kirim',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.download_outlined, color: _mainNavIndex == 1 ? primaryDark : Colors.grey[600]),
                        selectedIcon: const Icon(Icons.download, color: primaryDark),
                        label: 'Terima',
                      ),
                    ],
                  ),
      ),
    );
  }
}