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

  bool resolving = false;
  String? selectedService;
  final Map<String, BonsoirService> services = {};
  final dialog = await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (_, setState) {
          stream.listen((event) {
            print("event debug: ${event.type}");
            final sessionId = event.service?.attributes["sessionId"];

            switch (event.type) {
              case BonsoirDiscoveryEventType.discoveryServiceFound:
                if (event.service != null) {
                  setState(() {
                    if (sessionId != null) {
                      services[sessionId] = event.service!;
                    }
                  });
                }
                break;
              case BonsoirDiscoveryEventType.discoveryServiceLost:
                if (event.service != null) {
                  setState(() {
                    services.remove(sessionId);
                  });
                }
                break;
              case BonsoirDiscoveryEventType.discoveryServiceResolved:
                if (event.service != null) {
                  setState(() {
                    if (sessionId != null) {
                      services[sessionId] = event.service!;
                    }
                    selectedService = sessionId;

                    if (context.mounted && Navigator.canPop(context)) {
                      Navigator.pop(context, event.service!);
                    }
                  });
                }
              default:
            }
          });

          final servicesKeys = services.keys.toList();
          return AlertDialog(
            actions: [
              TextButton(
                onPressed: () async {
                  if (selectedService == null) {
                    Navigator.pop(context);
                    return;
                  }

                  await SharingDiscoveryService.resolveService(
                    services[selectedService]!,
                  );
                  setState(() {
                    resolving = true;
                  });
                },
                child: Text('Confirm'),
              ),
            ],
            title: const Text('Select Receiver'),
            insetPadding: EdgeInsets.fromLTRB(25, 125, 25, 125),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  resolving
                      ? const SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(),
                      )
                      : ListView.separated(
                        separatorBuilder: (_, _) => const Divider(),
                        itemCount: servicesKeys.length,
                        itemBuilder:
                            (context, index) => ListTile(
                              title: Text(services[servicesKeys[index]]!.name),
                              onTap: () {
                                setState(() {
                                  selectedService = servicesKeys[index];
                                });
                              },
                              selected: selectedService == servicesKeys[index],
                            ),
                      ),
            ),
          );
        },
      );
    },
  );

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
