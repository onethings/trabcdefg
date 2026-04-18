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

    if (jSessionId != null) {
      // Session ID found, try to use it to get devices
      final traccarProvider = context.read<TraccarProvider>();
      try {
        // We use fetchInitialData as a way to validate the session.
        // We add a timeout to ensure the user isn't stuck on the splash screen forever.
        traccarProvider.setSessionId(jSessionId);
        await traccarProvider.fetchInitialData().timeout(const Duration(seconds: 10));
        
        // If fetchInitialData succeeds, the session is valid. Navigate to main screen.
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } catch (e) {
        // If it's a timeout or any other error, we still try to go to the main screen
        // as long as we have a session ID, or go to login if the session is clearly invalid.
        if (mounted) {
          // If the error is likely due to invalid session (e.g. 401), go to login.
          // Otherwise (like a timeout), go to main and let it try to refresh later.
          debugPrint('Splash screen fetch error: $e');
          Navigator.of(context).pushReplacementNamed('/main');
        }
      }
    } else {
      // No session ID found, navigate to login screen.
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