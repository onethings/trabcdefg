// lib/screens/splash_screen.dart
// This screen handles checking the stored session ID and routing the user to either the main app or the login screen.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
// import 'package:trabcdefg/services/auth_service.dart';
// import 'package:get/get.dart';

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

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final jSessionId = prefs.getString('jSessionId');

    // ✨ 修正點 1：在 await 之後、使用 context 之前，先檢查 mounted
    if (!mounted) return;

    if (jSessionId != null) {
      // 現在可以安全地使用 context 了
      final traccarProvider = context.read<TraccarProvider>();
      try {
        traccarProvider.setSessionId(jSessionId);
        await traccarProvider.fetchInitialData().timeout(
          const Duration(seconds: 10),
        );

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } catch (e) {
        if (mounted) {
          debugPrint('Splash screen fetch error: $e');
          Navigator.of(context).pushReplacementNamed('/main');
        }
      }
    } else {
      // 這裡本來就有寫，沒問題！
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        // Show a loading indicator while the session status is being checked
        child: CircularProgressIndicator(),
      ),
    );
  }
}
