import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Data tim pengembang
  final List<Map<String, String>> _teamMembers = const [
    {'name': 'Rifat', 'image': 'assets/avatars/Avatar_1.png'},
    {'name': 'Sulthan', 'image': 'assets/avatars/Avatar_2.png'},
    {'name': 'Rafi', 'image': 'assets/avatars/Avatar_3.png'},
    {'name': 'Aqsa', 'image': 'assets/avatars/Avatar_4.png'},
    {'name': 'Angel', 'image': 'assets/avatars/Avatar_5.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView( // Menggunakan SingleChildScrollView agar konten bisa di-scroll
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'ShareThem App',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ShareThem adalah aplikasi yang dirancang untuk mengirim file antar perangkat dengan cepat dan efisien, bahkan tanpa koneksi internet. Aplikasi ini menggunakan teknologi Wi-Fi, memungkinkan pengguna untuk mengirim berbagai jenis file seperti dokumen, foto, video, dan aplikasi dengan kecepatan tinggi dan tanpa menggunakan kuota internet.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 30),
            const Text(
              'Our Team',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            // Menampilkan daftar anggota tim dalam Wrap
            Center(
              child: Wrap(
                spacing: 20.0,
                runSpacing: 20.0,
                alignment: WrapAlignment.center,
                children: _teamMembers.map((member) => TeamMemberBubble(
                  name: member['name']!,
                  imageUrl: member['image']!,
                )).toList(),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Contact Us:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Email: info@sharethem.pnj.ac.id\nWebsite: sharethem.pnj.ac.id',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Widget TeamMemberBubble yang Anda berikan
class TeamMemberBubble extends StatelessWidget {
  final String name;
  final String imageUrl;

  const TeamMemberBubble({
    super.key,
    required this.name,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.blueGrey.shade100,
          backgroundImage: AssetImage(imageUrl),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}