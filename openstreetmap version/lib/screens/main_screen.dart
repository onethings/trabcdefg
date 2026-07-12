// lib/screens/main_screen.dart
// The main screen with bottom navigation to different sections: Device List, Map, Reports, and Settings.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/screens/device_list_screen.dart';
import 'package:trabcdefg/screens/home/dashboard_screen.dart';
import 'package:trabcdefg/screens/map_screen.dart';
import 'package:trabcdefg/screens/reports/reports_screen.dart';
import 'package:trabcdefg/screens/settings/settings_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final List<Widget> _screens = const [DashboardScreen(), DeviceListScreen(), MapScreen(), ReportsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLastTab();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validateSessionOnResume();
    }
  }

  /// Validates the server session when the app resumes from background.
  ///
  /// If the JSESSIONID has expired (e.g. after a week), attempts auto-relogin
  /// with saved credentials. On success, re-fetches all data. On failure,
  /// redirects to the login screen.
  Future<void> _validateSessionOnResume() async {
    if (!mounted) return;

    final traccarProvider = context.read<TraccarProvider>();
    final authService = context.read<AuthService>();

    // Quick check: if there's no session ID stored, go to login
    final prefs = await SharedPreferences.getInstance();
    final savedSessionId = prefs.getString('jSessionId');
    if (savedSessionId == null) {
      if (mounted) Get.offAllNamed('/login');
      return;
    }

    try {
      // Validate the session by calling GET /session
      traccarProvider.apiClient.addDefaultHeader('Cookie', 'JSESSIONID=$savedSessionId');
      final sessionApi = api.SessionApi(traccarProvider.apiClient);
      await sessionApi.getSession().timeout(const Duration(seconds: 10));

      // Session is still valid — ensure WebSocket is connected with this session
      if (traccarProvider.sessionId != savedSessionId) {
        traccarProvider.setSessionId(savedSessionId);
      }
      debugPrint('Session validated on resume — still active.');
    } catch (e) {
      debugPrint('Session validation failed on resume: $e');

      // Try auto-relogin with saved credentials
      final reloginOk = await authService.tryAutoRelogin();
      if (reloginOk && mounted) {
        final freshSessionId = prefs.getString('jSessionId');
        if (freshSessionId != null) {
          traccarProvider.setSessionId(freshSessionId);
          try {
            await traccarProvider.fetchInitialData().timeout(const Duration(seconds: 15));
            debugPrint('Data re-fetched after auto-relogin on resume.');
            return;
          } catch (fetchError) {
            debugPrint('Data re-fetch after auto-relogin failed: $fetchError');
          }
        }
      }

      // Auto-relogin failed — redirect to login
      if (mounted) {
        debugPrint('Session expired and auto-relogin failed. Redirecting to login.');
        Get.offAllNamed('/login');
      }
    }
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
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5),
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.dashboard_rounded), label: 'dashboardTitle'.tr),
              BottomNavigationBarItem(icon: const Icon(Icons.list_rounded), label: 'deviceTitle'.tr),
              BottomNavigationBarItem(icon: const Icon(Icons.map_rounded), label: 'mapTitle'.tr),
              BottomNavigationBarItem(icon: const Icon(Icons.description_rounded), label: 'reportTitle'.tr),
              BottomNavigationBarItem(icon: const Icon(Icons.settings_rounded), label: 'settingsTitle'.tr),
            ],
          ),
        ),
      ),
    );
  }
}
