// lib/services/auth_session_store.dart
// Stores the server session and the credentials that renew it in the platform
// keystore (Android Keystore / iOS Keychain) instead of plain-text
// SharedPreferences.
//
// The server expires a session on its own schedule (24 hours by default) and a
// mobile app is usually killed in between, so the credentials have to outlive
// the process. They live in the keystore, never in SharedPreferences.

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The key-value backend behind [AuthSessionStore]. Production uses the
/// platform keystore; tests pass an in-memory map so two stores can model the
/// same device across an app restart.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android Keystore / iOS Keychain.
class KeychainStore implements SecureStore {
  const KeychainStore();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AuthSessionStore {
  AuthSessionStore({SecureStore? storage})
    : _storage = storage ?? const KeychainStore();

  static final AuthSessionStore instance = AuthSessionStore();

  final SecureStore _storage;

  static const _sessionKey = 'auth_session_id';
  static const _emailKey = 'auth_email';
  static const _passwordKey = 'auth_password';

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

  /// Used for one silent re-login when the saved session expires.
  String? get email => _email;
  String? get password => _password;

  /// Loads the persisted session and credentials, and removes the copies that
  /// older builds kept in plain text.
  Future<void> load() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();

    _sessionId = await _read(_sessionKey);
    _email = await _read(_emailKey);
    _password = await _read(_passwordKey);

    final legacySessionId = prefs.getString('jSessionId');
    if ((_sessionId == null || _sessionId!.isEmpty) &&
        legacySessionId != null &&
        legacySessionId.isNotEmpty) {
      // Migrate the existing session to secure storage before deleting the
      // plain-text copy so users are not forced to log in again.
      _sessionId = legacySessionId;
      await _write(_sessionKey, legacySessionId);
    }

    final legacyEmail = prefs.getString('saved_email');
    final legacyPassword = prefs.getString('saved_password');
    if (_email == null && legacyEmail != null && legacyPassword != null) {
      // `fix session expired by auto update session` (6906b04) kept these in
      // plain text; without them an expired session cannot be renewed.
      _email = legacyEmail;
      _password = legacyPassword;
      await _write(_emailKey, legacyEmail);
      await _write(_passwordKey, legacyPassword);
    }

    await _removeLegacyPrefs(prefs);
    _loaded = true;
  }

  /// Persists the new session id and the credentials that renew it.
  Future<void> saveCredentials({
    required String sessionId,
    required String email,
    required String password,
  }) async {
    _sessionId = sessionId;
    _email = email;
    _password = password;

    await _write(_sessionKey, sessionId);
    await _write(_emailKey, email);
    await _write(_passwordKey, password);

    onSessionUpdated?.call(sessionId);
  }

  /// Updates the session after a successful silent re-login.
  Future<void> updateSession(String sessionId) async {
    _sessionId = sessionId;
    await _write(_sessionKey, sessionId);
    onSessionUpdated?.call(sessionId);
  }

  /// Removes the session and every credential from memory and disk.
  Future<void> clear() async {
    _sessionId = null;
    _email = null;
    _password = null;

    await _delete(_sessionKey);
    await _delete(_emailKey);
    await _delete(_passwordKey);

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

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key);
    } catch (e) {
      debugPrint('AuthSessionStore: failed to read $key: $e');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key, value);
    } catch (e) {
      debugPrint('AuthSessionStore: failed to write $key: $e');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key);
    } catch (e) {
      debugPrint('AuthSessionStore: failed to delete $key: $e');
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
