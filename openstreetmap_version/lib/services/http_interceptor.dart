// lib/services/http_interceptor.dart
// A custom HTTP client that intercepts 401 Unauthorized responses
// and triggers a callback to handle session expiration globally.

import 'dart:async';
import 'package:http/http.dart' as http;

/// Wraps an [http.Client] to intercept 401 responses.
///
/// When the server returns 401 for any request, [onUnauthorized] is called
/// (via a microtask) so the app can redirect to the login screen.
///
/// Login requests (POST /session) are explicitly excluded from interception
/// because a 401 there means "invalid credentials", not "expired session".
class AuthInterceptingClient extends http.BaseClient {
  final http.Client _inner;
  final void Function()? onUnauthorized;

  AuthInterceptingClient({http.Client? inner, this.onUnauthorized}) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);

    // Intercept 401, but skip login requests (POST /session) since
    // a 401 there means "wrong email/password", not an expired session.
    if (response.statusCode == 401 && onUnauthorized != null) {
      final isLoginRequest = request.method == 'POST' && request.url.path.endsWith('/session');
      if (!isLoginRequest) {
        Future.microtask(() => onUnauthorized!());
      }
    }

    return response;
  }

  @override
  void close() => _inner.close();
}
