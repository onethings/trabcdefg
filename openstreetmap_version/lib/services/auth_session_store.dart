// lib/services/auth_session_store.dart
// Stores the server session in the platform keystore (Android Keystore /
// iOS Keychain) instead of plain-text SharedPreferences.
//
// Credentials (email + password) are kept in memory only for the lifetime of
// the process so the app can silently renew an expired session. They are never
// written to disk.

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionStore {
  AuthSessionStore._();

  static final AuthSessionStore instance = AuthSessionStore._();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _sessionKey = 'auth_session_id';

  /// Keys written by older builds in plain-text SharedPreferences.
  static const _legacyKeys = <String>[
    'jSessionId',
    'userJson',
    'saved_email',
    'saved_password',
  ];

  String? _sessionId;
  String? _email;
  String? _password;
  bool _loaded = false;

  /// Invoked after the current session is discarded (logout or a failed 401
  /// refresh), so listeners can reset in-memory app state.
  Future<void> Function()? onSessionCleared;

  /// Invoked whenever a new session id becomes available.
  void Function(String sessionId)? onSessionUpdated;

  String? get sessionId => _sessionId;

  /// Only available for the current process — used for one silent re-login
  /// when the saved session expires.
  String? get email => _email;
  String? get password => _password;

  /// Loads the persisted session and removes credentials that older builds
  /// stored in plain text.
  Future<void> load() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    final legacySessionId = prefs.getString('jSessionId');

    String? storedSessionId;
    try {
      storedSessionId = await _storage.read(key: _sessionKey);
    } catch (e) {
      debugPrint('AuthSessionStore: failed to read secure storage: $e');
    }

    if (storedSessionId == null &&
        legacySessionId != null &&
        legacySessionId.isNotEmpty) {
      // Migrate the existing session to secure storage before deleting the
      // plain-text copy so users are not forced to log in again.
      storedSessionId = legacySessionId;
      try {
        await _storage.write(key: _sessionKey, value: storedSessionId);
      } catch (e) {
        debugPrint('AuthSessionStore: failed to migrate session: $e');
      }
    }

    _sessionId = storedSessionId;
    await _removeLegacyPrefs(prefs);
    _loaded = true;
  }

  /// Persists the new session id and keeps the credentials in memory only.
  Future<void> saveCredentials({
    required String sessionId,
    required String email,
    required String password,
  }) async {
    _sessionId = sessionId;
    _email = email;
    _password = password;

    try {
      await _storage.write(key: _sessionKey, value: sessionId);
    } catch (e) {
      debugPrint('AuthSessionStore: failed to save session: $e');
    }

    onSessionUpdated?.call(sessionId);
  }

  /// Updates the session after a successful silent re-login.
  Future<void> updateSession(String sessionId) async {
    _sessionId = sessionId;
    try {
      await _storage.write(key: _sessionKey, value: sessionId);
    } catch (e) {
      debugPrint('AuthSessionStore: failed to update session: $e');
    }
    onSessionUpdated?.call(sessionId);
  }

  /// Removes the session and every credential from memory and disk.
  Future<void> clear() async {
    _sessionId = null;
    _email = null;
    _password = null;

    try {
      await _storage.delete(key: _sessionKey);
    } catch (e) {
      debugPrint('AuthSessionStore: failed to delete session: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await _removeLegacyPrefs(prefs);

    final callback = onSessionCleared;
    if (callback != null) {
      try {
        await callback();
      } catch (e) {
        debugPrint('AuthSessionStore: session-cleared callback failed: $e');
      }
    }
  }

  Future<void> _removeLegacyPrefs(SharedPreferences prefs) async {
    for (final key in _legacyKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }
  }
}
