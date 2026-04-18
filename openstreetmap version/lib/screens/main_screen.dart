// lib/screens/main_screen.dart
// The main screen with bottom navigation to different sections: Device List, Map, Reports, and Settings.
import 'package:flutter/material.dart';
import 'package:trabcdefg/screens/device_list_screen.dart';
import 'package:trabcdefg/screens/map_screen.dart';
import 'package:trabcdefg/screens/reports/reports_screen.dart'; // Import the new ReportsScreen
import 'package:trabcdefg/screens/settings/settings_screen.dart';
import 'package:trabcdefg/screens/home/dashboard_screen.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    DashboardScreen(),
    DeviceListScreen(),
    MapScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadLastTab();
  }

  Future<void> _loadLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTab = prefs.getInt('last_main_tab_index');
    if (lastTab != null && lastTab < _screens.length) {
      if (mounted) {
        setState(() {
          _currentIndex = lastTab;
        });
      }
    }
  }

  void _onTabTapped(int index) async {
    setState(() {
      _currentIndex = index;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_main_tab_index', index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: BottomNavigationBar(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.5)
                : Colors.white.withOpacity(0.5),
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard_rounded),
                label: 'dashboardTitle'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.list_rounded),
                label: 'deviceTitle'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.map_rounded),
                label: 'mapTitle'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.description_rounded),
                label: 'reportTitle'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_rounded),
                label: 'settingsTitle'.tr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
