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
    _checkLoginStatus(); // Call the new method to check login status
  }

  void _checkLoginStatus() async {
    // Keep the delay to show your Lottie animation for a few seconds
    await Future.delayed(const Duration(seconds: 6));

    // Listen to Firebase Authentication state changes
    // This stream provides the current user (if logged in) or null (if not).
    // It also handles the app restarting and Firebase automatically restoring a session.
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        // User is currently signed out. Navigate to LoginPage.
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        // User is signed in. Navigate to HomePage.
        Navigator.of(context).pushReplacementNamed('/home');
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