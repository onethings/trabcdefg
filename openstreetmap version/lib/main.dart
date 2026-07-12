// lib/main.dart
// Main entry point for the TracDefg Flutter application.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/constants.dart';
import 'package:trabcdefg/models/report_summary_hive.dart';
import 'package:trabcdefg/models/route_positions_hive.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/providers/settings_provider.dart';
import 'package:trabcdefg/providers/theme_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/login_screen.dart';
import 'package:trabcdefg/screens/main_screen.dart';
import 'package:trabcdefg/screens/register_screen.dart';
import 'package:trabcdefg/screens/reports/combined_report_screen.dart';
import 'package:trabcdefg/screens/reports/events_report_screen.dart';
import 'package:trabcdefg/screens/reports/route_report_screen.dart';
import 'package:trabcdefg/screens/reports/stops_report_screen.dart';
import 'package:trabcdefg/screens/reports/summary_report_screen.dart';
import 'package:trabcdefg/screens/reports/trips_report_screen.dart';
import 'package:trabcdefg/screens/reset_password_screen.dart';
import 'package:trabcdefg/screens/splash_screen.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/services/http_interceptor.dart';
import 'package:trabcdefg/services/localization_service.dart';
import 'package:trabcdefg/services/websocket_service.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

void main() async {
  // Ensure that Flutter is initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();

  // Group initialization tasks into Future.wait for parallel execution.
  // This reduces the time before runApp is called.
  final results = await Future.wait([
    () async {
      await Hive.initFlutter();
      Hive.registerAdapter(ReportSummaryHiveAdapter());
      Hive.registerAdapter(RoutePositionsHiveAdapter());
      await Hive.openBox('ui_settings');
    }(),
    SharedPreferences.getInstance(),
    initializeDateFormatting(),
  ]);

  final prefs = results[1] as SharedPreferences;
  final savedUrl = prefs.getString('traccarServerUrl');
  final savedLanguageCode = prefs.getString('saved_language_code');

  runApp(TraccarApp(initialUrl: savedUrl, initialLanguageCode: savedLanguageCode));
}

class TraccarApp extends StatelessWidget {
  final String? initialUrl;
  final String? initialLanguageCode;

  const TraccarApp({super.key, this.initialUrl, this.initialLanguageCode});

  @override
  Widget build(BuildContext context) {
    // Use MultiProvider to provide multiple services to the widget tree.
    return MultiProvider(
      providers: [
        // Provide the API client with the initial server URL.
        Provider<api.ApiClient>(
          create: (_) {
            final client = api.ApiClient(
              basePath: initialUrl != null ? '$initialUrl/api' : AppConstants.traccarApiUrl, // Use constant default
            );

            // CRITICAL FIX: Add the Accept header here to force JSON response from the server.
            // This resolves the 'PK' (ZIP file) error.
            client.addDefaultHeader('Accept', 'application/json');

            // Wrap the HTTP client with an interceptor that detects 401
            // (expired session) responses and attempts auto-relogin first.
            client.client = AuthInterceptingClient(
              onUnauthorized: () async {
                debugPrint('AuthInterceptingClient: 401 detected, attempting auto-relogin...');

                // Try auto-relogin using saved credentials
                final prefs = await SharedPreferences.getInstance();
                final email = prefs.getString('saved_email');
                final password = prefs.getString('saved_password');

                if (email != null && password != null) {
                  try {
                    // POST /session is excluded from interception, so this is safe
                    final sessionApi = api.SessionApi(client);
                    final response = await sessionApi.postSessionWithHttpInfo(email, password);

                    final setCookieHeader = response.headers['set-cookie'];
                    if (setCookieHeader != null) {
                      final jSessionId = setCookieHeader.split(';').firstWhere((s) => s.startsWith('JSESSIONID='), orElse: () => '').split('=').last;
                      if (jSessionId.isNotEmpty) {
                        await prefs.setString('jSessionId', jSessionId);
                        await prefs.setString('userJson', response.body);
                        debugPrint('Auto-relogin succeeded! New session acquired.');

                        // Update the TraccarProvider with the fresh session
                        final provider = TraccarProvider.instance;
                        provider?.setSessionId(jSessionId);

                        // Re-fetch data so the UI immediately reflects the refreshed session.
                        // This is critical when the session expired silently (e.g. app
                        // backgrounded for a week) and the interceptor catches the first 401.
                        try {
                          await provider?.fetchInitialData().timeout(const Duration(seconds: 15));
                          debugPrint('Data re-fetched after interceptor auto-relogin.');
                        } catch (fetchError) {
                          // Data re-fetch failed, but we have a valid session now.
                          // The WebSocket will connect and push updates shortly.
                          debugPrint('Data re-fetch after interceptor auto-relogin failed: $fetchError');
                        }

                        return; // Don't redirect — the app can continue
                      }
                    }
                  } catch (e) {
                    debugPrint('Auto-relogin failed in interceptor: $e');
                  }
                }

                // Auto-relogin failed or no saved credentials — clear & redirect
                debugPrint('Auto-relogin unavailable, redirecting to login.');
                await prefs.remove('jSessionId');
                await prefs.remove('userJson');
                await prefs.remove('saved_email');
                await prefs.remove('saved_password');
                Get.offAllNamed('/login');
              },
            );

            return client;
          },
        ),
        // Provide the authentication service.
        Provider<AuthService>(create: (context) => AuthService(apiClient: context.read<api.ApiClient>())),
        // Provide the WebSocket service.
        Provider<WebSocketService>(create: (_) => WebSocketService()),
        // Provide the main TraccarProvider for state management.
        ChangeNotifierProvider<TraccarProvider>(
          create: (context) => TraccarProvider(apiClient: context.read<api.ApiClient>(), webSocketService: context.read<WebSocketService>(), authService: context.read<AuthService>()),
        ),
        ChangeNotifierProvider<MapStyleProvider>(create: (_) => MapStyleProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
      ],
      // Changed MaterialApp to GetMaterialApp to correctly handle GetX localization.
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, themeProvider, settingsProvider, child) {
          return GetMaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Trabcdefg',
            theme: themeProvider.getTheme(Brightness.light),
            darkTheme: themeProvider.getTheme(Brightness.dark),
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              final data = MediaQuery.of(context);
              return MediaQuery(
                data: data.copyWith(textScaler: TextScaler.linear(settingsProvider.fontSizeScale)),
                child: child!,
              );
            },
            // Configure localization for the app using GetX properties.
            translations: LocalizationService(),
            locale: initialLanguageCode != null ? LocalizationService.getLocaleFromLang(initialLanguageCode!) : Get.deviceLocale ?? LocalizationService.fallbackLocale,
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
          );
        },
      ),
    );
  }
}
