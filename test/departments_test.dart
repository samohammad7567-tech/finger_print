import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/localization/lang_keys.dart';
import 'package:attendence/core/network/api_exception.dart';
import 'package:attendence/features/attendance/data/data_source/attendance_local_data_source.dart';
import 'package:attendence/features/departments/data/data_source/departments_local_data_source.dart';
import 'package:attendence/features/departments/data/models/department_model.dart';

/// The department list, and the employees standing in it.
///
/// The department is stored on the employee as its name rather than as a
/// foreign key, so nothing in SQLite keeps the two in step — this data source
/// does. That is what these check: that a rename takes its staff with it, that
/// a delete lets them go instead of stranding them, and that a department
/// nobody added but somebody is in is still offered.
void main() {
  late AppDatabase database;
  late AttendanceLocalDataSource attendance;
  late DepartmentsLocalDataSource departments;

  setUp(() async {
    database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    attendance = AttendanceLocalDataSource(database);
    departments = DepartmentsLocalDataSource(database);
  });

  tearDown(() async => database.close());

  Future<void> employee(String name, String department) async {
    await attendance.createEmployee({
      'full_name': name,
      'department': department,
    });
  }

  Future<DepartmentModel> byName(String name) async {
    final all = await departments.getDepartments();
    return all.firstWhere((d) => d.name == name);
  }

  test('an added department is offered with nobody in it', () async {
    await departments.createDepartment('Security');

    final all = await departments.getDepartments();
    expect(all, hasLength(1));
    expect(all.single.name, 'Security');
    expect(all.single.inUse, 0);
    expect(all.single.isUnlisted, isFalse);
  });

  test('the same name in another case is refused', () async {
    await departments.createDepartment('Security');

    expect(
      () => departments.createDepartment('security'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorDepartmentExists,
        ),
      ),
    );
  });

  test('a blank name is refused', () async {
    expect(
      () => departments.createDepartment('   '),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorDepartmentNameRequired,
        ),
      ),
    );
  });

  test('a department in use but never added is still offered', () async {
    // How every employee on an install that predates the list looks.
    await employee('Sara', 'Ops');

    final all = await departments.getDepartments();
    expect(all, hasLength(1));
    expect(all.single.name, 'Ops');
    expect(all.single.inUse, 1);
    expect(
      all.single.isUnlisted,
      isTrue,
      reason: 'nobody added it; it exists only because Sara is in it',
    );
  });

  test('renaming one moves its staff with it', () async {
    await departments.createDepartment('Ops');
    await employee('Sara', 'Ops');
    await employee('Khalid', 'Ops');

    await departments.renameDepartment(await byName('Ops'), 'Operations');

    final all = await departments.getDepartments();
    expect(
      all,
      hasLength(1),
      reason: 'the old name must not linger as unlisted',
    );
    expect(all.single.name, 'Operations');
    expect(all.single.inUse, 2);

    final staff = await attendance.getAllEmployees();
    expect(staff.map((e) => e.department), everyElement('Operations'));
  });

  test('renaming an unlisted department puts it on the list', () async {
    await employee('Sara', 'Ops');

    final renamed = await departments.renameDepartment(
      await byName('Ops'),
      'Operations',
    );

    expect(renamed.isUnlisted, isFalse);
    final all = await departments.getDepartments();
    expect(all.single.isUnlisted, isFalse);
    expect(all.single.name, 'Operations');
  });

  test('deleting one leaves its staff without a department', () async {
    await departments.createDepartment('Ops');
    await employee('Sara', 'Ops');

    final ops = await byName('Ops');
    expect(
      ops.inUse,
      1,
      reason: 'the count is what the confirm dialog warns with',
    );

    await departments.deleteDepartment(ops);

    expect(await departments.getDepartments(), isEmpty);
    final staff = await attendance.getAllEmployees();
    expect(staff, hasLength(1), reason: 'the employee is kept, not deleted');
    expect(staff.single.department, '');
  });

  test('deleting one leaves every other department alone', () async {
    await departments.createDepartment('Ops');
    await departments.createDepartment('Security');
    await employee('Sara', 'Ops');
    await employee('Khalid', 'Security');

    await departments.deleteDepartment(await byName('Ops'));

    final all = await departments.getDepartments();
    expect(all.map((d) => d.name), ['Security']);
    expect(all.single.inUse, 1);
  });

  test('an employee saved with no department is not a department', () async {
    await employee('Sara', '');

    expect(
      await departments.getDepartments(),
      isEmpty,
      reason: 'the blank must not become a department called ""',
    );
  });
}
