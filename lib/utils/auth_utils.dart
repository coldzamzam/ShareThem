// lib/utils/auth_utils.dart (as provided by you)

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

/// --- 1. Real Authentication Service ---
/// This service interfaces with FirebaseAuth to get the currently logged-in user.
class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the UID of the current user, or null if no user is logged in.
  String? getCurrentUserId() {
    final User? user = _auth.currentUser;
    return user?.uid;
  }
}


/// --- 2. Centralized Path Helper (Unchanged) ---
/// This function gets the user-specific directory for storing and retrieving files.
Future<Directory> getDownloadDirectoryForUser(String userId) async {
  if (userId.isEmpty) {
    throw Exception("User ID cannot be empty.");
  }
  
  final baseDir = await getExternalStorageDirectory();
  if (baseDir == null) {
    throw Exception("Could not access storage directory.");
  }

  // The path will now be like: .../downloads/<firebase_user_id>/
  final userDownloadsDir = Directory(p.join(baseDir.path, 'downloads', userId));

  // Ensure the directory exists.
  if (!await userDownloadsDir.exists()) {
    await userDownloadsDir.create(recursive: true);
  }
  
  return userDownloadsDir;
}