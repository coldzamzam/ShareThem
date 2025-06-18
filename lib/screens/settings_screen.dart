import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_shareit/models/user.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const SettingsScreen({super.key, this.onClose});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  User? _currentUser;
  UserProfile? _userProfile;
  bool _isLoadingProfile = true;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String? _notificationMessage;
  Color? _notificationColor;
  bool _showNotification = false;
  Timer? _notificationTimer;

  bool _isUpdatingAvatar = false;

  final List<String> _availableAvatars = [
    'assets/avatars/Avatar_1.png',
    'assets/avatars/Avatar_2.png',
    'assets/avatars/Avatar_3.png',
    'assets/avatars/Avatar_4.png',
    'assets/avatars/Avatar_5.png',
    'assets/avatars/Avatar_6.png',
  ];

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoadingProfile = true;
        });
        if (user != null) {
          _loadUserProfile(user.uid);
        } else {
          setState(() {
            _userProfile = null;
            _usernameController.clear();
            _phoneNumberController.clear();
            _addressController.clear();
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _isLoadingProfile = false;
          });
        }
      }
    });

    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _loadUserProfile(_currentUser!.uid);
    } else {
      _isLoadingProfile = false;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _showCustomTopNotification(String message, Color backgroundColor,
      {Duration duration = const Duration(seconds: 3)}) {
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

  Future<void> _loadUserProfile(String uid) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      if (mounted) {
        UserProfile? fetchedUserProfile;
        if (docSnapshot.exists) {
          fetchedUserProfile = UserProfile.fromMap(docSnapshot.data()!);
        } else {
          _showCustomTopNotification(
              'User profile not found. Creating a basic one.', Colors.orange,
              duration: const Duration(seconds: 5));
          fetchedUserProfile = UserProfile(
            uid: uid,
            email: _currentUser?.email ?? 'N/A',
            username: _currentUser?.displayName ?? 'New User',
            photoUrl: _currentUser?.photoURL,
          );
          await _firestore
              .collection('users')
              .doc(uid)
              .set(fetchedUserProfile.toMap());
        }

        setState(() {
          _isLoadingProfile = false;
          _userProfile = fetchedUserProfile;
          _usernameController.text = _userProfile!.username;
          _phoneNumberController.text = _userProfile!.phoneNumber ?? '';
          _addressController.text = _userProfile!.address ?? '';
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        _showCustomTopNotification('Failed to load user profile.', Colors.red,
            duration: const Duration(seconds: 5));
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_currentUser == null || _userProfile == null) return;

    try {
      final updatedData = {
        'username': _usernameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim().isEmpty
            ? null
            : _phoneNumberController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      };

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updatedData);

      if (_currentUser!.displayName != _usernameController.text.trim()) {
        await _currentUser!.updateDisplayName(_usernameController.text.trim());
      }

      if (mounted) {
        setState(() {
          _userProfile!.username = _usernameController.text.trim();
          _userProfile!.phoneNumber = _phoneNumberController.text.trim().isEmpty
              ? null
              : _phoneNumberController.text.trim();
          _userProfile!.address = _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim();
        });
        _showCustomTopNotification('Profile updated successfully!', Colors.green);
      }
    } on FirebaseException catch (e) {
      print('Error updating profile: ${e.code} - ${e.message}');
      if (mounted)
        _showCustomTopNotification(
            'Failed to update profile: ${e.message}', Colors.red,
            duration: const Duration(seconds: 5));
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted)
        _showCustomTopNotification(
            'An unexpected error occurred while updating profile: $e',
            Colors.red,
            duration: const Duration(seconds: 5));
    }
  }

  Future<void> _changePassword() async {
    if (_currentUser == null) return;

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _showCustomTopNotification(
          'Please enter both current and new passwords.', Colors.red);
      return;
    }
    if (newPassword.length < 6) {
      _showCustomTopNotification(
          'New password must be at least 6 characters.', Colors.red);
      return;
    }

    try {
      final AuthCredential credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: currentPassword,
      );
      await _currentUser!.reauthenticateWithCredential(credential);

      await _currentUser!.updatePassword(newPassword);

      if (mounted) {
        _showCustomTopNotification('Password updated successfully!', Colors.green);
        _currentPasswordController.clear();
        _newPasswordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect.';
          break;
        case 'requires-recent-login':
          message =
          'This operation is sensitive and requires recent authentication. Please re-login.';
          break;
        case 'weak-password':
          message = 'New password is too weak.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message = 'Failed to change password: ${e.message}';
          break;
      }
      if (mounted)
        _showCustomTopNotification(message, Colors.red,
            duration: const Duration(seconds: 5));
      print('Error changing password: ${e.code} - ${e.message}');
    } catch (e) {
      if (mounted)
        _showCustomTopNotification(
            'An unexpected error occurred: $e', Colors.red,
            duration: const Duration(seconds: 5));
      print('Generic error changing password: $e');
    }
  }

  Future<void> _handleAuthButtonPress() async {
    if (_currentUser != null) {
      try {
        await _auth.signOut();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.pushReplacementNamed(context, '/login');
          _showCustomTopNotification('Logged out successfully!', Colors.green);
        }
      } catch (e) {
        if (mounted) {
          _showCustomTopNotification(
              'Error logging out: ${e.toString()}', Colors.red);
        }
      }
    } else {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _updateAvatar(String newAvatarPath) async {
    if (_currentUser == null) return;

    // Use _scaffoldKey.currentState?.closeEndDrawer() to close the right-side drawer
    if (_scaffoldKey.currentState?.isEndDrawerOpen == true) {
      _scaffoldKey.currentState?.closeEndDrawer();
    }

    if (newAvatarPath != _userProfile?.photoUrl) {
      setState(() {
        _isUpdatingAvatar = true;
      });
      try {
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'photoUrl': newAvatarPath,
        });

        if (mounted) {
          setState(() {
            _userProfile!.photoUrl = newAvatarPath;
          });
          _showCustomTopNotification('Profile picture updated!', Colors.green);
        }
      } catch (e) {
        print('Error updating avatar: $e');
        _showCustomTopNotification('An error occurred during avatar update.', Colors.red);
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingAvatar = false;
          });
        }
      }
    } else {
      print('Same avatar selected.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isWideScreen = MediaQuery.of(context).size.width > 600;

    return Container( // Wrapper Container untuk background gradient halaman
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF9F5FF), Color(0xFFEEEBFF)], // Background yang Anda pilih
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        endDrawer: Drawer( // This makes the drawer appear from the right
          child: Container( // Tambahkan Container untuk background gradien di Drawer
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEEEBFF), Color(0xFFF9F5FF)], // Gradien terbalik atau disesuaikan untuk Drawer
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                DrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFAA88CC), Color(0xFF554DDE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Pilih Avatar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUser?.email ?? 'Guest',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _availableAvatars.length,
                    itemBuilder: (context, index) {
                      final avatarPath = _availableAvatars[index];
                      final isSelected = _userProfile?.photoUrl == avatarPath;
                      return GestureDetector(
                        onTap: () => _updateAvatar(avatarPath),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF554DDE) // Border primaryDark saat selected
                                  : Colors.transparent,
                              width: isSelected ? 4 : 1,
                            ),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? const Color(0xFF554DDE).withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                                blurRadius: 5,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              avatarPath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.broken_image, size: 40, color: Colors.red);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 100.0 : 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        _buildProfilePictureSection(),
                        const SizedBox(height: 20),
                        _currentUser != null
                            ? Text(
                                _userProfile?.username ??
                                    _currentUser!.email ??
                                    'No Username/Email',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                              )
                            : const SizedBox.shrink(),
                        _currentUser != null
                            ? Text(
                                _currentUser!.email ?? 'No Email',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              )
                            : const SizedBox(height: 10),
                        const SizedBox(height: 40),

                        if (_currentUser != null)
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Profile Information',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF554DDE), // Warna dari primaryDark
                                  ),
                                ),
                                const Divider(height: 30, thickness: 2, color: Color(0xFFAA88CC)), // Divider lebih tebal & warna primaryLight
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Color(0xFFAA88CC), width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Color(0xFF554DDE), width: 2),
                                    ),
                                    prefixIcon: const Icon(Icons.person, color: Color(0xFFAA88CC)), // Icon dengan warna primaryLight
                                    filled: true,
                                    fillColor: Colors.white,
                                    labelStyle: TextStyle(color: Colors.grey[700]),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Username cannot be empty';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _phoneNumberController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Color(0xFFAA88CC), width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Color(0xFF554DDE), width: 2),
                                    ),
                                    prefixIcon: const Icon(Icons.phone, color: Color(0xFFAA88CC)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    labelStyle: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _addressController,
                                  keyboardType: TextInputType.streetAddress,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Address',
                                    alignLabelWithHint: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Color(0xFFAA88CC), width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Color(0xFF554DDE), width: 2),
                                    ),
                                    prefixIcon: const Icon(Icons.location_on, color: Color(0xFFAA88CC)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    labelStyle: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                                const SizedBox(height: 30),

                                Align(
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    onTap: _updateProfile,
                                    child: Container(
                                      constraints: const BoxConstraints(maxWidth: 300),
                                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFAA88CC), Color(0xFF554DDE)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF554DDE).withOpacity(0.4),
                                            blurRadius: 2,
                                            offset: const Offset(0, 0),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.save, color: Colors.white, size: 20),
                                          SizedBox(width: 10),
                                          Text(
                                            'Update Profile',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 40),

                                if (_currentUser != null && _currentUser!.providerData.any((info) => info.providerId == 'password'))
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Change Password',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF554DDE),
                                        ),
                                      ),
                                      const Divider(height: 30, thickness: 2, color: Color(0xFFAA88CC)),
                                      const SizedBox(height: 20),
                                      TextFormField(
                                        controller: _currentPasswordController,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          labelText: 'Current Password',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(15),
                                            borderSide: const BorderSide(color: Color(0xFFAA88CC), width: 1.5),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(15),
                                            borderSide: const BorderSide(color: Color(0xFF554DDE), width: 2),
                                          ),
                                          prefixIcon: const Icon(Icons.lock_open, color: Color(0xFFAA88CC)),
                                          filled: true,
                                          fillColor: Colors.white,
                                          labelStyle: TextStyle(color: Colors.grey[700]),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your current password';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      TextFormField(
                                        controller: _newPasswordController,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          labelText: 'New Password',
                                          hintText: 'Minimum 6 characters',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(15),
                                            borderSide: const BorderSide(color: Color(0xFFAA88CC), width: 1.5),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(15),
                                            borderSide: const BorderSide(color: Color(0xFF554DDE), width: 2),
                                          ),
                                          prefixIcon: const Icon(Icons.lock, color: Color(0xFFAA88CC)),
                                          filled: true,
                                          fillColor: Colors.white,
                                          labelStyle: TextStyle(color: Colors.grey[700]),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a new password';
                                          }
                                          if (value.length < 6) {
                                            return 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 30),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _changePassword,
                                          icon: const Icon(Icons.vpn_key, color: Colors.white),
                                          label: const Text('Change Password', style: TextStyle(color: Colors.white)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF554DDE), // Warna utama primaryDark
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                            elevation: 0,
                                            shadowColor: const Color(0xFF554DDE).withOpacity(0.4), // Shadow dari primaryDark
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _handleAuthButtonPress,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFE5484A), Color(0xFFCD2427)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFCD2427).withOpacity(0.4),
                                        blurRadius: 2,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _currentUser != null ? "Logout" : "Login",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(
                            height: MediaQuery.of(context).padding.bottom > 0
                                ? MediaQuery.of(context).padding.bottom + 20
                                : 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_showNotification && _notificationMessage != null && _notificationColor != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: _showNotification ? MediaQuery.of(context).padding.top + 60.0 : 0,
                  color: _notificationColor,
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10.0, left: 20, right: 20),
                    child: Text(
                      _notificationMessage!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    String? currentPhotoPath = _userProfile?.photoUrl;

    String? initial = _currentUser?.email?.isNotEmpty == true
        ? _currentUser!.email![0].toUpperCase()
        : (_userProfile?.username?.isNotEmpty == true
        ? _userProfile!.username[0].toUpperCase()
        : null);

    Widget imageWidget;
    if (_isUpdatingAvatar) {
      imageWidget = const SizedBox(
        width: 60,
        height: 60,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 5),
      );
    } else if (currentPhotoPath != null && currentPhotoPath.startsWith('assets/')) {
      imageWidget = ClipOval(
        child: Image.asset(
          currentPhotoPath,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading asset image $currentPhotoPath: $error');
            return _buildDefaultAvatar(initial);
          },
        ),
      );
    } else if (currentPhotoPath != null && currentPhotoPath.startsWith('http')) {
      imageWidget = ClipOval(
        child: Image.network(
          currentPhotoPath,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading network image $currentPhotoPath: $error');
            return _buildDefaultAvatar(initial);
          },
        ),
      );
    } else {
      imageWidget = _buildDefaultAvatar(initial);
    }

    return GestureDetector(
      onTap: _isUpdatingAvatar ? null : () => _scaffoldKey.currentState?.openEndDrawer(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFAA88CC), Color(0xFF554DDE)], // Gradien primary color
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF554DDE).withOpacity(0.3), // Shadow dari primaryDark
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: imageWidget,
          ),
          if (!_isUpdatingAvatar)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFAA88CC), Color(0xFF554DDE)], // Gradien primary color
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF554DDE).withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String? initial) {
    return initial != null
        ? Text(
      initial,
      style: const TextStyle(fontSize: 70, color: Colors.white, fontWeight: FontWeight.bold),
    )
        : const Icon(Icons.person, size: 120, color: Colors.white);
  }
}