import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/src/generated_api/api.dart';

class AuthService {
  // FIX: Removed 'final' to allow the client to be updated
  ApiClient apiClient;

  AuthService({required this.apiClient});

  // FIX: Method to replace the entire ApiClient instance
  void updateApiClient(ApiClient newClient) {
    apiClient = newClient;
  }

  Future<void> login(String email, String password) async {
    try {
      final sessionApi = SessionApi(apiClient);

      final response = await sessionApi.postSessionWithHttpInfo(email, password);

      final setCookieHeader = response.headers['set-cookie'];
      if (setCookieHeader == null) {
        throw Exception('Login failed: Session cookie not found.');
      }

      final jSessionId = setCookieHeader.split(';').firstWhere((s) => s.startsWith('JSESSIONID='), orElse: () => '').split('=').last;

      if (jSessionId.isEmpty) {
        throw Exception('Login failed: Invalid session cookie.');
      }

      // Save the session ID and credentials for auto-login / auto-relogin
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jSessionId', jSessionId);
      await prefs.setString('userJson', response.body);
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
    } on ApiException catch (e) {
      if (e.code == 401) {
        throw Exception('Invalid email or password.');
      }
      throw Exception('Login failed: ${e.message}');
    }
  }

  /// Attempts to re-login using saved credentials (email & password).
  /// Returns `true` if the re-login succeeded, `false` if no saved credentials
  /// exist or the credentials are invalid.
  Future<bool> tryAutoRelogin() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    final password = prefs.getString('saved_password');

    if (email == null || password == null) return false;

    try {
      await login(email, password);
      debugPrint('Auto-relogin succeeded with saved credentials.');
      return true;
    } catch (e) {
      debugPrint('Auto-relogin failed: $e');
      // Saved credentials are no longer valid — clear them
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      return false;
    }
  }

  Future<void> logout() async {
    // Clear the session ID and saved credentials from storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jSessionId');
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
  }
}
