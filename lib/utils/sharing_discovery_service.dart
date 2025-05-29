import 'package:bonsoir/bonsoir.dart';
import 'dart:io';
import 'dart:async';

// Model to hold file information
class SharedFileInfo {
  final String name;
  final int size; // Size in bytes
  final String? path; // Optional: if you need the path on the sender side

  SharedFileInfo({required this.name, required this.size, this.path});

  Map<String, String> toAttributes() {
    return {
      'fileName': name,
      'fileSize': size.toString(),
      // Add other relevant info as strings if needed
    };
  }

  static SharedFileInfo? fromAttributes(Map<String, String>? attributes) {
    if (attributes == null ||
        !attributes.containsKey('fileName') ||
        !attributes.containsKey('fileSize')) {
      return null;
    }
    try {
      return SharedFileInfo(
        name: attributes['fileName']!,
        size: int.parse(attributes['fileSize']!),
      );
    } catch (e) {
      print("Error parsing SharedFileInfo from attributes: $e");
      return null;
    }
  }
}

class SharingDiscoveryService {
  static const String _serviceType = '_sharing-service._tcp';
  static const int _servicePort = 48230;

  static BonsoirBroadcast? _broadcaster;
  static BonsoirService? _currentBroadcastService;

  static final BonsoirDiscovery _discovery = BonsoirDiscovery(type: _serviceType);

  static final StreamController<BonsoirService> _resolvedServiceController =
      StreamController<BonsoirService>.broadcast();

  static Stream<BonsoirService> get resolvedServiceStream =>
      _resolvedServiceController.stream;

  static bool _isBroadcasting = false;
  static bool _isDiscovering = false;

  static bool get isBroadcasting => _isBroadcasting;

  static Future<void> beginBroadcast(SharedFileInfo fileInfo) async {
    if (_isBroadcasting) {
      await stopBroadcast();
    }

    _currentBroadcastService = BonsoirService(
      name: 'SharingService_${Platform.localHostname}',
      type: _serviceType,
      port: _servicePort,
      attributes: fileInfo.toAttributes(),
    );

    _broadcaster = BonsoirBroadcast(service: _currentBroadcastService!);

    await _broadcaster!.ready;
    await _broadcaster!.start();
    _isBroadcasting = true;

    print('Broadcasting started with file: ${fileInfo.name}');
  }

  static Future<void> stopBroadcast() async {
    if (_broadcaster != null) {
      await _broadcaster!.stop();
      _broadcaster = null;
      _currentBroadcastService = null;
      _isBroadcasting = false;
      print('Broadcasting stopped.');
    }
  }

  static Future<void> beginDiscovery() async {
    if (_isDiscovering) {
      print("Discovery already in progress.");
      return;
    }

    await _discovery.ready;

    _discovery.eventStream?.listen(
      (event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          print('Service found: ${event.service?.toJson()}');
          event.service?.resolve(_discovery.serviceResolver);
        } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
          final resolvedService = event.service!;
          _resolvedServiceController.sink.add(resolvedService);

          print('Service resolved: ${resolvedService.toJson()}');

          final host = resolvedService.toJson()['host'];
          if (host != null) {
            _printIPAddress(host);
          }
        } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
          print('Service lost: ${event.service?.toJson()}');
        }
      },
      onError: (e) => print("Error in discovery stream: $e"),
    );

    await _discovery.start();
    _isDiscovering = true;
    print("Discovery started.");
  }

  static Future<void> stopDiscovery() async {
    if (_isDiscovering) {
      await _discovery.stop();
      _isDiscovering = false;
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

  static void _printIPAddress(String host) {
    try {
      final address = InternetAddress(host);
      print('Parsed IP: ${address.address}');
    } on FormatException {
      print('Attempting DNS lookup for host: $host');
      InternetAddress.lookup(host).then((addresses) {
        if (addresses.isNotEmpty) {
          print('Resolved IP: ${addresses.first.address}');
        } else {
          print('Could not resolve IP for: $host');
        }
      }).catchError((e) {
        print('DNS lookup error: $e');
      });
    }
  }
}
