import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Holds the JWT and the cached signed-in user so a relaunch does not need a
/// round trip before the router can decide where to send the user.
class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _expiryKey = 'auth_token_expires_at';

  final SharedPreferences _prefs;

  TokenStorage(this._prefs);

  String? get token {
    final value = _prefs.getString(_tokenKey);
    if (value == null || value.isEmpty) return null;
    if (isExpired) return null;
    return value;
  }

  bool get isExpired {
    final raw = _prefs.getString(_expiryKey);
    if (raw == null) return false;
    final expiry = DateTime.tryParse(raw);
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  Map<String, dynamic>? get cachedUser {
    final raw = _prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> save({
    required String token,
    required Map<String, dynamic> user,
    DateTime? expiresAt,
  }) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(user));
    if (expiresAt != null) {
      await _prefs.setString(_expiryKey, expiresAt.toIso8601String());
    } else {
      await _prefs.remove(_expiryKey);
    }
  }

  /// Rewrites only the cached user, leaving the token and its expiry alone.
  Future<void> saveUser(Map<String, dynamic> user) =>
      _prefs.setString(_userKey, jsonEncode(user));

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
    await _prefs.remove(_expiryKey);
  }
}
