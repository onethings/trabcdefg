import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/src/generated_api/api.dart';

/// Thrown when the login request is rejected by the server.
/// Carries the HTTP status code so the UI can react per status.
class LoginException implements Exception {
  final int statusCode;
  final String message;
  const LoginException(this.statusCode, this.message);

  @override
  String toString() => 'LoginException($statusCode): $message';
}

class AuthService {
  // FIX: Removed 'final' to allow the client to be updated
  ApiClient apiClient;

  AuthService({required this.apiClient});

  // FIX: Method to replace the entire ApiClient instance
  void updateApiClient(ApiClient newClient) {
    apiClient = newClient;
  }

  Future<void> login(String email, String password) async {
    final sessionApi = SessionApi(apiClient);

    // postSessionWithHttpInfo returns the raw HTTP response and does NOT
    // throw on non-2xx status codes, so the status must be handled here.
    final response = await sessionApi.postSessionWithHttpInfo(email, password);

    // 200 — credentials accepted: persist the fresh session + credentials.
    if (response.statusCode == 200) {
      final setCookieHeader = response.headers['set-cookie'];
      if (setCookieHeader == null) {
        throw const LoginException(500, 'Server did not return a session cookie.');
      }

      final jSessionId = setCookieHeader.split(';').firstWhere((s) => s.startsWith('JSESSIONID='), orElse: () => '').split('=').last;
      if (jSessionId.isEmpty) {
        throw const LoginException(500, 'Server returned an invalid session cookie.');
      }

      // Save the session ID and credentials for auto-login / auto-relogin
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jSessionId', jSessionId);
      await prefs.setString('userJson', response.body);
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
      return;
    }

    // 401 — wrong email/password or expired account.
    if (response.statusCode == 401) {
      throw const LoginException(401, 'Invalid email or password.');
    }

    // 400 — bad request; surface the server message (e.g. "Account has expired").
    if (response.statusCode == 400) {
      throw LoginException(400, response.body.isNotEmpty ? response.body : 'Bad request.');
    }

    // Any other unexpected status.
    throw LoginException(response.statusCode, 'Login failed (HTTP ${response.statusCode}).');
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
