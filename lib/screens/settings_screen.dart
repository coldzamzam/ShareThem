import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback? onClose;
  const SettingsScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 15, 0, 15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            spacing: 25,
            children: [
              Text(
                "Settings",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              CircleAvatar(
                maxRadius: 75,
                child: const Icon(Icons.person, size: 100),
              ),
              ElevatedButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login'), child: const Text("Login"))
            ],
          ),
          if (onClose != null)
            ElevatedButton(onPressed: onClose, child: const Text("Close")),
        ],
      ),
    );
  }
}
