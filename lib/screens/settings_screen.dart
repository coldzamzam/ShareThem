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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      // --- Changed from 'drawer' to 'endDrawer' ---
      endDrawer: Drawer( // This makes the drawer appear from the right
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
                    'Choose Your Avatar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentUser?.email ?? 'Guest',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
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
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _availableAvatars.length,
                itemBuilder: (context, index) {
                  final avatarPath = _availableAvatars[index];
                  final isSelected = _userProfile?.photoUrl == avatarPath;
                  return GestureDetector(
                    onTap: () => _updateAvatar(avatarPath),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: isSelected ? 3 : 1,
                        ),
                        color: Colors.grey[100],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 15, 16, 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Settings",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 30),
                        onPressed: widget.onClose,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 100.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProfilePictureSection(),
                      const SizedBox(height: 10),
                      _currentUser != null
                          ? Text(
                              _userProfile?.username ??
                                  _currentUser!.email ??
                                  'No Username/Email',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            )
                          : const SizedBox.shrink(),
                      _currentUser != null
                          ? Text(
                              _currentUser!.email ?? 'No Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            )
                          : const SizedBox(height: 10),
                      const SizedBox(height: 30),

                      if (_currentUser != null)
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profile Information',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              const Divider(height: 20, thickness: 1.5, color: Colors.grey),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.person),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Username cannot be empty';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneNumberController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.phone),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                keyboardType: TextInputType.streetAddress,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Address',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.location_on),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _updateProfile,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Update Profile'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8E44AD),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),

                              if (_currentUser != null && _currentUser!.providerData.any((info) => info.providerId == 'password'))
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Change Password',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                    const Divider(height: 20, thickness: 1.5, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _currentPasswordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'Current Password',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        prefixIcon: const Icon(Icons.lock_open),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your current password';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _newPasswordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'New Password',
                                        hintText: 'Minimum 6 characters',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        prefixIcon: const Icon(Icons.lock),
                                        filled: true,
                                        fillColor: Colors.grey[50],
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
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _changePassword,
                                        icon: const Icon(Icons.vpn_key),
                                        label: const Text('Change Password'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFD2B4DE),
                                          foregroundColor: Colors.black87,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          textStyle: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isWideScreen ? double.infinity : 250),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFAA88CC), Color(0xFF554DDE)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: ElevatedButton(
                                onPressed: _handleAuthButtonPress,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  textStyle: const TextStyle(fontSize: 18),
                                ),
                                child: Text(
                                  _currentUser != null ? "Logout" : "Login",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            if (widget.onClose != null)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: widget.onClose,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey[700],
                                    side: BorderSide(color: Colors.grey.shade400),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    textStyle: const TextStyle(fontSize: 18),
                                  ),
                                  child: const Text("Close"),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).padding.bottom > 0
                              ? MediaQuery.of(context).padding.bottom
                              : 20),
                    ],
                  ),
                ),
              ),
            ],
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
        width: 50,
        height: 50,
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else if (currentPhotoPath != null && currentPhotoPath.startsWith('assets/')) {
      imageWidget = ClipOval(
        child: Image.asset(
          currentPhotoPath,
          width: 150,
          height: 150,
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
          width: 150,
          height: 150,
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
      // --- Changed to openEndDrawer() ---
      onTap: _isUpdatingAvatar ? null : () => _scaffoldKey.currentState?.openEndDrawer(), // Open from right
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFAA88CC), Color(0xFF554DDE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
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
                  color: const Color(0xFFAA88CC),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 24,
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
      style: const TextStyle(fontSize: 60, color: Colors.white),
    )
        : const Icon(Icons.person, size: 100, color: Colors.white);
  }
}