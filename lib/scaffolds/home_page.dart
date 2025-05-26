import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_shareit/screens/receive_screen.dart';
import 'package:flutter_shareit/screens/send_screen.dart';
import 'package:flutter_shareit/screens/settings_screen.dart';

// The main screen of the application, featuring a Scaffold with responsive navigation.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _lockingIndex = 0;
  int _selectedIndex = 0; // Keeps track of the currently selected navigation item.

  // Define the navigation destinations for both NavigationRail and BottomNavigationBar.
  static final List<NavigationDestination> _destinations =
      <NavigationDestination>[
        NavigationDestination(
          selectedIcon: Icon(Icons.upload, color: Colors.lightBlue),
          icon: Icon(Icons.upload_outlined, color: Colors.lightBlueAccent),
          label: 'Send',
        ),
        NavigationDestination(
          selectedIcon: Icon(Icons.download, color: Colors.orange),
          icon: Icon(Icons.download_outlined, color: Colors.orangeAccent),
          label: 'Receive',
        ),
      ];

  // Function to update the selected index.
  void _onNavigation(int index) {
    setState(() {
      if (index < _destinations.length) {
        _lockingIndex = index;
      }
      _selectedIndex = index;
    });
  }

  void _openSettings() {
    setState(() {
      _selectedIndex = _destinations.length;
    });
  }

  void _closeSettings() {
    setState(() {
      _selectedIndex = _lockingIndex;
    });
  }

  @override
  void dispose() {
    print("HomePage disposed");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 1000.0;
    final List<Widget> widgets = <Widget>[
      SendScreen(),
      ReceiveScreen(),
      SettingsScreen(onClose: isWideScreen ? null : _closeSettings),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          'ShareThem',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            color: Theme.of(context).colorScheme.onPrimary,
            onPressed: _openSettings,
          ),
        ],
        // No leading icon needed for NavigationRail as it's always visible.
      ),
      body: Row(
        children: [
          // Conditionally render the NavigationRail for wide screens.
          if (isWideScreen)
            NavigationDrawer(
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onNavigation,
              children: [
                Padding(padding: EdgeInsets.only(top: 10)),
                ...(_destinations.mapIndexed(
                  (i, e) => NavigationDrawerDestination(
                    icon: e.icon,
                    selectedIcon: e.selectedIcon,
                    label: Text(e.label),
                    enabled: e.enabled,
                  ),
                )),
                Padding(padding: EdgeInsets.only(bottom: 10)),
              ],
            ),

          if (isWideScreen) const VerticalDivider(thickness: 1, width: 1),

          // The main content of the screen, taking up the remaining space.
          Expanded(child: widgets[_selectedIndex]),
        ],
      ),
      // Conditionally render the BottomNavigationBar for narrow screens.
      bottomNavigationBar:
          (isWideScreen || _selectedIndex >= _destinations.length)
              ? null // No bottom navigation bar if it's a wide screen (using NavigationRail).
              : NavigationBarTheme(
                data: const NavigationBarThemeData(
                  indicatorColor: Colors.white,
                ),
                child: NavigationBar(
                  animationDuration: const Duration(seconds: 1),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onNavigation,
                  destinations: _destinations,
                ),
              ),
    );
  }
}
