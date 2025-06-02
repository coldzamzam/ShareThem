import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_shareit/utils/sharing_discovery_service.dart';

Future<dynamic> showSelectReceiverDialog({
  required BuildContext context,
}) async {
  final stream = await SharingDiscoveryService.beginDiscovery();
  if (stream == null || !context.mounted) {
    return null;
  }

  BonsoirService? selectedService;
  final List<BonsoirService> services = [];
  final dialog = await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        actions: [
          TextButton(
            onPressed: () {
              if (selectedService == null) {
                showDialog(
                  context: context,
                  builder:
                      (dialogContext) => AlertDialog(
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Dismiss'),
                          ),
                        ],
                        title: const Text('Error'),
                        content: const Text('Select a receiver first!'),
                      ),
                );
                return;
              }
            },
            child: Text('Confirm'),
          ),
        ],
        title: const Text('Select Receiver'),
        insetPadding: EdgeInsets.fromLTRB(25, 125, 25, 125),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setState) {
              stream.listen((event) {
                print("event debug: ${event.type}");
                switch (event.type) {
                  case BonsoirDiscoveryEventType.discoveryServiceFound:
                    if (event.service != null) {
                      setState(() {
                        services.add(event.service!);
                      });
                    }
                    break;
                  case BonsoirDiscoveryEventType.discoveryServiceLost:
                    if (event.service != null) {
                      setState(() {
                        services.remove(event.service!);
                      });
                    }
                    break;
                  default:
                }
              });

              return ListView.separated(
                separatorBuilder: (_, _) => const Divider(),
                itemCount: services.length,
                itemBuilder:
                    (context, index) => ListTile(
                      title: Text(services[index].name),
                      onTap: () {
                        setState(() {
                          selectedService = services[index];
                        });
                      },
                      selected: selectedService == services[index],
                    ),
              );
            },
          ),
        ),
      );
    },
  );

  await SharingDiscoveryService.stopDiscovery();

  return dialog;
}

class SelectReceiverDialogContent extends StatefulWidget {
  final Stream<BonsoirDiscoveryEvent> stream;
  const SelectReceiverDialogContent({super.key, required this.stream});

  @override
  State<StatefulWidget> createState() => _SelectReceiverDialogContentState();
}

class _SelectReceiverDialogContentState
    extends State<SelectReceiverDialogContent> {
  final List<BonsoirService> _services = [];

  @override
  void initState() {
    widget.stream.listen((event) {
      print("event debug: ${event.type}");
      switch (event.type) {
        case BonsoirDiscoveryEventType.discoveryServiceFound:
          if (event.service != null) {
            setState(() {
              _services.add(event.service!);
            });
          }
          break;
        case BonsoirDiscoveryEventType.discoveryServiceLost:
          if (event.service != null) {
            setState(() {
              _services.remove(event.service!);
            });
          }
          break;
        default:
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _services.length,
      itemBuilder:
          (context, index) =>
              ListTile(title: Text(_services[index].attributes.toString())),
    );
  }
}
