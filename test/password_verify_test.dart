import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/localization/lang_keys.dart';
import 'package:attendence/core/network/api_exception.dart';
import 'package:attendence/core/storage/token_storage.dart';
import 'package:attendence/features/auth/data/data_source/auth_local_data_source.dart';

/// Confirming an identity before something that cannot be undone.
///
/// The gate in front of a punch correction is only worth having if a wrong
/// password is refused and a right one leaves the session alone, so both are
/// checked here rather than trusted from the dialog.
void main() {
  late AppDatabase database;
  late AuthLocalDataSource auth;
  late TokenStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    storage = TokenStorage(prefs);
    auth = AuthLocalDataSource(database, storage);

    await auth.seedDefaultAdmin(
      email: 'admin@example.com',
      password: 'correct-horse',
    );
  });

  tearDown(() async => database.close());

  Future<String> signedInUserId() async {
    final user = await auth.signIn('admin@example.com', 'correct-horse');
    return user.uid;
  }

  test('the right password passes', () async {
    final id = await signedInUserId();

    await expectLater(
      auth.verifyPassword(userId: id, password: 'correct-horse'),
      completes,
    );
  });

  test('a wrong password is refused', () async {
    final id = await signedInUserId();

    expect(
      () => auth.verifyPassword(userId: id, password: 'not-the-password'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorWrongPassword,
        ),
      ),
    );
  });

  test('an empty password is refused rather than waved through', () async {
    final id = await signedInUserId();

    expect(
      () => auth.verifyPassword(userId: id, password: ''),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorWrongPassword,
        ),
      ),
    );
  });

  test('an unknown account is refused', () async {
    await signedInUserId();

    expect(
      () => auth.verifyPassword(userId: 'nobody', password: 'correct-horse'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorUserNotFound,
        ),
      ),
    );
  });

  test('a disabled account is refused even with the right password', () async {
    final id = await signedInUserId();
    await database.db.update(
      'users',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    expect(
      () => auth.verifyPassword(userId: id, password: 'correct-horse'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorAccountDisabled,
        ),
      ),
    );
  });

  test('a wrong password leaves the session exactly as it was', () async {
    final id = await signedInUserId();
    final tokenBefore = storage.token;
    expect(tokenBefore, isNotNull);

    await expectLater(
      auth.verifyPassword(userId: id, password: 'wrong'),
      throwsA(isA<ApiException>()),
    );

    // Confirming an identity must never open or close one.
    expect(storage.token, tokenBefore);
    expect(auth.cachedUser?.uid, id);
  });

  test('verifying does not open a session of its own', () async {
    // Nobody signed in: the stored session stays empty whatever the answer.
    final rows = await database.db.query('users', columns: ['id'], limit: 1);
    final id = rows.first['id'] as String;

    await auth.verifyPassword(userId: id, password: 'correct-horse');

    expect(storage.token, isNull);
    expect(auth.cachedUser, isNull);
  });
}
