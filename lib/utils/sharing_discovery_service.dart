import 'package:bonsoir/bonsoir.dart';
import 'dart:async';

class SharingDiscoveryService {
  static bool isDiscoverable = false;
  static bool isSearching = false;

  static const String _serviceType = '_sharing-service._tcp';
  static const int _servicePort = 48230;

  static BonsoirBroadcast? _broadcaster;
  static BonsoirService? _currentBroadcastService;

  static BonsoirDiscovery _discovery = BonsoirDiscovery(type: _serviceType);

  static final StreamController<BonsoirService> _resolvedServiceController =
      StreamController<BonsoirService>.broadcast();

  static Stream<BonsoirService> get resolvedServiceStream =>
      _resolvedServiceController.stream;

  static Future<void> beginBroadcast({String deviceName = "Unknown Device"}) async {
    if (isDiscoverable) {
      await stopBroadcast();
    }

    _currentBroadcastService = BonsoirService(
      name: deviceName,
      type: _serviceType,
      port: _servicePort
    );

    _broadcaster = BonsoirBroadcast(service: _currentBroadcastService!);

    await _broadcaster!.ready;
    await _broadcaster!.start();
    isDiscoverable = true;

    print('Broadcasting started');
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

  static Future<Stream<BonsoirDiscoveryEvent>?> beginDiscovery() async {
    if (isSearching) {
      print("Discovery already in progress.");
      return _discovery.eventStream;
    }
    if (_discovery.isStopped) {
      _discovery = BonsoirDiscovery(type: _serviceType);
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
