import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_shareit/models/user.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _showEmailLoginForm = false;
  bool _isRegisterMode = false;

  // State variables for the custom top notification
  String? _notificationMessage;
  Color? _notificationColor;
  bool _showNotification = false;
  Timer? _notificationTimer;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneNumberController = TextEditingController(); 
  final _addressController = TextEditingController(); 

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Initialize Firestore

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose(); 
    _phoneNumberController.dispose();
    _addressController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _showCustomTopNotification(String message, Color backgroundColor, {Duration duration = const Duration(seconds: 3)}) {
    _notificationTimer?.cancel();
    setState(() {
      _notificationMessage = message;
      _notificationColor = backgroundColor;
      _showNotification = true;
    });
    _notificationTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _showNotification = false;
          _notificationMessage = null;
          _notificationColor = null;
        });
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _showCustomTopNotification('Google Sign-In canceled.', Colors.grey);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Check if this is a new user (first time signing in with Google)
        final User? user = userCredential.user;
        if (user != null) {
          final docRef = _firestore.collection('users').doc(user.uid);
          final docSnapshot = await docRef.get();

          if (!docSnapshot.exists) {
            // New Google user, create a profile in Firestore
            await docRef.set(UserProfile(
              uid: user.uid,
              email: user.email ?? 'N/A', // Google user usually has email
              username: user.displayName ?? 'Google User', // Use Google display name as initial username
              phoneNumber: null, // Can be added later in settings
              address: null,     // Can be added later in settings
            ).toMap());
            _showCustomTopNotification('New Google account created!', Colors.green);
          } else {
            _showCustomTopNotification('Logged in with Google successfully!', Colors.green);
          }
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home'); // Navigate to home or settings
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Caught FirebaseAuthException during Google Sign-In: ${e.code} - ${e.message}');
      String message;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message = 'Akun sudah terdaftar dengan metode lain. Silakan gunakan metode login yang berbeda.';
          break;
        case 'invalid-credential':
          message = 'Kredensial Google tidak valid.';
          break;
        case 'network-request-failed':
          message = 'Tidak dapat terhubung ke internet.';
          break;
        default:
          message = 'Terjadi kesalahan saat login Google: ${e.message}';
          break;
      }
      _showCustomTopNotification(message, Colors.red, duration: const Duration(seconds: 5));
    } catch (e) {
      print('Caught generic exception during Google Sign-In: ${e.toString()}');
      _showCustomTopNotification(
        'Terjadi kesalahan tak terduga saat login Google: ${e.toString()}',
        Colors.red,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim(); // Get new field values
    final phoneNumber = _phoneNumberController.text.trim().isEmpty ? null : _phoneNumberController.text.trim();
    final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();


    try {
      if (_isRegisterMode) {
        print('Attempting to create user with email: $email');
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('User created successfully: ${userCredential.user?.uid}');

        final User? user = userCredential.user;
        if (user != null) {
          // Store additional user data in Firestore
          await _firestore.collection('users').doc(user.uid).set(UserProfile(
            uid: user.uid,
            email: email,
            username: username,
            phoneNumber: phoneNumber,
            address: address,
          ).toMap());
          print('User profile saved to Firestore.');

          _showCustomTopNotification('Register successful!', Colors.green);

          await user.sendEmailVerification();
          print('Verification email sent to: $email');

          _showCustomTopNotification(
            'A verification email has been sent to $email. Please verify before logging in.',
            Colors.orange,
            duration: const Duration(seconds: 5),
          );

          await _auth.signOut(); // Sign out after registration for verification

          setState(() {
            _isRegisterMode = false;
            _emailController.clear();
            _passwordController.clear();
            _usernameController.clear(); // Clear new controllers
            _phoneNumberController.clear();
            _addressController.clear();
            _showEmailLoginForm = true;
          });
        }
      } else {
        print('Attempting to sign in user with email: $email');
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('User signed in successfully: ${userCredential.user?.uid}');

        if (userCredential.user != null && userCredential.user!.emailVerified) {
          _showCustomTopNotification('Logged in successfully!', Colors.green);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          print('User not verified. Signing out.');
          await _auth.signOut();

          if (mounted) { // Ensure context is valid before showing dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Email not verified'),
                content: const Text(
                  'Please verify your email before logging in. Would you like to resend the verification email?',
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      try {
                        // Attempt to sign in again just to get the user object for resending verification
                        // (This is a workaround as userCredential.user becomes null after signOut)
                        final UserCredential tempUserCredential = await _auth.signInWithEmailAndPassword(
                          email: email,
                          password: password,
                        );
                        await tempUserCredential.user?.sendEmailVerification();
                        await _auth.signOut(); // Sign out again

                        if (mounted) Navigator.pop(context);
                        _showCustomTopNotification('Verification email resent.', Colors.orange);
                      } on FirebaseAuthException catch (e) {
                         print('Error during resend email: ${e.code} - ${e.message}');
                         if (mounted) Navigator.pop(context);
                         _showCustomTopNotification(
                           'Failed to resend verification email: ${e.message}',
                           Colors.red,
                           duration: const Duration(seconds: 5),
                         );
                      }
                    },
                    child: const Text('Resend'),
                  ),
                  TextButton(
                    onPressed: () {
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Caught FirebaseAuthException: ${e.code} - ${e.message}');
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'Email sudah digunakan oleh akun lain.';
          break;
        case 'invalid-email':
          message = 'Format email tidak valid.';
          break;
        case 'weak-password':
          message = 'Password terlalu lemah. Gunakan minimal 6 karakter.';
          break;
        case 'user-not-found':
          message = 'Akun dengan email ini tidak ditemukan.';
          break;
        case 'wrong-password':
          message = 'Password salah.';
          break;
        case 'network-request-failed':
          message = 'Tidak dapat terhubung ke internet.';
          break;
        default:
          message = 'Terjadi kesalahan: ${e.message}';
          break;
      }
      print('Displaying error message: $message');
      _showCustomTopNotification(message, Colors.red, duration: const Duration(seconds: 5));
    } catch (e) {
      print('Caught generic exception: ${e.toString()}');
      _showCustomTopNotification(
        'An unexpected error occurred: ${e.toString()}',
        Colors.red,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // No need for screenSize.height in the main build if we're using Column + Spacer for alignment
    // The SingleChildScrollView should simply encompass the content that *needs* to scroll.

    return Scaffold(
      resizeToAvoidBottomInset: true, // This is crucial and correct
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8E44AD), Color(0xFFD2B4DE)],
              ),
            ),
          ),

          // Main content column
          Column( // This main Column now controls the overall layout
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 50), 
              const Text(
                'Sign in to ShareThem',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Use Expanded with SingleChildScrollView for the scrollable middle content
              Expanded( 
                child: SingleChildScrollView( 
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Card(
                        margin: const EdgeInsets.all(0), // Margin moved to padding of SCV
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child:
                                _showEmailLoginForm
                                    ? _buildEmailForm(context) // This _buildEmailForm also uses SingleChildScrollView internally
                                    : _buildInitialButtons(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '© ShareThem Copyright Kelompok 2 PBL 2025',
                  style: TextStyle(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),

          // Custom Top Notification Layer (on top of everything)
          if (_showNotification && _notificationMessage != null && _notificationColor != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20.0, // Position below system status bar
              left: 20.0,
              right: 20.0,
              child: Material( // Wrap in Material to get elevation and shape
                color: _notificationColor,
                elevation: 6.0,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Text(
                    _notificationMessage!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildInitialButtons(BuildContext context) {
    return Column(
      key: const ValueKey<int>(0),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sign In',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _signInWithGoogle,
            icon: Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
              height: 20,
              errorBuilder:
                  (context, error, stackTrace) =>
                      const Icon(Icons.g_mobiledata),
            ),
            label: const Text('Google'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showEmailLoginForm = true;
                _isRegisterMode = false; 
              });
            },
            icon: const Icon(Icons.email),
            label: const Text('Email'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            icon: const Icon(Icons.home),
            label: const Text('Back to home'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          key: const ValueKey<int>(1),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isRegisterMode ? 'Register with Email' : 'Login with Email',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            if (_isRegisterMode) ...[ // Only show these fields in register mode
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (_isRegisterMode && (value == null || value.isEmpty)) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: 'e.g., +6281234567890',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                // No validator for optional field unless strict format is needed
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                keyboardType: TextInputType.streetAddress,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Address (Optional)',
                  hintText: 'Your full address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                // No validator for optional field
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 8) {
                  return 'Password should be at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _isRegisterMode ? 'Register' : 'Login',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _isRegisterMode = !_isRegisterMode;
                  _emailController.clear();
                  _passwordController.clear();
                  _usernameController.clear();
                  _phoneNumberController.clear();
                  _addressController.clear();
                  _formKey.currentState?.reset();
                });
              },
              child: Text(
                _isRegisterMode
                    ? 'Already have an account? Login'
                    : 'Don\'t have an account? Register',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showEmailLoginForm = false;
                    _emailController.clear();
                    _passwordController.clear();
                    _usernameController.clear();
                    _phoneNumberController.clear();
                    _addressController.clear();
                    _isRegisterMode = false;
                    _formKey.currentState?.reset();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}