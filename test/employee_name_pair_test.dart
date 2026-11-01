import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/localization/lang_keys.dart';
import 'package:attendence/core/network/api_exception.dart';
import 'package:attendence/features/attendance/data/data_source/attendance_local_data_source.dart';

/// A surname alone and a full name alone may repeat; only the pair is unique.
void main() {
  late AppDatabase database;
  late AttendanceLocalDataSource employees;

  setUp(() async {
    database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    employees = AttendanceLocalDataSource(database);
  });

  tearDown(() async => database.close());

  Future<String> add(String surname, String fullName) async {
    final employee = await employees.createEmployee({
      'surname': surname,
      'full_name': fullName,
      'personal_id': '${surname.hashCode}$fullName',
    });
    return employee.id;
  }

  test('two people may share a surname when their names differ', () async {
    await add('Ali', 'Sara');
    await add('Ali', 'Omar');
  });

  test('two people may share a full name when their surnames differ', () async {
    await add('Ali', 'Sara');
    await add('Hassan', 'Sara');
  });

  test('the same surname and full name pair is refused', () async {
    await add('Ali', 'Sara');

    expect(
      () => add('Ali', 'Sara'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorDuplicateEmployeeName,
        ),
      ),
    );
  });

  test('spacing, case and alef variants are still the same pair', () async {
    await add('Ali', 'Sara');

    expect(
      () => add('  ali ', ' sara  '),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorDuplicateEmployeeName,
        ),
      ),
    );
  });

  test('editing an employee onto an existing pair is refused', () async {
    await add('Ali', 'Sara');
    final omar = await add('Hassan', 'Omar');

    expect(
      () => employees.updateEmployee(omar, {'surname': 'Ali', 'full_name': 'Sara'}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorDuplicateEmployeeName,
        ),
      ),
    );
  });

  test('editing an employee may keep their own pair', () async {
    final sara = await add('Ali', 'Sara');

    await employees.updateEmployee(sara, {'phone': '0500000000'});
    await employees.updateEmployee(sara, {
      'surname': 'Ali',
      'full_name': 'Sara',
    });
  });

  test('editing only the surname is checked against the stored full name', () async {
    await add('Ali', 'Omar');
    final third = await add('Hassan', 'Omar');

    expect(
      () => employees.updateEmployee(third, {'surname': 'Ali'}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorDuplicateEmployeeName,
        ),
      ),
    );
  });
}
