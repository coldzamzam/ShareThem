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
                    selectedService = sessionId; // Tandai sebagai terpilih
                    if (dialogContext.mounted && Navigator.canPop(dialogContext)) { // Gunakan dialogContext
                      Navigator.pop(dialogContext, event.service!); // Pop dengan service yang di-resolve
                    }
                  });
                }
                break;
              default:
            }
          });

          final servicesKeys = services.keys.toList();
          return AlertDialog(
            backgroundColor: const Color(0xFFF9F5FF), // Warna background dialog (backgroundStart)
            shape: RoundedRectangleBorder( // Sudut dialog membulat
              borderRadius: BorderRadius.circular(20.0),
            ),
            surfaceTintColor: Colors.transparent, // Menghilangkan overlay warna default
            title: const Text(
              'Select Receiver',
              textAlign: TextAlign.center, // Judul di tengah
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF554DDE), // Warna judul dari primaryDark
              ),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0), // Padding judul
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80), // Padding dialog dari tepi layar
            contentPadding: const EdgeInsets.all(16), // Padding konten
            content: SizedBox(
              width: double.maxFinite,
              child:
                  resolving
                      ? const Center( // Wrap CircularProgressIndicator dengan Center
                          child: SizedBox(
                            width: 80, // Ukuran indicator
                            height: 80,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF554DDE)), // Warna dari primaryDark
                              strokeWidth: 6, // Ketebalan
                            ),
                          ),
                        )
                      : servicesKeys.isEmpty
                          ? Center(
                              child: Text(
                                'No devices found. Make sure other devices can be detected.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView.separated(
                              separatorBuilder: (_, __) => Divider(
                                color: Colors.grey[300], // Warna divider yang lebih halus
                                thickness: 1,
                                height: 20, // Tinggi divider
                              ),
                              itemCount: servicesKeys.length,
                              itemBuilder:
                                  (context, index) {
                                    final BonsoirService service = services[servicesKeys[index]]!;
                                    return Container( // Membungkus ListTile untuk styling selected
                                      decoration: BoxDecoration(
                                        color: selectedService == servicesKeys[index]
                                            ? const Color(0xFFAA88CC).withOpacity(0.1) // Background saat selected (primaryLight opacity)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10), // Sudut membulat saat selected
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: const Icon(Icons.devices, color: Color(0xFFAA88CC), size: 30), // Ikon device (primaryLight)
                                        title: Text(
                                          service.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 18,
                                            color: selectedService == servicesKeys[index] ? const Color(0xFF554DDE) : Colors.grey[800], // Warna teks berdasarkan selection (primaryDark)
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          service.attributes['deviceType'] ?? 'Unknown Device', // Contoh subtitle
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            selectedService = servicesKeys[index];
                                          });
                                        },
                                        // selected: selectedService == servicesKeys[index], // Sudah di handle dengan Container.decoration
                                      ),
                                    );
                                  },
                            ),
            ),
            // Bagian ini DIPINDAHKAN ke dalam 'actions'
            actions: [ // <-- Pastikan ini adalah properti 'actions' dari AlertDialog
              Padding( // <-- Padding ini membungkus Row
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), // Padding tombol
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // Gunakan dialogContext
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFAA88CC), // Warna teks dari primaryLight
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: selectedService == null
                          ? null // Tombol dinonaktifkan jika belum ada yang dipilih
                          : () async {
                              setState(() {
                                resolving = true; // Tampilkan loading
                              });
                              // Pastikan service tidak null sebelum di-resolve
                              if (services.containsKey(selectedService)) {
                                await SharingDiscoveryService.resolveService(
                                  services[selectedService]!,
                                );
                                // Pop akan dilakukan di listener BonsoirDiscoveryEventType.discoveryServiceResolved
                              } else {
                                // Jika selectedService tidak ditemukan (mungkin hilang), pop saja
                                if (dialogContext.mounted && Navigator.canPop(dialogContext)) {
                                  Navigator.pop(dialogContext);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF554DDE), // Warna tombol Confirm dari primaryDark
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10), // Sudut tombol membulat
                        ),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        elevation: 5,
                        shadowColor: const Color(0xFF554DDE).withOpacity(0.3), // Shadow dari primaryDark
                      ),
                      child: resolving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            ], // <-- Akhir dari properti 'actions'
          );
        },
      );
    },
  );

  return dialog;
}

// Class ini tampaknya tidak terpakai dalam struktur showSelectReceiverDialog yang baru,
// namun saya akan tetap menyertakan gaya dasarnya jika sewaktu-waktu digunakan di tempat lain.
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
        case BonsoirDiscoveryEventType.discoveryServiceResolved:
        // Logika resolve biasanya ditangani di showDialog parent
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
              ListTile(
                leading: const Icon(Icons.devices, color: Color(0xFFAA88CC)), // primaryLight
                title: Text(
                  _services[index].name, // Mengambil nama service
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF333333),
                  ),
                ),
                subtitle: Text(
                  _services[index].attributes.toString(), // Menampilkan atribut sebagai subtitle
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
    );
  }
}