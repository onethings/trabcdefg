// lib/services/api_config.dart
// Single source of truth for URLs derived from the active Traccar server.
import 'package:trabcdefg/src/generated_api/api.dart' as api;

/// Derives every endpoint from the [api.ApiClient.basePath] currently in use.
///
/// Screens must not hard-code a server URL: users can point the app at their
/// own Traccar instance, and requests (including the JSESSIONID cookie) must
/// never be sent to the default demo server by mistake.
class ApiConfig {
  ApiConfig._(this.basePath);

  /// Creates a config for the server the given [client] is talking to.
  factory ApiConfig.fromApiClient(api.ApiClient client) {
    return ApiConfig._(client.basePath.replaceFirst(RegExp(r'/+$'), ''));
  }

  /// API root, for example `https://example.com/api`.
  final String basePath;

  /// Builds an absolute API URI, for example `uri('/notifications/types')`.
  Uri uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$basePath$normalizedPath');
  }

  /// Server root without the `/api` suffix, for user-facing links.
  String get serverUrl => basePath.replaceFirst(RegExp(r'/api$'), '');
}
