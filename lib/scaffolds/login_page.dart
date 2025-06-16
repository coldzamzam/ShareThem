import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_shareit/models/user.dart'; // Pastikan path import model ini benar

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // =======================================================================
  // BAGIAN LOGIKA (TIDAK ADA YANG DIUBAH)
  // Semua state, controller, dan fungsi Anda tetap sama.
  // =======================================================================
  bool _showEmailLoginForm = false;
  bool _isRegisterMode = false;
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    if (mounted) {
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
  }

  Future<void> _signInWithGoogle() async {
    // Fungsi ini tidak diubah
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
        final User? user = userCredential.user;
        if (user != null) {
          final docRef = _firestore.collection('users').doc(user.uid);
          final docSnapshot = await docRef.get();

          if (!docSnapshot.exists) {
            await docRef.set(UserProfile(
              uid: user.uid,
              email: user.email ?? 'N/A',
              username: user.displayName ?? 'Google User',
              phoneNumber: null,
              address: null,
            ).toMap());
            _showCustomTopNotification('New Google account created!', Colors.green);
          } else {
            _showCustomTopNotification('Logged in with Google successfully!', Colors.green);
          }
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      }
    } on FirebaseAuthException catch (e) {
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
      _showCustomTopNotification(
        'Terjadi kesalahan tak terduga saat login Google: ${e.toString()}',
        Colors.red,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _handleSubmit() async {
    // Fungsi ini tidak diubah
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim().isEmpty ? null : _phoneNumberController.text.trim();
    final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();

    try {
      if (_isRegisterMode) {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final User? user = userCredential.user;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).set(UserProfile(
            uid: user.uid,
            email: email,
            username: username,
            phoneNumber: phoneNumber,
            address: address,
          ).toMap());

          _showCustomTopNotification('Register successful!', Colors.green);

          await user.sendEmailVerification();
          _showCustomTopNotification(
            'A verification email has been sent to $email. Please verify before logging in.',
            Colors.orange,
            duration: const Duration(seconds: 5),
          );

          await _auth.signOut();

          setState(() {
            _isRegisterMode = false;
            _showEmailLoginForm = true;
            _emailController.clear();
            _passwordController.clear();
            _usernameController.clear();
            _phoneNumberController.clear();
            _addressController.clear();
          });
        }
      } else {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null && userCredential.user!.emailVerified) {
          _showCustomTopNotification('Logged in successfully!', Colors.green);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          await _auth.signOut();
          if (mounted) {
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
                        final tempUserCredential = await _auth.signInWithEmailAndPassword(
                          email: email,
                          password: password,
                        );
                        await tempUserCredential.user?.sendEmailVerification();
                        await _auth.signOut();
                        if (mounted) Navigator.pop(context);
                        _showCustomTopNotification('Verification email resent.', Colors.orange);
                      } on FirebaseAuthException catch (e) {
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
      _showCustomTopNotification(message, Colors.red, duration: const Duration(seconds: 5));
    } catch (e) {
      _showCustomTopNotification(
        'An unexpected error occurred: ${e.toString()}',
        Colors.red,
        duration: const Duration(seconds: 5),
      );
    }
  }

  // =======================================================================
  // BAGIAN UI (SEMUA DI BAWAH INI TELAH DIPERBARUI SESUAI DESAIN)
  // =======================================================================
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildCurvedBackground(context, screenHeight),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.1),
                  const Text(
                    'Sign in to ShareThem',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10.0, color: Colors.black26)],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 8.0,
                    shadowColor: Colors.black38,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _showEmailLoginForm
                              ? _buildEmailForm(context)
                              : _buildInitialButtons(context),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      '© ShareThem 2025.\nAll rights reserved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showNotification && _notificationMessage != null && _notificationColor != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20.0,
              left: 20.0,
              right: 20.0,
              child: Material(
                color: _notificationColor,
                elevation: 6.0,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Text(
                    _notificationMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurvedBackground(BuildContext context, double screenHeight) {
    return ClipPath(
      clipper: _LoginShapeClipper(),
      child: Container(
        height: screenHeight * 0.4,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFBCA4EC), Color(0xFF8C82E3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({required VoidCallback onPressed, required String label, Widget? icon}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFAD78D9), Color(0xFF8667E3)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[icon, const SizedBox(width: 10)],
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialButtons(BuildContext context) {
    return Column(
      key: const ValueKey<int>(0),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Sign In',
          style: TextStyle(color: Color(0xFF333333), fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildGradientButton(
          onPressed: _signInWithGoogle,
          label: 'Google',
          icon: Image.network(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
            height: 20,
            width: 20,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 20),
          ),
        ),

        const SizedBox(height: 12),
        _buildGradientButton(
          onPressed: () => setState(() => _showEmailLoginForm = true),
          label: 'Email',
          icon: const Icon(Icons.email, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 12),
        _buildGradientButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          label: 'Back to home',
        ),
      ],
    );
  }

  Widget _buildEmailForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey<int>(1),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isRegisterMode ? 'Register with Email' : 'Login with Email',
            style: const TextStyle(color: Color(0xFF333333), fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(controller: _emailController, decoration: _inputDecoration('Email', Icons.email_outlined), validator: (v) => v!.isEmpty ? 'Email tidak boleh kosong' : null),
          if (_isRegisterMode) ...[
            const SizedBox(height: 12),
            TextFormField(controller: _usernameController, decoration: _inputDecoration('Username', Icons.person_outline), validator: (v) => v!.isEmpty ? 'Username tidak boleh kosong' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneNumberController, decoration: _inputDecoration('Phone Number (Optional)', Icons.phone)),
            const SizedBox(height: 12),
            TextFormField(controller: _addressController, decoration: _inputDecoration('Address (Optional)', Icons.location_on)),
          ],
          const SizedBox(height: 12),
          TextFormField(controller: _passwordController, obscureText: true, decoration: _inputDecoration('Password', Icons.lock_outline), validator: (v) => v!.length < 6 ? 'Password minimal 6 karakter' : null),
          const SizedBox(height: 20),
          _buildGradientButton(onPressed: _handleSubmit, label: _isRegisterMode ? 'Register' : 'Login'),
          TextButton(
            onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
            child: Text(_isRegisterMode ? 'Already have an account? Login' : 'Don\'t have an account? Register'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to options'),
            onPressed: () => setState(() => _showEmailLoginForm = false),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8C82E3), width: 2)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}

class _LoginShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}