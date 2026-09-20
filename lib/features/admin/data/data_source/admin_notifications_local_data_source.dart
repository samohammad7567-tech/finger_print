import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_id.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../models/admin_notification_model.dart';

/// Admin notifications in the local SQLite database.
class AdminNotificationsLocalDataSource {
  static const _table = 'admin_notifications';

  final AppDatabase _database;

  AdminNotificationsLocalDataSource(this._database);

  Database get _db => _database.db;

  Future<List<AdminNotificationModel>> getNotifications() async {
    return _guard(() async {
      final rows = await _db.query(
        _table,
        orderBy: 'created_at DESC',
        limit: 50,
      );
      return rows.map(AdminNotificationModel.fromJson).toList();
    });
  }

  Future<int> getUnreadCount() async {
    return _guard(() async {
      final result = await _db.rawQuery(
        'SELECT COUNT(*) AS c FROM $_table WHERE is_read = 0',
      );
      return (result.first['c'] as int?) ?? 0;
    });
  }

  Future<AdminNotificationModel> createNotification(
    AdminNotificationModel notification,
  ) async {
    return _guard(() async {
      final id = DbId.generate();

      await _db.insert(_table, {
        'id': id,
        'type': notification.type,
        'employee_id': notification.employeeId,
        'employee_name': notification.employeeName,
        'message': notification.message,
        'date': notification.date,
        'early_leave_count': notification.earlyLeaveCount,
        'is_read': notification.isRead ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      final rows = await _db.query(
        _table,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw const ApiException(LangKeys.errorUnknown);
      return AdminNotificationModel.fromJson(rows.first);
    });
  }

  Future<void> markAsRead(String id) async {
    return _guard(() async {
      await _db.update(
        _table,
        {'is_read': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// One statement instead of the per-document batch the Firestore version needed.
  Future<void> markAllAsRead() async {
    return _guard(() async {
      await _db.update(_table, {'is_read': 1}, where: 'is_read = 0');
    });
  }

  Future<bool> hasNotificationForEmployeeMonth(
    String employeeId,
    String yearMonth,
  ) async {
    return _guard(() async {
      final rows = await _db.query(
        _table,
        columns: ['id'],
        where: 'employee_id = ? AND type = ? AND date LIKE ?',
        whereArgs: [employeeId, 'early_leave_threshold', '$yearMonth-%'],
        limit: 1,
      );
      return rows.isNotEmpty;
    });
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on DatabaseException catch (e) {
      throw ApiException(LangKeys.errorDatabase, detail: e.toString());
    } catch (e) {
      throw ApiException(LangKeys.errorUnknown, detail: e.toString());
    }
  }
}
