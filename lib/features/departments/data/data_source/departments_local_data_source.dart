import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_id.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../models/department_model.dart';

/// The departments the admin maintains, and the employees standing in them.
///
/// The department is stored on the employee as its name, not as a foreign key —
/// see the note on the `departments` table in [AppDatabase] for why. Two
/// consequences are this class's to handle, and nothing above it has to know
/// about either:
///
///  * A name in use but not in the table — carried over from before the list
///    existed, or written by an import — is still offered by the picker.
///    [getDepartments] unions the two, so a department can never disappear from
///    under the people in it.
///  * Renaming one has to move its staff with it, and deleting one has to let
///    them go, or the employee list would keep pointing at a department the
///    admin can no longer see.
class DepartmentsLocalDataSource {
  static const _departments = 'departments';
  static const _employees = 'employees';

  final AppDatabase _database;

  DepartmentsLocalDataSource(this._database);

  Database get _db => _database.db;

  /// Every department, alphabetical, each with the number of employees in it.
  Future<List<DepartmentModel>> getDepartments() async {
    return _guard(() async {
      final rows = await _db.rawQuery('''
        SELECT d.id AS id,
               d.name AS name,
               (SELECT COUNT(*) FROM $_employees e
                 WHERE TRIM(e.department) = d.name COLLATE NOCASE) AS in_use
          FROM $_departments d
        UNION ALL
        -- In use, but never added to the list. Given a blank id, which is what
        -- [DepartmentModel.isUnlisted] reads, so the admin can still rename it
        -- or clear it away.
        SELECT '' AS id,
               TRIM(e.department) AS name,
               COUNT(*) AS in_use
          FROM $_employees e
         WHERE TRIM(e.department) <> ''
           AND NOT EXISTS (SELECT 1 FROM $_departments d
                            WHERE d.name = TRIM(e.department) COLLATE NOCASE)
         GROUP BY TRIM(e.department) COLLATE NOCASE
         ORDER BY name COLLATE NOCASE
      ''');

      return rows.map(DepartmentModel.fromJson).toList();
    });
  }

  /// Adds a department to the list.
  ///
  /// Refuses a name already taken, in any case: two spellings of one department
  /// would split its staff across every report in the app.
  Future<DepartmentModel> createDepartment(String name) async {
    return _guard(() async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw const ApiException(LangKeys.errorDepartmentNameRequired);
      }
      if (await _nameTaken(trimmed, exceptId: null)) {
        throw const ApiException(LangKeys.errorDepartmentExists);
      }

      final id = DbId.generate();
      await _db.insert(_departments, {
        'id': id,
        'name': trimmed,
        'created_at': DateTime.now().toIso8601String(),
      });

      return DepartmentModel(id: id, name: trimmed);
    });
  }

  /// Renames a department and moves its staff with it.
  ///
  /// The two go together in one transaction. Renaming the row alone would leave
  /// every employee in it pointing at a department that no longer exists, and
  /// they would reappear as an unlisted one under the old spelling — the admin
  /// would see both.
  Future<DepartmentModel> renameDepartment(
    DepartmentModel department,
    String name,
  ) async {
    return _guard(() async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw const ApiException(LangKeys.errorDepartmentNameRequired);
      }
      if (await _nameTaken(trimmed, exceptId: department.id)) {
        throw const ApiException(LangKeys.errorDepartmentExists);
      }

      final id = department.isUnlisted ? DbId.generate() : department.id;

      await _db.transaction((txn) async {
        if (department.isUnlisted) {
          // It only ever existed as text on the employees. Renaming it is what
          // finally puts it on the list.
          await txn.insert(_departments, {
            'id': id,
            'name': trimmed,
            'created_at': DateTime.now().toIso8601String(),
          });
        } else {
          await txn.update(
            _departments,
            {'name': trimmed},
            where: 'id = ?',
            whereArgs: [id],
          );
        }

        await _moveEmployees(txn, from: department.name, to: trimmed);
      });

      return DepartmentModel(id: id, name: trimmed, inUse: department.inUse);
    });
  }

  /// Removes a department and leaves its staff without one.
  ///
  /// Deliberately not refused when somebody is in it. A department being
  /// dissolved is exactly when an admin needs to delete it, and blocking that
  /// until every employee has been moved by hand would mean editing them one at
  /// a time. They are set to no department instead, which the picker offers as
  /// an ordinary choice — [DepartmentModel.inUse] is what tells the admin how
  /// many that will be before they confirm.
  Future<void> deleteDepartment(DepartmentModel department) async {
    return _guard(() async {
      await _db.transaction((txn) async {
        if (!department.isUnlisted) {
          await txn.delete(
            _departments,
            where: 'id = ?',
            whereArgs: [department.id],
          );
        }
        await _moveEmployees(txn, from: department.name, to: '');
      });
    });
  }

  /// Points everyone in [from] at [to]. An empty [to] is "no department".
  static Future<void> _moveEmployees(
    DatabaseExecutor txn, {
    required String from,
    required String to,
  }) async {
    await txn.update(
      _employees,
      {'department': to, 'updated_at': DateTime.now().toIso8601String()},
      where: 'TRIM(department) = ? COLLATE NOCASE',
      whereArgs: [from.trim()],
    );
  }

  Future<bool> _nameTaken(String name, {required String? exceptId}) async {
    final rows = await _db.query(
      _departments,
      columns: ['id'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
    );
    return rows.any((row) => row['id'] != exceptId);
  }

  /// Reduces a SQLite failure to the one key the UI knows how to translate,
  /// matching how every other data source in the app reports.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(LangKeys.errorDatabase);
    }
  }
}
