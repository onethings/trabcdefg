// lib/screens/splash_screen.dart
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await AuthSessionStore.instance.load();
    final jSessionId = AuthSessionStore.instance.sessionId;

    if (!mounted) return;

    if (jSessionId == null || jSessionId.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    final traccarProvider = context.read<TraccarProvider>();
    if (traccarProvider.sessionId != jSessionId) {
      traccarProvider.setSessionId(jSessionId);
    }

    try {
      await traccarProvider.fetchInitialData().timeout(const Duration(seconds: 10));

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      debugPrint('Splash session check failed: $e');
      if (!mounted) return;

      if (AuthSessionStore.instance.sessionId == null) {
        Get.snackbar(
          'Error'.tr,
          'Your session has expired. Please log in again.'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      setState(() {
        _errorMessage = 'Could not connect to server. Please check your network and try again.';
      });
    }
  }

  void _retry() {
    setState(() => _errorMessage = null);
    _checkLoginStatus();
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
            if (_errorMessage == null)
              const CircularProgressIndicator()
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_errorMessage!.tr, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _retry, child: Text('retry'.tr)),
            ],
          ],
        ),
      ),
    );
  }
}