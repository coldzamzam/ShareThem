import 'package:flutter/material.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_sharing/file_sharing_receiver.dart';
import 'package:flutter_shareit/utils/file_utils.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart'; // Adjust path

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _discoverable = SharingDiscoveryService.isDiscoverable;
  List<SharedFile> _sharedFiles = [];
  bool _receivingBegun = false;
  late FileSharingReceiver _receiver;

  @override
  void initState() {
    super.initState();

    _receiver = FileSharingReceiver(
      onFileProgress: (files) {
        if (_discoverable) {
          setState(() {
            _discoverable = false;
          });
          SharingDiscoveryService.stopBroadcast();
        }

        setState(() {
          _receivingBegun = true;
          _sharedFiles = files;
        });
      },
    );
  }

  @override
  void dispose() {
    SharingDiscoveryService.stopBroadcast();
    _receiver.stop();
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
                child: _discoverable
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
              Expanded(
                child: Card(
                  elevation: 2,
                  child: ListView.builder(
                    itemCount: _sharedFiles.length,
                    itemBuilder: (_, i) {
                      return ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(
                          _sharedFiles[i].fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Size: ${fileSizeToHuman(_sharedFiles[i].fileSize)}',
                        ),
                        trailing: Text("0%"),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _receivingBegun
                    ? null
                    : () async {
                        if (_discoverable) {
                          setState(() {
                            _discoverable = false;
                          });
                          await SharingDiscoveryService.stopBroadcast();
                          await _receiver.stop();
                          return;
                        }

                        await _receiver.start();
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
                  backgroundColor: _discoverable
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: _discoverable
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
