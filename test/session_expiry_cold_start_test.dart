import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/services/api_client_factory.dart';
import 'package:trabcdefg/services/auth_session_store.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

/// Stands in for the platform keystore and outlives a store instance the same
/// way the device keychain outlives the app process.
class MemoryKeychain implements SecureStore {
  MemoryKeychain([Map<String, String>? seed]) : values = {...?seed};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// The parts of the Traccar API a reopened app touches, with the status codes
/// the server really answers: protected endpoints return 401 for a session it
/// no longer knows, while GET /session is PermitAll and returns 404.
class FakeTraccar {
  final Set<String> validSessions = {};
  final List<String> requests = [];
  var logins = 0;
  var issued = 0;

  late HttpServer _server;

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final body = await utf8.decoder.bind(request).join();
    final authenticated = validSessions.contains(_sessionIdOf(request));
    requests.add('${request.method} $path ${authenticated ? 'ok' : 'anonymous'}');
    final response = request.response;

    if (request.method == 'POST' && path == '/api/session') {
      logins++;
      final fields = Uri.splitQueryString(body);
      if (fields['email'] != 'driver@fleet.test' ||
          fields['password'] != 'secret') {
        return _send(response, 401, {'message': 'Invalid email or password'});
      }
      final sessionId = 'session-${++issued}';
      validSessions.add(sessionId);
      response.headers.add('set-cookie', 'JSESSIONID=$sessionId; Path=/; HttpOnly');
      return _send(response, 200, _user);
    }

    if (path == '/api/session') {
      return authenticated ? _send(response, 200, _user) : _send(response, 404, {});
    }

    if (!authenticated) return _send(response, 401, {});
    return _send(response, 200, <Object>[]);
  }

  String? _sessionIdOf(HttpRequest request) {
    for (final header in request.headers['cookie'] ?? <String>[]) {
      for (final part in header.split(';')) {
        final trimmed = part.trim();
        if (trimmed.startsWith('JSESSIONID=')) return trimmed.substring(11);
      }
    }
    return null;
  }

  Future<void> _send(
    HttpResponse response,
    int status,
    Object body,
  ) async {
    response
      ..statusCode = status
      ..headers.set('content-type', 'application/json')
      ..write(jsonEncode(body));
    await response.close();
  }

  static final Map<String, Object?> _user = {
    'id': 1,
    'name': 'Driver',
    'email': 'driver@fleet.test',
    'readonly': false,
    'administrator': false,
    'latitude': 0.0,
    'longitude': 0.0,
    'zoom': 0,
    'attributes': <String, Object?>{},
  };
}

void main() {
  late FakeTraccar server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = FakeTraccar();
    await server.start();
  });

  tearDown(() => server.stop());

  test('a reopened app renews the expired session the splash needs', () async {
    // What a login left on the device 24 hours ago, now expired server side.
    final keychain = MemoryKeychain({
      'auth_session_id': 'expired-session',
      'auth_email': 'driver@fleet.test',
      'auth_password': 'secret',
    });

    final store = AuthSessionStore(storage: keychain);
    await store.load();
    expect(store.sessionId, 'expired-session');

    // The same client the app builds at startup, wired by the production
    // factory: shared session cookie plus the single-flight 401 refresh.
    final client = ApiClientFactory.create('${server.baseUrl}/api', sessionStore: store);

    // The five requests SplashScreen fires, as _fetchInitialData sends them.
    final user = await api.SessionApi(client).getSession();
    await Future.wait([
      api.DevicesApi(client).getDevices(),
      api.PositionsApi(client).getPositions(),
      api.GeofencesApi(client).getGeofences(),
      api.NotificationsApi(client).getNotifications(),
    ]);

    expect(user?.email, 'driver@fleet.test');
    expect(server.logins, 1, reason: 'the app must sign in again by itself');
    expect(store.sessionId, isNot('expired-session'));
    expect(server.validSessions, contains(store.sessionId));
  });

  test('a session the server still accepts costs no extra login', () async {
    final keychain = MemoryKeychain({
      'auth_session_id': 'live-session',
      'auth_email': 'driver@fleet.test',
      'auth_password': 'secret',
    });
    server.validSessions.add('live-session');

    final store = AuthSessionStore(storage: keychain);
    await store.load();
    final client = ApiClientFactory.create('${server.baseUrl}/api', sessionStore: store);

    await api.SessionApi(client).getSession();
    await api.DevicesApi(client).getDevices();

    expect(server.logins, 0);
    expect(store.sessionId, 'live-session');
  });
}
