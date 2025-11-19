// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:trabcdefg/screens/device_list_screen.dart';
import 'package:trabcdefg/screens/map_screen.dart';
import 'package:trabcdefg/screens/reports/reports_screen.dart'; // Import the new ReportsScreen
import 'package:trabcdefg/screens/settings/settings_screen.dart';
import 'package:get/get.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    DeviceListScreen(),
    MapScreen(),
    ReportsScreen(), // Add the new Report screen
    SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // To show more than 3 items
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'deviceTitle'.tr),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'mapTitle'.tr),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'reportTitle'.tr),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'settingsTitle'.tr),
        ],
      ),
    );
  }
}