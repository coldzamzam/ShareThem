import 'package:flutter/material.dart';
import '../utils/sharing_discovery_service.dart'; // Adjust path
import 'package:bonsoir/bonsoir.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async'; // For StreamSubscription
// import 'dart:math'; // You would need this if you use the improved _formatBytes with pow()

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final Map<String, BonsoirService> _discoveredServices = {};
  StreamSubscription<BonsoirService>? _serviceSubscription;
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndStartDiscovery();
  }

  Future<void> _requestPermissionsAndStartDiscovery() async {
    bool permissionsGranted = await _requestPermissions();
    if (permissionsGranted) {
      _listenToServices();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions required to discover services. Please grant them in settings.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _listenToServices() {
    _serviceSubscription?.cancel();
    _serviceSubscription = SharingDiscoveryService.resolvedServiceStream.listen(
      (service) {
        if (mounted) {
          setState(() {
            _discoveredServices[service.name] = service;
          });
        }
      },
      onError: (error) {
        print("Error in service stream: $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Discovery stream error: $error")),
          );
        }
      },
      onDone: () {
        print("Service stream closed.");
      },
      cancelOnError: false,
    );
  }

  Future<bool> _requestPermissions() async {
    var statusLocation = await Permission.location.request();
    bool locationGranted = statusLocation.isGranted;

    if (!locationGranted) {
      print('Location permission status: $statusLocation');
      if (statusLocation.isPermanentlyDenied) {
        if (mounted) _showPermissionPermanentlyDeniedDialog("Location");
      }
    }

    bool nearbyGranted = true;
    if (Theme.of(context).platform == TargetPlatform.android) {
      var statusNearbyWifi = await Permission.nearbyWifiDevices.request();
      nearbyGranted = statusNearbyWifi.isGranted;
      if (!nearbyGranted) {
        print('Nearby Wifi Devices permission status: $statusNearbyWifi');
        if (statusNearbyWifi.isPermanentlyDenied) {
          if (mounted) _showPermissionPermanentlyDeniedDialog("Nearby Devices");
        }
      }
    }
    return locationGranted && nearbyGranted;
  }

  void _showPermissionPermanentlyDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
            'This app needs $permissionName permission to discover devices. Please enable it in app settings.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDiscovery() async {
    if (_isDiscovering) {
      await SharingDiscoveryService.stopDiscovery();
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discovery stopped.'), duration: Duration(seconds: 2)),
        );
      }
    } else {
      if(_serviceSubscription == null || _serviceSubscription!.isPaused) {
        _listenToServices();
      }
      await SharingDiscoveryService.beginDiscovery();
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting discovery...'), duration: Duration(seconds: 2)),
        );
      }
    }
    if(mounted){
      setState(() {
        _isDiscovering = !_isDiscovering;
      });
    }
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    if (_isDiscovering) {
      SharingDiscoveryService.stopDiscovery();
    }
    super.dispose();
  }

  // Your original _formatBytes. It's syntactically valid,
  // though the math for units larger than KB could be improved later.
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes == 0) ? 0 : ( (bytes.toString().length - 1) / 3 ).floor();
    if (i >= suffixes.length) i = suffixes.length - 1;
    return '${(bytes / (1024 * (i > 0 ? i : 1) ) ).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    List<BonsoirService> currentServices = _discoveredServices.values.toList();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isDiscovering ? Icons.radar : Icons.search_off,
                size: 100,
                color: _isDiscovering ? Theme.of(context).primaryColor : Colors.grey[400],
              ),
              const SizedBox(height: 20),
              const Text(
                'Discover Senders',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _toggleDiscovery,
                icon: Icon(_isDiscovering ? Icons.stop_circle_outlined : Icons.search),
                label: Text(
                  _isDiscovering ? 'Stop Discovery' : 'Start Discovery',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDiscovering ? Colors.redAccent : Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Available Devices & Files:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: currentServices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.devices_other_outlined, size: 50, color: Colors.grey),
                            const SizedBox(height: 10),
                            Text(_isDiscovering ? 'Searching for devices...' : 'No devices found. Start discovery.', textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: currentServices.length,
                        itemBuilder: (context, index) {
                          final service = currentServices[index];
                          final fileInfo = SharedFileInfo.fromAttributes(service.attributes);

                          final Map<String, dynamic> serviceJson = service.toJson();
                          final String? discoveredHost = serviceJson['host'] as String?;
                          final String? discoveredIp = serviceJson['ip'] as String?;
                          
                          String displayAddress = discoveredIp ?? discoveredHost ?? "N/A";

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            elevation: 2,
                            child: ListTile(
                              leading: const Icon(Icons.radar, size: 40),
                              title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Address: $displayAddress, Port: ${service.port}'),
                                  if (fileInfo != null)
                                    Text('File: ${fileInfo.name} (${_formatBytes(fileInfo.size, 2)})', style: TextStyle(color: Theme.of(context).primaryColorDark))
                                  else
                                    const Text('File: (No file info)', style: TextStyle(fontStyle: FontStyle.italic)),
                                  Text('Type: ${service.type}'),
                                ],
                              ),
                              isThreeLine: fileInfo != null || (discoveredHost != null && discoveredIp != null && discoveredHost != discoveredIp),
                              onTap: () {
                                print('Tapped on: ${service.name} - Address: $displayAddress - Attributes: ${service.attributes}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Selected ${service.name} - File: ${fileInfo?.name ?? "N/A"}')),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}