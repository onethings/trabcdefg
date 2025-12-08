// lib/main.dart
// Main entry point for the TracDefg Flutter application.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/services/websocket_service.dart';
import 'package:trabcdefg/screens/login_screen.dart';
import 'package:trabcdefg/screens/main_screen.dart';
import 'package:trabcdefg/screens/splash_screen.dart';
import 'package:trabcdefg/screens/reports/combined_report_screen.dart';
import 'package:trabcdefg/screens/reports/summary_report_screen.dart';
import 'package:trabcdefg/screens/reports/stops_report_screen.dart';
import 'package:trabcdefg/screens/reports/route_report_screen.dart';
import 'package:trabcdefg/screens/reports/trips_report_screen.dart';
import 'package:trabcdefg/screens/reports/events_report_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trabcdefg/models/report_summary_hive.dart';
import 'package:trabcdefg/screens/register_screen.dart';
import 'package:trabcdefg/screens/reset_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/services/localization_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trabcdefg/models/route_positions_hive.dart';

void main() async {
  // Ensure that Flutter is initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local data storage.
  await Hive.initFlutter();
  Hive.registerAdapter(ReportSummaryHiveAdapter());

  Hive.registerAdapter(RoutePositionsHiveAdapter());
  
  // Load the saved Traccar server URL and the language code from shared preferences.
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('traccarServerUrl');
  final savedLanguageCode = prefs.getString('saved_language_code');

  await initializeDateFormatting();
  
  runApp(TraccarApp(
    initialUrl: savedUrl,
    initialLanguageCode: savedLanguageCode,
  ));
}

class TraccarApp extends StatelessWidget {
  final String? initialUrl;
  final String? initialLanguageCode;

  const TraccarApp({
    super.key,
    this.initialUrl,
    this.initialLanguageCode,
  });

  @override
  Widget build(BuildContext context) {
    // Use MultiProvider to provide multiple services to the widget tree.
    return MultiProvider(
      providers: [
        // Provide the API client with the initial server URL.
        Provider<api.ApiClient>(
          create: (_) => api.ApiClient(
            basePath: initialUrl != null ? '$initialUrl/api' : 'https://demo3.traccar.org/api',
          ),
        ),
        // Provide the authentication service.
        Provider<AuthService>(
          create: (context) => AuthService(
            apiClient: context.read<api.ApiClient>(),
          ),
        ),
        // Provide the WebSocket service.
        Provider<WebSocketService>(
          create: (_) => WebSocketService(),
        ),
        // Provide the main TraccarProvider for state management.
        ChangeNotifierProvider<TraccarProvider>(
          create: (context) => TraccarProvider(
            apiClient: context.read<api.ApiClient>(),
            webSocketService: context.read<WebSocketService>(),
            authService: context.read<AuthService>(),
          ),
        ),
      ],
      // Changed MaterialApp to GetMaterialApp to correctly handle GetX localization.
      child: GetMaterialApp(
        title: 'Trabcdefg',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        // Configure localization for the app using GetX properties.
        translations: LocalizationService(),
        locale: initialLanguageCode != null
            ? LocalizationService.getLocaleFromLang(initialLanguageCode!)
            : Get.deviceLocale ?? LocalizationService.fallbackLocale,
        fallbackLocale: LocalizationService.fallbackLocale,
        
        // Define all the application routes.
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/main': (context) => const MainScreen(),
          '/register': (context) => const RegisterScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
          '/reports/combined': (context) => const CombinedReportScreen(),
          '/reports/summary': (context) => const SummaryReportScreen(),
          '/reports/stops': (context) => const StopsReportScreen(),
          '/reports/route': (context) => const RouteReportScreen(),
          '/reports/trips': (context) => const TripsReportScreen(),
          '/reports/events': (context) => const EventsReportScreen(),
        },
      ),
    );
  }
}