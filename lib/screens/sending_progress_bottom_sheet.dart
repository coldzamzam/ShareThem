import 'package:flutter/material.dart';
import 'package:flutter_shareit/protos/sharethem.pb.dart';
import 'package:flutter_shareit/utils/file_utils.dart';

class SendingProgressData {
  final SharedFile file;
  final int sentBytes;
  final bool isCompleted;

  SendingProgressData({
    required this.file,
    required this.sentBytes,
    this.isCompleted = false,
  });
}

class SendingProgressBottomSheet extends StatefulWidget {
  final ValueNotifier<List<SendingProgressData>> progressNotifier;

  const SendingProgressBottomSheet({
    super.key,
    required this.progressNotifier,
  });

  @override
  State<SendingProgressBottomSheet> createState() => _SendingProgressBottomSheetState();
}

class _SendingProgressBottomSheetState extends State<SendingProgressBottomSheet> {
  @override
  void initState() {
    super.initState();
    widget.progressNotifier.addListener(_onProgressChanged);
  }

  void _onProgressChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.progressNotifier.removeListener(_onProgressChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Sending Files...",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Divider(),
            Expanded(
              child: widget.progressNotifier.value.isEmpty
                  ? const Center(child: Text("Waiting to send files..."))
                  : ListView.builder(
                      itemCount: widget.progressNotifier.value.length,
                      itemBuilder: (context, index) {
                        final data = widget.progressNotifier.value[index];
                        final progress = (data.file.fileSize == 0)
                            ? 0.0
                            : (data.sentBytes / data.file.fileSize);
                        final isCompleted = data.isCompleted;

                        Widget trailingWidget;
                        if (isCompleted) {
                          trailingWidget = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Sent ", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                            ],
                          );
                        } else {
                          trailingWidget = SizedBox(
                            width: 80,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[300],
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                Text("${(progress * 100).toStringAsFixed(0)}%"),
                              ],
                            ),
                          );
                        }

                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(data.file.fileName),
                          subtitle: Text('Size: ${fileSizeToHuman(data.file.fileSize)}'),
                          trailing: trailingWidget,
                        );
                      },
                    ),
            ),
            if (widget.progressNotifier.value.isNotEmpty && widget.progressNotifier.value.every((data) => data.isCompleted))
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}