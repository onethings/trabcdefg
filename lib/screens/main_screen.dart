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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [DeviceListScreen(), MapScreen(), SettingsScreen()];

  // 用來追蹤是否已載入完成上次的 tab，避免畫面閃爍[cite: 6]
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadLastTab().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });

    // 啟動集中在 TraccarProvider 內的伺服器健康檢查
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TraccarProvider>().startServerHealthCheck();
      }
    });
  }

  @override
  void dispose() {
    // 就不需要在此處手動取消 _serverHealthTimer，已交由 TraccarProvider 統一處置
    super.dispose();
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
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _currentIndex,
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
