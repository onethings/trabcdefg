import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/services/auth_session_store.dart';
import 'package:trabcdefg/services/http_interceptor.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

/// Stands in for the platform keystore. The map outlives a store instance the
/// same way the device keychain outlives the app process.
class MemoryKeychain implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a restarted app can still renew an expired session', () async {
    final keychain = MemoryKeychain();

    final loggedIn = AuthSessionStore(storage: keychain);
    await loggedIn.load();
    await loggedIn.saveCredentials(
      sessionId: 'before',
      email: 'driver@fleet.test',
      password: 'secret',
    );

    // The app was killed and reopened: a new store, nothing in memory.
    final restarted = AuthSessionStore(storage: keychain);
    await restarted.load();

    expect(restarted.sessionId, 'before');
    expect(restarted.email, 'driver@fleet.test');
    expect(restarted.password, 'secret');

    // The restored credentials are enough for the silent re-login that the
    // interceptor runs on the first 401.
    final client = api.ApiClient(basePath: 'https://fleet.test/api')
      ..client = MockClient((request) async {
        expect(request.url.path, '/api/session');
        expect(request.method, 'POST');
        return http.Response(
          '{"id":1,"email":"driver@fleet.test"}',
          200,
          headers: {'set-cookie': 'JSESSIONID=after; Path=/; HttpOnly'},
        );
      });

    expect(
      await AuthService.refreshSession(client: client, store: restarted),
      SessionRefreshResult.renewed,
    );
    expect(restarted.sessionId, 'after');
  });

  test('credentials an older build stored in plain text survive the upgrade', () async {
    SharedPreferences.setMockInitialValues({
      'jSessionId': 'legacy-session',
      'userJson': '{}',
      'saved_email': 'driver@fleet.test',
      'saved_password': 'secret',
    });
    final keychain = MemoryKeychain();

    final store = AuthSessionStore(storage: keychain);
    await store.load();

    expect(store.sessionId, 'legacy-session');
    expect(store.email, 'driver@fleet.test');
    expect(store.password, 'secret');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('saved_password'), isFalse);
    expect(prefs.containsKey('saved_email'), isFalse);

    final restarted = AuthSessionStore(storage: keychain);
    await restarted.load();
    expect(restarted.email, 'driver@fleet.test');
    expect(restarted.password, 'secret');
  });

  test('logout leaves nothing behind for the next process', () async {
    final keychain = MemoryKeychain();
    final store = AuthSessionStore(storage: keychain);
    await store.load();
    await store.saveCredentials(
      sessionId: 's1',
      email: 'driver@fleet.test',
      password: 'secret',
    );

    await store.clear();

    final restarted = AuthSessionStore(storage: keychain);
    await restarted.load();
    expect(restarted.sessionId, isNull);
    expect(restarted.email, isNull);
    expect(restarted.password, isNull);
  });
}
