import 'package:flutter/material.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart'; // Adjust path

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _discoverable = SharingDiscoveryService.isDiscoverable;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    SharingDiscoveryService.stopBroadcast();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Durations.short2,
                child:
                    _discoverable
                        ? const Icon(
                          Icons.wifi_tethering,
                          size: 100,
                          key: ValueKey(1),
                        )
                        : Icon(
                          Icons.wifi_tethering_off,
                          size: 100,
                          color: Colors.grey[400],
                          key: ValueKey(0),
                        ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_discoverable) {
                    setState(() {
                      _discoverable = false;
                    });
                    await SharingDiscoveryService.stopBroadcast();
                    return;
                  }

                  await SharingDiscoveryService.beginBroadcast();
                  setState(() {
                    _discoverable = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor:
                      _discoverable
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.primary,
                  foregroundColor:
                      _discoverable
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(
                  _discoverable ? 'Stop Receiving' : 'Start Receiving',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
