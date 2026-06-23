// lib/screens/splash_screen.dart
// This screen handles checking the stored session ID and routing the user to either the main app or the login screen.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

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

    if (!mounted) return;

    if (jSessionId != null) {
      final traccarProvider = context.read<TraccarProvider>();
      try {
        traccarProvider.setSessionId(jSessionId);
        await traccarProvider.fetchInitialData().timeout(const Duration(seconds: 10));

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } catch (e) {
        if (!mounted) return;
        debugPrint('Splash screen fetch error: $e');

        // Session expired (401) — try auto-relogin with saved credentials
        if (e is api.ApiException && e.code == 401) {
          debugPrint('Session expired. Attempting auto-relogin...');

          final authService = context.read<AuthService>();
          final reloginOk = await authService.tryAutoRelogin();

          if (reloginOk) {
            // Relogin succeeded — we have a fresh session. Retry data fetch.
            final freshSessionId = prefs.getString('jSessionId');
            if (freshSessionId != null) {
              traccarProvider.setSessionId(freshSessionId);
              try {
                await traccarProvider.fetchInitialData().timeout(const Duration(seconds: 10));
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/main');
                  return;
                }
              } catch (retryError) {
                debugPrint('Retry after auto-relogin also failed: $retryError');
              }
            }
          }
        }

        // Auto-relogin failed or it wasn't a 401 — go to login or main
        if (e is api.ApiException && e.code == 401) {
          // Auth error and auto-relogin failed → login screen
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        } else {
          // Network or other error → still try the main screen
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/main');
          }
        }
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
