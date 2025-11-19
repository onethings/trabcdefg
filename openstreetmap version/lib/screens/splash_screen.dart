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
        // We use fetchInitialData as a way to validate the session
        traccarProvider.setSessionId(jSessionId);
        await traccarProvider.fetchInitialData();
        
        // If fetchInitialData succeeds, the session is valid. Navigate to main screen.
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } catch (e) {
        // Session has expired or is invalid. Navigate to login screen.
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
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