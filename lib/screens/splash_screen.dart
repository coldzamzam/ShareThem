import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Logika navigasi dimulai setelah jeda
    Future.delayed(const Duration(seconds: 6), () async {
      // Pengecekan 'mounted' penting untuk mencegah error jika user
      // meninggalkan screen sebelum navigasi terjadi.
      if (!mounted) return;

      // --- PERUBAHAN DIMULAI DI SINI ---

      // 1. Periksa apakah onboarding sudah pernah selesai.
      final prefs = await SharedPreferences.getInstance();
      final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

      // 2. Tentukan halaman tujuan berdasarkan status onboarding dan login.
      if (onboardingCompleted) {
        // Jika onboarding sudah selesai, lanjutkan ke logika login seperti semula.
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Pengguna sudah login, arahkan ke home.
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // Pengguna belum login, arahkan ke login.
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        // Jika onboarding belum pernah selesai, arahkan ke halaman onboarding.
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
      // --- PERUBAHAN SELESAI ---
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF554DDE), // Ungu gelap
              Color(0xFF8E44AD), // Ungu muda
            ],
          ),
        ),
        child: Center(
          child: Lottie.asset(
            'assets/animations/splash_screen.json',
            width: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
