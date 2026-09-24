import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../models/data_maintenance_models.dart';

/// Everything that reads, replaces or removes the database file as a whole.
///
/// The single-PC deployment is why this feature exists at all: there is no
/// server holding a second copy, so the backup is the only recovery there is —
/// and anything that deletes in bulk has to be answerable to it.
class BackupDataSource {
  final AppDatabase _database;

  BackupDataSource(this._database);

  /// Tables a full erase empties. `employees` goes last: deleting it cascades
  /// into attendance and permissions, and doing it first would make every
  /// count above it meaningless.
  static const _erasableTables = [
    'attendance_records',
    'permission_requests',
    'admin_notifications',
    'device_punches',
    'pending_employee_matches',
    'dismissed_device_users',
    'app_sequences',
    'employees',
  ];

  String get databasePath => _database.path;

  // ------------------------------------------------------------- backing up

  /// Writes a timestamped copy into the admin's Documents folder.
  Future<File> backupNow() async {
    try {
      final folder = Directory(await _backupFolder());
      await folder.create(recursive: true);

      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;

      return await _database.backupTo(
        p.join(folder.path, 'guardsync-$stamp.db'),
      );
    } catch (e) {
      throw ApiException(LangKeys.backupFailed, detail: e.toString());
    }
  }

  // -------------------------------------------------------------- restoring

  /// Asks which backup to restore. Null when the admin closed the dialog,
  /// which is an answer rather than a failure.
  Future<String?> pickBackupFile({
    required String typeLabel,
    String? confirmLabel,
  }) async {
    final file = await openFile(
      initialDirectory: await _existingBackupFolder(),
      confirmButtonText: confirmLabel,
      acceptedTypeGroups: [
        XTypeGroup(label: typeLabel, extensions: const ['db']),
      ],
    );
    return file?.path;
  }

  /// Replaces the live database with the backup at [path].
  ///
  /// Each refusal the database layer can raise becomes its own key. One
  /// "restore failed" covering four quite different causes — wrong file, newer
  /// build, damaged copy, missing tables — is the message that leaves an admin
  /// with nothing to try next.
  Future<void> restore(String path) async {
    try {
      await _database.restoreFrom(path);
    } on DatabaseRestoreException catch (e) {
      throw ApiException(switch (e.reason) {
        RestoreRefusal.unreadable => LangKeys.errorRestoreUnreadable,
        RestoreRefusal.notADatabase => LangKeys.errorRestoreNotDatabase,
        RestoreRefusal.tooNew => LangKeys.errorRestoreTooNew,
        RestoreRefusal.incomplete => LangKeys.errorRestoreIncomplete,
      }, detail: e.detail);
    } catch (e) {
      throw ApiException(LangKeys.errorRestoreUnreadable, detail: e.toString());
    }
  }

  // ------------------------------------------------------------ what's held

  Future<DataFootprint> footprint() async {
    try {
      final db = _database.db;
      return DataFootprint(
        employees: await _count(db, 'employees'),
        attendanceDays: await _count(db, 'attendance_records'),
        punches: await _count(db, 'device_punches'),
        permissions: await _count(db, 'permission_requests'),
        notifications: await _count(db, 'admin_notifications'),
        databaseBytes: await _fileSize(),
        oldestAttendanceDate: await _oldestAttendanceDate(db),
      );
    } catch (e) {
      throw ApiException(LangKeys.errorLoadFailed, detail: e.toString());
    }
  }

  // --------------------------------------------------------------- clearing

  /// Removes everything dated before [date] (`yyyy-MM-dd`, exclusive).
  ///
  /// Punches go with the attendance days they produced. They are the audit
  /// trail behind a re-fold or a correction, so keeping them would free almost
  /// nothing — the punch table is the bulk of the file — and days without their
  /// punches are a half-state worth nobody's time. The screen says so before
  /// this runs.
  Future<PurgeResult> purgeBefore(String date) async {
    try {
      final db = _database.db;
      final before = await _fileSize();

      late final int attendance;
      late final int punches;
      late final int permissions;
      late final int notifications;

      await db.transaction((txn) async {
        attendance = await txn.delete(
          'attendance_records',
          where: 'date < ?',
          whereArgs: [date],
        );
        permissions = await txn.delete(
          'permission_requests',
          where: 'date < ?',
          whereArgs: [date],
        );
        notifications = await txn.delete(
          'admin_notifications',
          where: 'date < ?',
          whereArgs: [date],
        );
        // punch_time is a full ISO timestamp. Compared against a bare date it
        // still orders correctly, the date being its own prefix.
        punches = await txn.delete(
          'device_punches',
          where: 'punch_time < ?',
          whereArgs: [date],
        );
      });

      // Outside the transaction, which SQLite requires, and the only reason
      // the file shrinks rather than merely holding free pages.
      await db.execute('VACUUM');

      final after = await _fileSize();
      return PurgeResult(
        attendanceRemoved: attendance,
        punchesRemoved: punches,
        permissionsRemoved: permissions,
        notificationsRemoved: notifications,
        bytesFreed: before > after ? before - after : 0,
      );
    } catch (e) {
      throw ApiException(LangKeys.errorDataClearFailed, detail: e.toString());
    }
  }

  /// Empties the staff list and everything hanging off it.
  ///
  /// Login accounts, departments, shifts and holidays are deliberately spared.
  /// Wiping `users` on a single-PC install with no server would lock the admin
  /// out of their own app with nothing to log back in with; the rest is
  /// configuration somebody spent an afternoon on and no part of "start the
  /// staff list again".
  Future<void> eraseOperationalData() async {
    try {
      final db = _database.db;
      await db.transaction((txn) async {
        for (final table in _erasableTables) {
          await txn.delete(table);
        }
      });
      await db.execute('VACUUM');
    } catch (e) {
      throw ApiException(LangKeys.errorDataClearFailed, detail: e.toString());
    }
  }

  // ---------------------------------------------------------------- helpers

  Future<String> _backupFolder() async {
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, 'GuardSync Backups');
  }

  /// Opens the picker where the backups actually are, falling back to
  /// Documents the first time, before one has ever been written.
  Future<String?> _existingBackupFolder() async {
    try {
      final folder = Directory(await _backupFolder());
      if (await folder.exists()) return folder.path;
      return (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      return null;
    }
  }

  static Future<int> _count(Database db, String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    return rows.isEmpty ? 0 : (rows.first['n'] as int? ?? 0);
  }

  static Future<String?> _oldestAttendanceDate(Database db) async {
    final rows = await db.rawQuery(
      'SELECT MIN(date) AS d FROM attendance_records',
    );
    return rows.isEmpty ? null : rows.first['d'] as String?;
  }

  Future<int> _fileSize() async {
    try {
      final file = File(_database.path);
      return await file.exists() ? await file.length() : 0;
    } catch (_) {
      return 0;
    }
  }
}
