import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const SettingsScreen({super.key, this.onClose});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser; // To hold the current user

  @override
  void initState() {
    super.initState();
    // Listen to authentication state changes
    _auth.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user; // Update the current user
      });
    });
  }

  Future<void> _handleAuthButtonPress() async {
    if (_currentUser != null) {
      // User is logged in, so log them out
      try {
        await _auth.signOut();
        // Optionally, navigate to the login page after logout
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // User is not logged in, navigate to login page
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 15, 0, 15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(

            children: [
              const Text(
                "Settings",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 25), 
              CircleAvatar(
                maxRadius: 75,
                child: _currentUser != null
                    ? Text(
                        _currentUser!.email![0].toUpperCase(), 
                        style: const TextStyle(fontSize: 60, color: Colors.white),
                      )
                    : const Icon(Icons.person, size: 100),
              ),
              const SizedBox(height: 10), 
              _currentUser != null
                  ? Text(
                      _currentUser!.email ?? 'No Email', 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    )
                  : const SizedBox.shrink(), 
              const SizedBox(height: 25), 
              ElevatedButton(
                onPressed: _handleAuthButtonPress,
                child: Text(_currentUser != null ? "Logout" : "Login"),
              ),
            ],
          ),
          if (widget.onClose != null)
            ElevatedButton(onPressed: widget.onClose, child: const Text("Close")),
        ],
      ),
    );
  }
}