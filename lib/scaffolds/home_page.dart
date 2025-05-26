import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_shareit/screens/receive_screen.dart';
import 'package:flutter_shareit/screens/send_screen.dart';

// The main screen of the application, featuring a Scaffold with responsive navigation.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex =
      0; // Keeps track of the currently selected navigation item.

  // Define the navigation destinations for both NavigationRail and BottomNavigationBar.
  static const List<NavigationDestination> _destinations =
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

  // List of widgets to display in the body based on the selected index.
  static const List<Widget> _widgets = <Widget>[SendScreen(), ReceiveScreen()];

  // Function to update the selected index.
  void _onNavigation(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 1000.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          'ShareThem',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        actions: [IconButton(icon: Icon(Icons.person), color: Theme.of(context).colorScheme.onPrimary, onPressed: () {})],
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
                    label: Text(e.label),
                  ),
                )),
                Padding(padding: EdgeInsets.only(bottom: 10)),
              ],
            ),

          if (isWideScreen) const VerticalDivider(thickness: 1, width: 1),

          // The main content of the screen, taking up the remaining space.
          Expanded(child: _widgets[_selectedIndex]),
        ],
      ),
      // Conditionally render the BottomNavigationBar for narrow screens.
      bottomNavigationBar:
          isWideScreen
              ? null // No bottom navigation bar if it's a wide screen (using NavigationRail).
              : NavigationBarTheme(
                data: const NavigationBarThemeData(
                  indicatorColor: Colors.white,
                ),
                child: NavigationBar(
                  animationDuration: const Duration(seconds: 1),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: _destinations,
                ),
              ),
    );
  }
}
