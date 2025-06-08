import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Delay splash screen for 3 seconds, then navigate
    Future.delayed(const Duration(seconds: 6), () {
      Navigator.pushReplacementNamed(context, '/login');
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
