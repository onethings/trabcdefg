import 'package:flutter/foundation.dart';
import 'package:trabcdefg/services/auth_session_store.dart';
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
  ApiClient apiClient;

  final AuthSessionStore _sessionStore;

  AuthService({required this.apiClient, AuthSessionStore? sessionStore})
    : _sessionStore = sessionStore ?? AuthSessionStore.instance;

  void updateApiClient(ApiClient newClient) {
    apiClient = newClient;
  }

  Future<void> login(String email, String password) async {
    final sessionApi = SessionApi(apiClient);

    // postSessionWithHttpInfo returns the raw HTTP response and does NOT
    // throw on non-2xx status codes, so the status must be handled here.
    final response = await sessionApi.postSessionWithHttpInfo(email, password);

    // 200 — credentials accepted: persist the session (never the password).
    if (response.statusCode == 200) {
      final jSessionId = extractSessionId(response.headers);
      if (jSessionId == null) {
        throw const LoginException(
          500,
          'Server did not return a valid session cookie.',
        );
      }

      await _sessionStore.saveCredentials(
        sessionId: jSessionId,
        email: email,
        password: password,
      );
      return;
    }

    // 401 — wrong email/password or expired account.
    if (response.statusCode == 401) {
      throw const LoginException(401, 'Invalid email or password.');
    }

    // 400 — bad request; surface the server message (e.g. "Account has expired").
    if (response.statusCode == 400) {
      throw LoginException(
        400,
        response.body.isNotEmpty ? response.body : 'Bad request.',
      );
    }

    // Any other unexpected status.
    throw LoginException(
      response.statusCode,
      'Login failed (HTTP ${response.statusCode}).',
    );
  }

  /// Attempts to renew an expired session using credentials kept in memory.
  ///
  /// The password is never persisted, so this only works within the process
  /// that performed the original login. After an app restart the user has to
  /// sign in again.
  Future<bool> tryAutoRelogin() =>
      refreshSession(client: apiClient, store: _sessionStore);

  /// Re-logs in through [client] and updates [store] with the new session id.
  static Future<bool> refreshSession({
    required ApiClient client,
    required AuthSessionStore store,
  }) async {
    final email = store.email;
    final password = store.password;
    if (email == null || password == null) return false;

    try {
      final response = await SessionApi(client)
          .postSessionWithHttpInfo(email, password);
      if (response.statusCode != 200) return false;

      final sessionId = extractSessionId(response.headers);
      if (sessionId == null) return false;

      await store.updateSession(sessionId);
      debugPrint('Session refreshed successfully.');
      return true;
    } catch (e) {
      debugPrint('Session refresh failed: $e');
      return false;
    }
  }

  /// Extracts the JSESSIONID value from a response's `set-cookie` headers.
  static String? extractSessionId(Map<String, String> headers) {
    final setCookieHeaders = headers['set-cookie'] ?? headers['Set-Cookie'];
    if (setCookieHeaders == null) return null;

    // Multiple cookies may be joined with ", ". Match the first JSESSIONID.
    final match = RegExp(r'(?:^|[,\s])JSESSIONID=([^;,\s]+)')
        .firstMatch(setCookieHeaders);
    return match?.group(1);
  }

  Future<void> logout() async {
    await _sessionStore.clear();
  }
}
