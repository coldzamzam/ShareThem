import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Import paket Lottie
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // --- DATA KONTEN ---
  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Selamat Datang di ShareThem!',
      'description': 'Aplikasi berbagi file super cepat yang menghubungkan Anda dengan teman di sekitar.',
      'icon': null,
      'lottiePath': 'assets/animations/sharethem_lottie.json',
      'imagePath': null,
      'team': null,
    },
    {
      'title': 'Kirim File Tanpa Internet',
      'description': 'ShareThem menggunakan teknologi Wi-Fi LAN untuk membuat koneksi langsung antar perangkat. Anda dapat mengirim aplikasi, foto, dan file lainnya tanpa kuota internet.',
      'icon': null,
      'lottiePath': null,
      'imagePath': 'assets/images/file_sharing-2.png',
      'team': null,
    },
    {
      'title': 'Fitur Lengkap dan Mudah',
      'description': 'Kirim file dengan mudah, terima file dari teman, dan lihat semua riwayat file yang pernah Anda terima langsung di dalam aplikasi.',
      'icon': null,
      'lottiePath': null,
      'imagePath': 'assets/images/file_sharing.png',
      'team': null,
    },
    // {
    //   'title': 'Tim Pengembang Hebat Kami',
    //   'description': null, // Deskripsi digantikan oleh daftar tim
    //   'icon': null,
    //   'lottiePath': null,
    //   'imagePath': null,
    //   'team': [
    //     {'name': 'Rifat', 'image': 'https://placehold.co/100x100/FFFFFF/333333?text=R'},
    //     {'name': 'Sulthan', 'image': 'https://placehold.co/100x100/FFFFFF/333333?text=S'},
    //     {'name': 'Rafi', 'image': 'https://placehold.co/100x100/FFFFFF/333333?text=R'},
    //     {'name': 'Aqsa', 'image': 'https://placehold.co/100x100/FFFFFF/333333?text=A'},
    //     {'name': 'Angel', 'image': 'https://placehold.co/100x100/FFFFFF/333333?text=A'},
    //   ]
    // }
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Gambar Latar Belakang (Layer Paling Bawah)
          Positioned.fill(
            child: Image.asset(
              'assets/images/onboarding_pict.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Gradasi Overlay (Layer di Atas Gambar)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, // Dari bawah
                  end: Alignment.topCenter,     // Ke atas
                  colors: [
                    Colors.black, // Hitam pekat di bawah
                    Colors.black.withOpacity(0.7), // Hitam agak transparan di tengah
                    Colors.white.withOpacity(0.0), // Putih transparan di atas
                  ],
                  stops: const [0.0, 0.4, 1.0], // Menyesuaikan stop untuk efek gradasi
                ),
              ),
            ),
          ),

          // 3. Konten Onboarding (Layer Paling Atas)
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _onboardingData.length,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemBuilder: (context, index) {
                      return OnboardingSlide(
                        icon: _onboardingData[index]['icon'],
                        imagePath: _onboardingData[index]['imagePath'],
                        lottiePath: _onboardingData[index]['lottiePath'],
                        title: _onboardingData[index]['title'],
                        description: _onboardingData[index]['description'],
                        team: _onboardingData[index]['team'],
                      );
                    },
                  ),
                ),

                // --- BAGIAN NAVIGASI ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _onboardingData.length,
                    (index) => buildDot(index, context),
                  ),
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Opacity(
                        opacity: _currentPage > 0 ? 1.0 : 0.0,
                        child: ElevatedButton(
                          onPressed: _currentPage > 0
                              ? () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                              side: BorderSide(color: Colors.white.withOpacity(0.5)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Kembali'),
                        ),
                      ),

                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage == _onboardingData.length - 1) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: const Color(0xFF554DDE),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          _currentPage == _onboardingData.length - 1 ? 'Mulai' : 'Lanjut',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Container buildDot(int index, BuildContext context) {
    return Container(
      height: 10,
      width: _currentPage == index ? 25 : 10,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _currentPage == index ? Colors.white : Colors.white54,
      ),
    );
  }
}

class OnboardingSlide extends StatelessWidget {
  final String? icon;
  final String? imagePath;
  final String? lottiePath;
  final String? title;
  final String? description;
  final List<Map<String, String>>? team;

  const OnboardingSlide({
    super.key,
    this.icon,
    this.imagePath,
    this.lottiePath,
    required this.title,
    this.description,
    this.team,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (lottiePath != null)
            Center(
              child: Lottie.asset(
                lottiePath!,
                height: 250,
                fit: BoxFit.contain,
              ),
            )
          else if (imagePath != null)
            Center(
              child: Image.asset(
                imagePath!,
                height: 250,
                fit: BoxFit.contain,
              ),
            )
          else if (icon != null)
            Text(
              icon!,
              style: const TextStyle(fontSize: 60),
            ),
          const SizedBox(height: 30),
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 15),
          if (description != null)
            Text(
              description!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                height: 1.5,
              ),
            )
          else if (team != null)
            Center(
              child: Wrap(
                spacing: 20.0,
                runSpacing: 20.0,
                alignment: WrapAlignment.center,
                children: team!
                    .map((member) => TeamMemberBubble(
                          name: member['name']!,
                          imageUrl: member['image']!,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

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
          backgroundColor: Colors.white24,
          backgroundImage: NetworkImage(imageUrl),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}