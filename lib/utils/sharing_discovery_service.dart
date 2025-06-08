import 'package:bonsoir/bonsoir.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';

// Import yang ditambahkan untuk Firebase
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SharingDiscoveryService {
  static final String _sessionId = Uuid().v7();

  static bool isDiscoverable = false;
  static bool isSearching = false;

  static const String serviceType = '_sharing-service._tcp';
  static const int servicePort = 48230;

  static BonsoirBroadcast? _broadcaster;
  static BonsoirService? _currentBroadcastService;

  static BonsoirDiscovery _discovery = BonsoirDiscovery(type: serviceType);

  static final StreamController<BonsoirService> _resolvedServiceController =
      StreamController<BonsoirService>.broadcast();

  static Stream<BonsoirService> get resolvedServiceStream =>
      _resolvedServiceController.stream;

  // --- METODE YANG DIMODIFIKASI ---
  static Future<void> beginBroadcast() async {
    if (isDiscoverable) {
      await stopBroadcast();
    }

    String deviceName = "Unknown Device"; // Nama default
    final User? currentUser = FirebaseAuth.instance.currentUser;

    // Periksa apakah ada pengguna yang sedang login
    if (currentUser != null) {
      try {
        final docSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();

        // Periksa apakah dokumen ada dan berisi data
        if (docSnapshot.exists && docSnapshot.data() != null) {
          deviceName = docSnapshot.data()!['username'] ?? "Nameless User";
        }
      } catch (e) {
        print("Error fetching username from Firestore: $e");
        // Jika terjadi error, tetap gunakan nama default
      }
    }

    _currentBroadcastService = BonsoirService(
      name: deviceName, // Gunakan username yang telah diambil
      type: serviceType,
      port: servicePort,
      attributes: {"sessionId": _sessionId},
    );

    _broadcaster = BonsoirBroadcast(service: _currentBroadcastService!);

    await _broadcaster!.ready;
    await _broadcaster!.start();
    isDiscoverable = true;

    print('Broadcasting started with device name: $deviceName');
  }

  static Future<void> stopBroadcast() async {
    if (_broadcaster != null) {
      await _broadcaster!.stop();
      _broadcaster = null;
      _currentBroadcastService = null;
      isDiscoverable = false;
      print('Broadcasting stopped.');
    }
  }

  static Future<void> resolveService(BonsoirService service) async {
    await _discovery.serviceResolver.resolveService(service);
  }

  static Future<Stream<BonsoirDiscoveryEvent>?> beginDiscovery() async {
    if (isSearching) {
      print("Discovery already in progress.");
      return _discovery.eventStream;
    }
    if (_discovery.isStopped) {
      _discovery = BonsoirDiscovery(type: serviceType);
    }

    await _discovery.ready;
    await _discovery.start();
    isSearching = true;
    print("Discovery started.");

    return _discovery.eventStream;
  }

  static Future<void> stopDiscovery() async {
    if (isSearching) {
      await _discovery.stop();
      isSearching = false;
      print("Discovery stopped.");
    }
  }

  static Future<void> dispose() async {
    await stopBroadcast();
    await stopDiscovery();
    if (!_resolvedServiceController.isClosed) {
      await _resolvedServiceController.close();
    }
  }
}
