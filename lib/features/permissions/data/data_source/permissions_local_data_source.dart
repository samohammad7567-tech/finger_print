import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_id.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../models/permission_request_model.dart';

/// Permission requests in the local SQLite database.
///
/// Signature-compatible with the remote data source it replaces, so the repo,
/// the cubits and the screens above them did not change.
class PermissionsLocalDataSource {
  static const _table = 'permission_requests';

  final AppDatabase _database;

  PermissionsLocalDataSource(this._database);

  Database get _db => _database.db;

  Future<List<PermissionRequestModel>> getPermissions() => _list(limit: 50);

  Future<List<PermissionRequestModel>> getAllPermissions() => _list(limit: 100);

  Future<List<PermissionRequestModel>> getPermissionsByDate(String date) =>
      _list(where: 'p.date = ? AND p.status = ?', args: [date, 'approved']);

  /// No limit — report screens cover a whole month and must see every row.
  Future<List<PermissionRequestModel>> getPermissionsByDateRange(
    String startDate,
    String endDate,
  ) => _list(
    where: 'p.date >= ? AND p.date <= ? AND p.status = ?',
    args: [startDate, endDate, 'approved'],
  );

  Future<PermissionRequestModel?> findExistingPermission(
    String employeeId,
    String date,
    String type,
  ) async {
    return _guard(() async {
      final rows = await _list(
        where: 'p.employee_id = ? AND p.date = ? AND p.permission_type = ?',
        args: [employeeId, date, type],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    });
  }

  Future<PermissionRequestModel> createPermission(
    PermissionRequestModel perm,
  ) async {
    return _guard(() async {
      final existing = await findExistingPermission(
        perm.employeeId,
        perm.date,
        perm.permissionType,
      );
      if (existing != null) {
        throw const ApiException(LangKeys.errorDuplicatePermission);
      }

      final now = DateTime.now().toIso8601String();
      final id = DbId.generate();

      await _db.insert(_table, {
        'id': id,
        'employee_id': perm.employeeId,
        'permission_type': perm.permissionType,
        'date': perm.date,
        'start_time': perm.startTime,
        'end_time': perm.endTime,
        'reason': perm.reason,
        'status': perm.status,
        'approved_by': perm.approvedBy,
        'notes': perm.notes,
        'created_at': now,
        'updated_at': now,
      });

      final created = await _byId(id);
      if (created == null) throw const ApiException(LangKeys.errorUnknown);
      return created;
    });
  }

  Future<PermissionRequestModel> updatePermissionStatus(
    String id,
    String status,
    String approvedBy,
  ) async {
    return _guard(() async {
      final changed = await _db.update(
        _table,
        {
          'status': status,
          'approved_by': approvedBy,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw const ApiException(LangKeys.errorNotFound);

      final updated = await _byId(id);
      if (updated == null) throw const ApiException(LangKeys.errorNotFound);
      return updated;
    });
  }

  /// Approved vacation days this employee has taken in the given "yyyy-MM".
  Future<int> countMonthlyVacations(String employeeId, String yearMonth) async {
    return _guard(() async {
      final result = await _db.rawQuery(
        '''
        SELECT COUNT(*) AS c FROM $_table
        WHERE employee_id = ?
          AND date LIKE ?
          AND permission_type = 'vacation'
          AND status = 'approved'
        ''',
        [employeeId, '$yearMonth-%'],
      );
      return (result.first['c'] as int?) ?? 0;
    });
  }

  /// Joins the employee so the list screens keep showing name and department
  /// without a follow-up query per row.
  Future<List<PermissionRequestModel>> _list({
    String? where,
    List<Object?> args = const [],
    int? limit,
  }) {
    return _guard(() async {
      final rows = await _db.rawQuery('''
        SELECT p.*, e.full_name AS employee_name, e.department AS department
        FROM $_table p
        LEFT JOIN employees e ON e.id = p.employee_id
        ${where == null ? '' : 'WHERE $where'}
        ORDER BY p.date DESC, p.created_at DESC
        ${limit == null ? '' : 'LIMIT $limit'}
        ''', args);
      return rows.map(PermissionRequestModel.fromJson).toList();
    });
  }

  Future<PermissionRequestModel?> _byId(String id) async {
    final rows = await _list(where: 'p.id = ?', args: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const ApiException(LangKeys.errorDuplicatePermission);
      }
      throw ApiException(LangKeys.errorDatabase, detail: e.toString());
    } catch (e) {
      throw ApiException(LangKeys.errorUnknown, detail: e.toString());
    }
  }
}
