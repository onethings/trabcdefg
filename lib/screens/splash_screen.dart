// lib/screens/splash_screen.dart
// This screen handles checking the stored session ID and routing the user to either the main app or the login screen.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/auth_session_store.dart';

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

  /// Resumes the session saved in secure storage. The password is never
  /// persisted, so if the server rejects the session the user must log in
  /// again instead of silently re-authenticating.
  Future<void> _checkLoginStatus() async {
    await AuthSessionStore.instance.load();
    final jSessionId = AuthSessionStore.instance.sessionId;

    if (!mounted) return;

    // No saved session → login page.
    if (jSessionId == null || jSessionId.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    final traccarProvider = context.read<TraccarProvider>();
    traccarProvider.setSessionId(jSessionId);

    try {
      await traccarProvider.fetchInitialData().timeout(const Duration(seconds: 10));

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    } catch (e) {
      // 401 is handled by the API client: it tries one silent re-login, then
      // clears the session and redirects. For network/server failures the
      // session is kept so the next launch can retry.
      debugPrint('Splash session check failed: $e');
      if (mounted) {
        final sessionExpired = AuthSessionStore.instance.sessionId == null;
        Get.snackbar(
          'Error'.tr,
          sessionExpired ? 'Your session has expired. Please log in again.'.tr : 'Could not connect to server. Please check your network and try again.'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
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
            Image.asset('assets/images/logo.png', width: 180, height: 180, fit: BoxFit.contain),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
