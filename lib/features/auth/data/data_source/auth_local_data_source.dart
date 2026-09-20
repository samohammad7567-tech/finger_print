import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_id.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/guard_model.dart';

/// Local accounts, replacing the JWT auth the API used to provide.
///
/// With no server there is nothing to issue or validate a token, so a session
/// is simply the signed-in user cached in [TokenStorage]. Passwords are stored
/// as PBKDF2-HMAC-SHA256 with a per-user salt — never in plain text, so someone
/// opening the database file cannot read them back.
class AuthLocalDataSource {
  static const _table = 'users';

  /// Cost factor. High enough to make offline guessing slow, low enough that a
  /// login on a modest office PC stays imperceptible.
  static const _iterations = 120000;
  static const _keyLength = 32;

  final AppDatabase _database;
  final TokenStorage _storage;

  AuthLocalDataSource(this._database, this._storage);

  Database get _db => _database.db;

  /// The user restored from local storage, before any database read.
  GuardModel? get cachedUser {
    if (_storage.token == null) return null;
    final json = _storage.cachedUser;
    return json == null ? null : GuardModel.fromJson(json);
  }

  /// Creates the first admin when the account table is empty, so a fresh
  /// install is usable without a separate setup step.
  Future<void> seedDefaultAdmin({
    required String email,
    required String password,
    String displayName = 'Administrator',
  }) async {
    return _guard(() async {
      final existing = await _db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
      if (((existing.first['c'] as int?) ?? 0) > 0) return;

      await _insertUser(
        email: email,
        password: password,
        displayName: displayName,
        role: 'admin',
      );
    });
  }

  Future<GuardModel> signIn(String email, String password) async {
    return _guard(() async {
      final normalized = email.trim().toLowerCase();
      final rows = await _db.query(
        _table,
        where: 'email = ?',
        whereArgs: [normalized],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw const ApiException(LangKeys.errorInvalidCredentials);
      }

      final row = rows.first;
      if ((row['is_active'] as int? ?? 1) == 0) {
        throw const ApiException(LangKeys.errorAccountDisabled);
      }

      final salt = row['password_salt'] as String? ?? '';
      final expected = row['password_hash'] as String? ?? '';
      if (!_verify(password, salt: salt, expected: expected)) {
        // Same key as an unknown email, so a failed login never reveals which
        // half was wrong.
        throw const ApiException(LangKeys.errorInvalidCredentials);
      }

      final user = _toGuard(row);
      await _openSession(user);
      return user;
    });
  }

  Future<GuardModel> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    return _guard(() async {
      final normalized = email.trim().toLowerCase();
      if (normalized.isEmpty || !normalized.contains('@')) {
        throw const ApiException(LangKeys.errorInvalidEmail);
      }
      if (password.length < 6) {
        throw const ApiException(LangKeys.errorWeakPassword);
      }

      final taken = await _db.query(
        _table,
        columns: ['id'],
        where: 'email = ?',
        whereArgs: [normalized],
        limit: 1,
      );
      if (taken.isNotEmpty) {
        throw const ApiException(LangKeys.errorEmailInUse);
      }

      final user = await _insertUser(
        email: normalized,
        password: password,
        displayName: displayName ?? '',
        role: 'guard',
      );

      await _openSession(user);
      return user;
    });
  }

  /// Re-reads the account so a role change made in the admin screens takes
  /// effect on next launch. Returns null when the account is gone or disabled.
  Future<GuardModel?> refreshCurrentUser() async {
    return _guard(() async {
      final cached = cachedUser;
      if (cached == null) return null;

      final rows = await _db.query(
        _table,
        where: 'id = ?',
        whereArgs: [cached.uid],
        limit: 1,
      );

      if (rows.isEmpty || (rows.first['is_active'] as int? ?? 1) == 0) {
        await _storage.clear();
        return null;
      }

      final user = _toGuard(rows.first);
      await _storage.saveUser(user.toJson());
      return user;
    });
  }

  /// Checks a password against an account without opening a session.
  ///
  /// For the moments the app asks somebody to prove they are still the person
  /// who signed in — correcting a day's punches, and anything else that cannot
  /// be undone. It deliberately does not touch [TokenStorage]: this confirms
  /// an identity, it does not grant one, and a wrong answer must leave the
  /// session exactly as it was.
  ///
  /// Returns normally when the password is right and throws otherwise, so a
  /// caller cannot mistake a failure for a pass by ignoring a boolean.
  Future<void> verifyPassword({
    required String userId,
    required String password,
  }) async {
    return _guard(() async {
      final rows = await _db.query(
        _table,
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) throw const ApiException(LangKeys.errorUserNotFound);

      final row = rows.first;
      if ((row['is_active'] as int? ?? 1) == 0) {
        throw const ApiException(LangKeys.errorAccountDisabled);
      }

      final ok = _verify(
        password,
        salt: row['password_salt'] as String? ?? '',
        expected: row['password_hash'] as String? ?? '',
      );
      if (!ok) throw const ApiException(LangKeys.errorWrongPassword);
    });
  }

  /// Changes a password for the signed-in user after checking the current one.
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    return _guard(() async {
      if (newPassword.length < 6) {
        throw const ApiException(LangKeys.errorWeakPassword);
      }

      final rows = await _db.query(
        _table,
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) throw const ApiException(LangKeys.errorUserNotFound);

      final row = rows.first;
      final ok = _verify(
        currentPassword,
        salt: row['password_salt'] as String? ?? '',
        expected: row['password_hash'] as String? ?? '',
      );
      if (!ok) throw const ApiException(LangKeys.errorWrongPassword);

      final salt = _newSalt();
      await _db.update(
        _table,
        {'password_hash': _hash(newPassword, salt), 'password_salt': salt},
        where: 'id = ?',
        whereArgs: [userId],
      );
    });
  }

  /// There is no mail server in a local install, so this cannot do what its
  /// name promises. It fails with a key telling the user to ask an admin.
  Future<void> sendPasswordResetEmail(String email) async {
    throw const ApiException(LangKeys.errorResetUnavailableOffline);
  }

  Future<void> signOut() => _storage.clear();

  // --------------------------------------------------------------- helpers

  Future<GuardModel> _insertUser({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final id = DbId.generate();
    final salt = _newSalt();

    await _db.insert(_table, {
      'id': id,
      'email': email.trim().toLowerCase(),
      'password_hash': _hash(password, salt),
      'password_salt': salt,
      'display_name': displayName.trim(),
      'role': role,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    return GuardModel(
      uid: id,
      name: displayName.trim(),
      email: email.trim().toLowerCase(),
      role: role,
    );
  }

  /// A session with no server to expire it: the cached user is the session, and
  /// the token is a local marker so [TokenStorage.token] stays non-null.
  Future<void> _openSession(GuardModel user) =>
      _storage.save(token: 'local-${DbId.generate()}', user: user.toJson());

  static GuardModel _toGuard(Map<String, Object?> row) => GuardModel(
    uid: row['id'] as String? ?? '',
    name: row['display_name'] as String? ?? '',
    email: row['email'] as String? ?? '',
    role: row['role'] as String? ?? 'guard',
  );

  static String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// PBKDF2-HMAC-SHA256, built on the HMAC the crypto package provides.
  static String _hash(String password, String salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final saltBytes = base64Decode(salt);

    // One output block is enough for a 32-byte key with SHA-256.
    var block = hmac.convert([...saltBytes, 0, 0, 0, 1]).bytes;
    var result = List<int>.from(block);

    for (var i = 1; i < _iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }

    return base64Encode(result.sublist(0, _keyLength));
  }

  /// Compares in constant time so a wrong password cannot be narrowed down by
  /// how long the check took.
  static bool _verify(
    String password, {
    required String salt,
    required String expected,
  }) {
    if (salt.isEmpty || expected.isEmpty) return false;

    final actual = _hash(password, salt);
    if (actual.length != expected.length) return false;

    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const ApiException(LangKeys.errorEmailInUse);
      }
      throw ApiException(LangKeys.errorDatabase, detail: e.toString());
    } catch (e) {
      throw ApiException(LangKeys.errorUnknown, detail: e.toString());
    }
  }
}
