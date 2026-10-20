// lib/services/http_interceptor.dart
// A custom HTTP client that intercepts 401 Unauthorized responses, renews the
// server session once and retries the original request.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef SessionIdProvider = String? Function();
typedef SessionRefresher = Future<SessionRefreshResult> Function();

/// Outcome of a silent session refresh.
enum SessionRefreshResult {
  /// A new session was obtained and persisted.
  renewed,

  /// The server rejected the session (or the credentials are no longer
  /// available), so the user has to sign in again.
  rejected,

  /// The refresh could not be completed (offline, timeout, 5xx). The stored
  /// session may still be valid, so it must not be discarded.
  inconclusive,
}

/// Wraps an [http.Client] to handle expired sessions.
///
/// When the server returns 401 for a request:
/// 1. [refreshSession] is invoked exactly once, even if many requests fail
///    concurrently (single-flight).
/// 2. If the refresh succeeds, the original request is retried once with the
///    new session cookie.
/// 3. If the refresh fails because the server rejected the session,
///    [onUnauthorized] is invoked once so the app can clear its state and
///    return to the login screen. A refresh that merely could not reach the
///    server keeps the session intact.
///
/// Login requests (POST /session) are excluded because a 401 there means
/// "invalid credentials", not "expired session".
class AuthInterceptingClient extends http.BaseClient {
  final http.Client _inner;
  final SessionIdProvider? sessionIdProvider;
  final SessionRefresher? refreshSession;
  final Future<void> Function()? onUnauthorized;

  Completer<SessionRefreshResult>? _refreshCompleter;
  Completer<void>? _unauthorizedCompleter;

  AuthInterceptingClient({
    http.Client? inner,
    this.sessionIdProvider,
    this.refreshSession,
    this.onUnauthorized,
  }) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isLoginRequest = _isLoginRequest(request);

    // Always send the latest session id; the default header on ApiClient can
    // become stale after a silent re-login. Login itself must not send a stale
    // cookie.
    if (isLoginRequest) {
      request.headers.remove('Cookie');
    } else {
      _applySessionCookie(request);
    }

    final response = await _inner.send(request);

    if (response.statusCode != 401 || isLoginRequest) {
      return response;
    }

    if (refreshSession == null) {
      await _notifyUnauthorized();
      return response;
    }

    final refreshResult = await _refreshOnce();
    if (refreshResult == SessionRefreshResult.rejected) {
      await _notifyUnauthorized();
      return response;
    }
    if (refreshResult != SessionRefreshResult.renewed) {
      // The refresh failed for a reason unrelated to the session's validity
      // (offline, timeout, 5xx). Keep the session and let the caller handle
      // the failed request.
      return response;
    }

    final retryRequest = _cloneRequest(request);
    if (retryRequest == null) {
      // The request body cannot be replayed (e.g. multipart upload). The
      // session is valid again, so the caller can retry on its own.
      return response;
    }

    await _drain(response);
    _applySessionCookie(retryRequest);

    final retryResponse = await _inner.send(retryRequest);
    if (retryResponse.statusCode == 401) {
      await _notifyUnauthorized();
    }
    return retryResponse;
  }

  bool _isLoginRequest(http.BaseRequest request) =>
      request.method == 'POST' && request.url.path.endsWith('/session');

  void _applySessionCookie(http.BaseRequest request) {
    final sessionId = sessionIdProvider?.call();
    if (sessionId != null && sessionId.isNotEmpty) {
      request.headers['Cookie'] = 'JSESSIONID=$sessionId';
    }
  }

  /// Runs at most one refresh at a time; concurrent 401s await the same result.
  Future<SessionRefreshResult> _refreshOnce() {
    final existing = _refreshCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<SessionRefreshResult>();
    _refreshCompleter = completer;

    Future(() async {
      var result = SessionRefreshResult.inconclusive;
      try {
        result = await refreshSession!();
      } catch (e) {
        debugPrint('AuthInterceptingClient: session refresh failed: $e');
      } finally {
        _refreshCompleter = null;
        if (!completer.isCompleted) completer.complete(result);
      }
    });

    return completer.future;
  }

  /// Runs [onUnauthorized] at most once for a burst of failures.
  Future<void> _notifyUnauthorized() {
    final existing = _unauthorizedCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _unauthorizedCompleter = completer;

    Future(() async {
      try {
        await onUnauthorized?.call();
      } catch (e) {
        debugPrint('AuthInterceptingClient: onUnauthorized failed: $e');
      } finally {
        _unauthorizedCompleter = null;
        if (!completer.isCompleted) completer.complete();
      }
    });

    return completer.future;
  }

  /// Rebuilds a regular [http.Request] so it can be sent a second time.
  /// Streamed requests (multipart/upload) cannot be replayed.
  http.BaseRequest? _cloneRequest(http.BaseRequest request) {
    if (request is! http.Request) return null;

    return http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes
      ..encoding = request.encoding
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
  }

  Future<void> _drain(http.StreamedResponse response) async {
    try {
      await response.stream.drain<void>();
    } catch (_) {
      // The response is being discarded; an error while draining is harmless.
    }
  }

  @override
  void close() => _inner.close();
}
