// lib/screens/main_screen.dart
// The main screen with bottom navigation to different sections: Device List, Map, Reports, and Settings.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/screens/device_list_screen.dart';
import 'package:trabcdefg/screens/map_screen.dart';
import 'package:trabcdefg/screens/settings/settings_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final List<Widget> _screens = const [DeviceListScreen(), MapScreen(), SettingsScreen()];

  // 🛑 伺服器健康檢查：伺服器當機/斷線時，把使用者送回登入頁，
  // 避免在伺服器不可用的狀態下繼續使用 Devices/Map/Settings。
  Timer? _serverHealthTimer;
  int _serverFailCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLastTab();
    _startServerHealthCheck();
  }

  @override
  void dispose() {
    _serverHealthTimer?.cancel();
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

  /// 每 20 秒輕量 ping 一次伺服器（GET /session）。
  /// - 成功：重置失敗計數。
  /// - 401（session 過期）：立即回登入頁。
  /// - 連線失敗（伺服器當機）：連續 2 次失敗才回登入頁，避免短暫斷線就踢人。
  void _startServerHealthCheck() {
    _serverHealthTimer?.cancel();
    _serverHealthTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkServerHealth());
  }

  Future<void> _checkServerHealth() async {
    if (!mounted) return;
    final traccarProvider = context.read<TraccarProvider>();
    try {
      await api.SessionApi(traccarProvider.apiClient).getSession().timeout(const Duration(seconds: 5));
      _serverFailCount = 0; // 伺服器正常
      return;
    } catch (e) {
      final isAuthFailure = e is api.ApiException && e.code == 401;
      if (!isAuthFailure) {
        _serverFailCount++;
        debugPrint('Server unreachable (health check $_serverFailCount/2): $e');
      }
      if (isAuthFailure || _serverFailCount >= 2) {
        _serverHealthTimer?.cancel();
        if (mounted) {
          Get.snackbar('Error'.tr, isAuthFailure ? 'Your session has expired. Please log in again.'.tr : 'Connection to server lost. Please check your network and log in again.'.tr, snackPosition: SnackPosition.BOTTOM);
          Get.offAllNamed('/login');
        }
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
