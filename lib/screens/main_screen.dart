// lib/screens/main_screen.dart
// The main screen with bottom navigation to different sections: Device List, Map, and Settings.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/device_list_screen.dart';
import 'package:trabcdefg/screens/map_screen.dart';
import 'package:trabcdefg/screens/settings/settings_screen.dart';
import 'package:trabcdefg/services/map_navigation.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _screens = const [DeviceListScreen(), MapScreen(), SettingsScreen()];

  CupertinoTabController? _tabController;
  MapNavigation? _mapNavigation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadLastTab();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TraccarProvider>().startServerHealthCheck();
      _mapNavigation = context.read<MapNavigation>()..addListener(_onMapFocusRequested);
      _onMapFocusRequested();
    });
  }

  @override
  void dispose() {
    _mapNavigation?.removeListener(_onMapFocusRequested);
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final int? lastTab = prefs.getInt('last_main_tab_index');
    final int initialIndex = lastTab != null && lastTab >= 0 && lastTab < _screens.length ? lastTab : 0;
    if (!mounted) return;
    setState(() {
      _tabController = CupertinoTabController(initialIndex: initialIndex);
      _isInitialized = true;
    });
  }

  void _onMapFocusRequested() {
    if (_mapNavigation?.pendingDeviceId != null) {
      _tabController?.index = 1;
    }
  }

  void _onTabTapped(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_main_tab_index', index);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        onTap: _onTabTapped,
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        items: [
          BottomNavigationBarItem(icon: const Icon(CupertinoIcons.list_bullet), label: 'deviceTitle'.tr),
          BottomNavigationBarItem(icon: const Icon(CupertinoIcons.map), label: 'mapTitle'.tr),
          BottomNavigationBarItem(icon: const Icon(CupertinoIcons.settings), label: 'settingsTitle'.tr),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(builder: (context) => _screens[index]);
      },
    );
  }
}
