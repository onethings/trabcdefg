// lib/services/api_client_factory.dart
// Creates ApiClient instances that always share the same defaults and the
// global 401 handling.

import 'package:get/get.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/services/auth_session_store.dart';
import 'package:trabcdefg/services/http_interceptor.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class ApiClientFactory {
  ApiClientFactory._();

  /// Creates a client for [basePath] (e.g. `https://host/api`) with:
  /// - `Accept: application/json`
  /// - the shared session cookie
  /// - single-flight 401 refresh + one retry
  static api.ApiClient create(
    String basePath, {
    AuthSessionStore? sessionStore,
  }) {
    final store = sessionStore ?? AuthSessionStore.instance;
    final client = api.ApiClient(basePath: basePath);

    client.addDefaultHeader('Accept', 'application/json');
    client.client = AuthInterceptingClient(
      sessionIdProvider: () => store.sessionId,
      refreshSession: () =>
          AuthService.refreshSession(client: client, store: store),
      onUnauthorized: () async {
        await store.clear();
        Get.offAllNamed('/login');
      },
    );

    return client;
  }
}
