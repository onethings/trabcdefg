import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/services/http_interceptor.dart';

void main() {
  test('extracts JSESSIONID from set-cookie headers', () {
    expect(
      AuthService.extractSessionId({
        'set-cookie': 'JSESSIONID=abc; Path=/; HttpOnly',
      }),
      'abc',
    );
    expect(
      AuthService.extractSessionId({
        'set-cookie': 'foo=bar, JSESSIONID=def; Path=/',
      }),
      'def',
    );
    expect(AuthService.extractSessionId({'set-cookie': 'foo=bar'}), isNull);
    expect(AuthService.extractSessionId({}), isNull);
  });
  test(
    'refreshes the session once and retries every request with the new cookie',
    () async {
      var sessionId = 'old';
      var refreshCalls = 0;
      var unauthorizedCalls = 0;
      final cookies = <String>[];

      final client = AuthInterceptingClient(
        sessionIdProvider: () => sessionId,
        refreshSession: () async {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          sessionId = 'new';
          return true;
        },
        onUnauthorized: () async => unauthorizedCalls++,
        inner: MockClient((request) async {
          final cookie = request.headers['Cookie'] ?? '';
          cookies.add(cookie);
          return cookie == 'JSESSIONID=old'
              ? http.Response('expired', 401)
              : http.Response('ok', 200);
        }),
      );

      final responses = await Future.wait(
        List.generate(
          5,
          (_) => client.get(Uri.parse('https://example.test/api/devices')),
        ),
      );

      expect(
        responses.map((response) => response.statusCode),
        everyElement(200),
      );
      expect(refreshCalls, 1);
      expect(unauthorizedCalls, 0);
      expect(cookies.where((cookie) => cookie == 'JSESSIONID=old').length, 5);
      expect(cookies.where((cookie) => cookie == 'JSESSIONID=new').length, 5);
    },
  );

  test('notifies unauthorized once when the refresh fails', () async {
    var refreshCalls = 0;
    var unauthorizedCalls = 0;

    final client = AuthInterceptingClient(
      sessionIdProvider: () => 'expired',
      refreshSession: () async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return false;
      },
      onUnauthorized: () async => unauthorizedCalls++,
      inner: MockClient((_) async => http.Response('expired', 401)),
    );

    final responses = await Future.wait(
      List.generate(
        3,
        (_) => client.get(Uri.parse('https://example.test/api/devices')),
      ),
    );

    expect(responses.map((response) => response.statusCode), everyElement(401));
    expect(refreshCalls, 1);
    expect(unauthorizedCalls, 1);
  });

  test('does not try to refresh a rejected login request', () async {
    var refreshCalls = 0;
    var unauthorizedCalls = 0;

    final client = AuthInterceptingClient(
      sessionIdProvider: () => 'old',
      refreshSession: () async {
        refreshCalls++;
        return true;
      },
      onUnauthorized: () async => unauthorizedCalls++,
      inner: MockClient((_) async => http.Response('invalid credentials', 401)),
    );

    final response = await client.post(
      Uri.parse('https://example.test/api/session'),
      body: {'email': 'a', 'password': 'b'},
    );

    expect(response.statusCode, 401);
    expect(refreshCalls, 0);
    expect(unauthorizedCalls, 0);
  });
}
