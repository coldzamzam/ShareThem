
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Delay splash screen for 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      // Check if a user is currently logged in
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // User is logged in, navigate to home page
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // No user is logged in, navigate to login page
        Navigator.pushReplacementNamed(context, '/login');
      }
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
