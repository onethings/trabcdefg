// lib/screens/main_screen.dart
// The main screen with bottom navigation to different sections: Device List, Map, Reports, and Settings.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/auth_session_store.dart';
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
  // 新增一個變數用來追蹤是否已載入完成上次的 tab，避免畫面閃爍
  bool _isInitialized = false;
  // 伺服器健康檢查：定期確認伺服器是否還在，並讓 401 的處理集中在一處。
  // 連線失敗或逾時只提示，不會把仍有效的登入狀態丟掉。
  Timer? _serverHealthTimer;
  int _serverFailCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLastTab().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
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
      // Restart the health check with a clean counter: requests that failed
      // while the app was backgrounded must not count towards a logout.
      _serverFailCount = 0;
      _startServerHealthCheck();
      _validateSessionOnResume();
    } else {
      // Pings fired while suspended/without network only produce false
      // failures (and used to send the user to the login screen).
      _serverHealthTimer?.cancel();
    }
  }

  /// Validates the server session when the app resumes from background.
  ///
  /// A 401 is handled by the API client: it attempts one silent re-login with
  /// the credentials still held in memory, retries the request, and clears the
  /// session + redirects to login if that fails.
  Future<void> _validateSessionOnResume() async {
    if (!mounted) return;

    final traccarProvider = context.read<TraccarProvider>();
    final savedSessionId = AuthSessionStore.instance.sessionId;

    // Quick check: if there's no session ID stored, go to login
    if (savedSessionId == null) {
      if (mounted) Get.offAllNamed('/login');
      return;
    }

    if (traccarProvider.sessionId != savedSessionId) {
      traccarProvider.setSessionId(savedSessionId);
    }

    try {
      // Validate the session by calling GET /session. The interceptor injects
      // the current cookie and handles expiry/retry.
      final sessionApi = api.SessionApi(traccarProvider.apiClient);
      await sessionApi.getSession().timeout(const Duration(seconds: 10));
      debugPrint('Session validated on resume — still active.');
    } catch (e) {
      // A 401 already triggered the interceptor (re-login or redirect).
      // Network/server errors should not discard a possibly valid session;
      // the periodic health check handles outages.
      debugPrint('Session validation failed on resume: $e');
    }
  }

  /// 每 20 秒輕量 ping 一次伺服器（GET /session）。
  ///
  /// 只有伺服器明確回 401 才代表 session 失效。連線失敗、逾時或 5xx 都只是
  /// 暫時性問題，不能因此把使用者送到登入頁（session 其實還有效）。
  /// 401 的靜默重登與導向由 AuthInterceptingClient 統一處理，這裡只做安全網。
  void _startServerHealthCheck() {
    _serverHealthTimer?.cancel();
    _serverHealthTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkServerHealth());
  }

  Future<void> _checkServerHealth() async {
    if (!mounted) return;
    final traccarProvider = context.read<TraccarProvider>();
    try {
      // 10s，讓行動網路喚醒/DNS 重連有足夠時間完成，避免誤判斷線。
      await api.SessionApi(traccarProvider.apiClient).getSession().timeout(const Duration(seconds: 10));
      _serverFailCount = 0; // 伺服器正常
      return;
    } catch (e) {
      final isAuthFailure = e is api.ApiException && e.code == 401;
      if (!isAuthFailure) {
        _serverFailCount++;
        debugPrint('Server unreachable (health check $_serverFailCount): $e');
        if (_serverFailCount == 2 && mounted) {
          Get.snackbar('Error'.tr, 'Connection to server lost. Please check your network.'.tr, snackPosition: SnackPosition.BOTTOM);
        }
        return;
      }

      // 401：攔截器已嘗試靜默重登；只有 session 真的被清掉（重登也失敗）
      // 才需要導向登入頁，而且不要重複導航。
      if (AuthSessionStore.instance.sessionId != null) return;
      _serverHealthTimer?.cancel();
      if (mounted && Get.currentRoute != '/login') {
        Get.snackbar('Error'.tr, 'Your session has expired. Please log in again.'.tr, snackPosition: SnackPosition.BOTTOM);
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
