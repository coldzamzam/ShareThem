import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_shareit/models/user.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
  // final FirebaseStorage _storage = FirebaseStorage.instance;

  User? _currentUser;
  UserProfile? _userProfile;
  bool _isLoadingProfile = true;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  // State variables for the custom top notification
  String? _notificationMessage;
  Color? _notificationColor;
  bool _showNotification = false;
  Timer? _notificationTimer;

  bool _isSavingImageLocally = false; // Changed from _isUploadingImage

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user; // Update the current user
          _isLoadingProfile = true; // Reset loading state when user changes
        });
        if (user != null) {
          _loadUserProfile(user.uid); // Load profile if user is logged in
        } else {
          // Clear profile data if user logs out
          setState(() {
            _userProfile = null;
            _usernameController.clear();
            _phoneNumberController.clear();
            _addressController.clear();
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _isLoadingProfile = false; // No user, no profile to load
          });
        }
      }
    });

    // Load initial user state (if already logged in when screen opens)
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _loadUserProfile(_currentUser!.uid);
    } else {
      _isLoadingProfile = false; // No current user to load
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
            photoUrl:
            _currentUser?.photoURL, // This might still be from previous cloud storage
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
        // photoUrl will be updated separately by _pickImage
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
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // --- MODIFIED _pickImage function for Local Storage ---
  Future<void> _pickImage() async {
    if (_currentUser == null) {
      _showCustomTopNotification(
          'Please log in to change profile picture.', Colors.red);
      return;
    }

    // This local storage approach is not compatible with web.
    if (kIsWeb) {
      _showCustomTopNotification(
          'Image picking for local storage is not supported on Web.', Colors.red);
      print('Attempted to pick image for local storage on web. Not supported.');
      return;
    }

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image =
      await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

      if (image != null) {
        setState(() {
          _isSavingImageLocally = true; // Use the new state variable
        });

        // Get the application's documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final String appDirPath = appDir.path;

        // Create a unique file name (e.g., using user UID and timestamp)
        final String fileName =
            '${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String localPath =
        p.join(appDirPath, 'profile_pictures', fileName); // Save in a sub-folder

        // Ensure the directory exists
        final Directory profilePicsDir =
        Directory(p.join(appDirPath, 'profile_pictures'));
        if (!await profilePicsDir.exists()) {
          await profilePicsDir.create(recursive: true);
        }

        // Create a File object from the picked XFile path and copy it
        final File pickedImageFile = File(image.path);
        final File newImageFile = await pickedImageFile.copy(localPath);

        print('Image saved locally at: ${newImageFile.path}');

        // --- Update UserProfile and Firestore with the LOCAL PATH ---
        // photoUrl will now be a local file path
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'photoUrl': newImageFile.path, // Store the local path in Firestore
        });

        // await _currentUser!.updatePhotoURL(newImageFile.path); // Firebase Auth expects a URL, so this might not work well

        if (mounted) {
          setState(() {
            _userProfile!.photoUrl =
                newImageFile.path; // Update local state with the local path
            _isSavingImageLocally = false;
          });
          _showCustomTopNotification(
              'Profile picture saved locally!', Colors.green);
        }
      } else {
        print('Image picking cancelled.');
      }
    } catch (e) {
      print('Error picking or saving image locally: $e');
      if (mounted) {
        setState(() {
          _isSavingImageLocally = false;
        });
        _showCustomTopNotification(
            'An unexpected error occurred during image saving.', Colors.red,
            duration: const Duration(seconds: 5));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.white, // Set background to white
      body: Stack(
        children: [
          // Untuk menengahkan konten secara vertikal, kita akan membungkus Column utama
          // dengan Center atau Align, dan memastikan Expanded di dalamnya bekerja dengan benar.
          Center( // Menengahkan seluruh konten secara vertikal
            child: Column(
              mainAxisSize: MainAxisSize.min, // Menggunakan ukuran minimal agar Column tidak mengambil seluruh ruang yang tidak perlu
              children: [
                // SizedBox(height: MediaQuery.of(context).padding.top), // Tidak diperlukan di sini jika di Center

                // Expanded juga tidak diperlukan lagi karena SingleChildScrollView akan mengelola scroll
                // dan Center akan menengahkan di sisa ruang yang tersedia
                SingleChildScrollView( // Memastikan konten bisa discroll jika melebihi layar
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center, // Tetap center untuk horizontal
                    children: [
                      // SizedBox(height: 40) bisa disesuaikan atau dihapus tergantung desain
                      // Jika Center sudah digunakan, ini akan memberikan ruang dari atas konten.
                      const SizedBox(height: 40), // Menambah jarak dari atas konten

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
                          color: Colors.black87, // Adjusted color
                        ),
                      )
                          : const SizedBox.shrink(),
                      _currentUser != null
                          ? Text(
                        _currentUser!.email ?? 'No Email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600], // Adjusted color
                        ),
                      )
                          : const SizedBox.shrink(),
                      const SizedBox(height: 30),

                      // Tombol Login/Logout dan Close
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250), // Lebar maksimum tombol
                        child: Column(
                          children: [
                            if (_currentUser == null)
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
                                  child: const Text(
                                    "Login",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            if (_currentUser != null)
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
                                  child: const Text(
                                    "Logout",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      // SizedBox untuk padding bawah, sesuaikan jika perlu
                      SizedBox(
                          height: MediaQuery.of(context).padding.bottom > 0
                              ? MediaQuery.of(context).padding.bottom
                              : 20),
                    ],
                  ),
                ),
              ],
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

  // --- MODIFIED _buildProfilePictureSection function ---
  Widget _buildProfilePictureSection() {
    String? currentPhotoPath =
        _userProfile?.photoUrl; // This will now hold a local path or a cloud URL

    String? initial = _currentUser?.email?.isNotEmpty == true
        ? _currentUser!.email![0].toUpperCase()

        : (_userProfile?.username.isNotEmpty == true
            ? _userProfile!.username[0].toUpperCase()
            : null);


    // Check if the currentPhotoPath is a local file path AND if it exists
    File? localImageFile;
    bool isLocalImage = false;
    if (currentPhotoPath != null && !currentPhotoPath.startsWith('http')) {
      localImageFile = File(currentPhotoPath);
      // Check if the file actually exists on disk
      if (localImageFile.existsSync()) {
        isLocalImage = true;
      } else {
        print('Local image file not found at: $currentPhotoPath');
        localImageFile = null; // Clear if not found
        currentPhotoPath = null; // Also clear the path so it falls back to default
      }
    }

    return GestureDetector(
      onTap: _isSavingImageLocally ? null : _pickImage, // Disable tap during saving
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFAA88CC), Color(0xFF554DDE)], // Figma gradient for profile circle
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
            child: _isSavingImageLocally
                ? const CircularProgressIndicator(color: Colors.white) // Show loader
                : (isLocalImage
                ? ClipOval(
              child: Image.file(
                localImageFile!, // Use Image.file for local files
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultAvatar(initial),
              ),
            )
                : (currentPhotoPath != null && currentPhotoPath.isNotEmpty
                ? ClipOval(
              child: Image.network( // Still use Image.network for actual URLs
                currentPhotoPath,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultAvatar(initial),
              ),
            )
                : _buildDefaultAvatar(initial))),
          ),
          if (!_isSavingImageLocally)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFAA88CC), // Camera icon background color
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