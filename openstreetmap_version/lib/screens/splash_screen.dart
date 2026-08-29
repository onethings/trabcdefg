// lib/screens/splash_screen.dart
// This screen handles checking the stored session ID and routing the user to either the main app or the login screen.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// 🔥 每次打開 app 都用存的帳密重新登入（POST /session）拿「全新」token，
  /// 不信任舊 session。只有自動登入成功才進主頁；伺服器當機/帳密無效都擋在登入頁。
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    final password = prefs.getString('saved_password');

    if (!mounted) return;

    // 沒有存帳密 → 登入頁
    if (email == null || password == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    final traccarProvider = context.read<TraccarProvider>();
    final authService = context.read<AuthService>();
    try {
      // 每次啟動都重新登入，取得全新 session token
      await authService.login(email, password);

      final jSessionId = prefs.getString('jSessionId');
      if (jSessionId != null) {
        traccarProvider.setSessionId(jSessionId);
      }

      await traccarProvider.fetchInitialData().timeout(const Duration(seconds: 10));

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    } on LoginException catch (e) {
      // 帳密無效（401/400）→ 清除存的憑證，避免每次啟動都失敗
      debugPrint('Splash auto-login rejected: $e');
      await authService.logout();
      if (mounted) {
        Get.snackbar('Error'.tr, 'loginFailed'.tr, snackPosition: SnackPosition.BOTTOM);
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      // 🛑 伺服器當機 / 網路錯誤 → 保留憑證供下次自動重試，但先進登入頁，
      // 不讓使用者進入 Devices/Map/Settings。
      debugPrint('Splash auto-login failed (server unreachable?): $e');
      if (mounted) {
        Get.snackbar('Error'.tr, 'Could not connect to server. Please check your network and try again.'.tr, snackPosition: SnackPosition.BOTTOM);
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/appstore.png', width: 180, height: 180, fit: BoxFit.contain),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
