import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_id.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/work_schedule.dart';
import '../models/shift_model.dart';
import '../models/shift_schedules.dart';

/// The working days the admin maintains, and the employees standing on them.
///
/// A shift is stored as an id on the employee, unlike a department, which is
/// stored as its name. The difference is that a department is a label every
/// report prints, while a shift is a set of rules nothing displays by name in
/// a record — so renaming one must not have to touch a single employee row,
/// and an id is the cheaper key.
///
/// Two consequences are this class's to handle, and nothing above it needs to
/// know about either:
///
///  * There is no foreign key (see the note on the `shifts` table in
///    [AppDatabase]), so deleting a shift releases the people on it here, in
///    the same transaction. Without that they would keep pointing at a shift
///    the admin can no longer see.
///  * Hours that cannot be worked are refused rather than stored. A shift
///    ending before it starts would quietly turn every one of its days into an
///    absence, and nothing downstream could tell that from a real one.
class ShiftsLocalDataSource {
  static const _shifts = 'shifts';
  static const _employees = 'employees';

  final AppDatabase _database;

  /// Reads the company default hours. A function rather than the settings data
  /// source itself: a shift only needs the current values to work out where
  /// its overtime window sits, and this keeps the dependency to one call a
  /// test can stand in for.
  final WorkSchedule Function()? _readCompanyDefault;

  ShiftsLocalDataSource(this._database, [this._readCompanyDefault]);

  Database get _db => _database.db;

  WorkSchedule get _companyDefault =>
      _readCompanyDefault?.call() ?? const WorkSchedule();

  /// Every shift, alphabetical, each with the number of employees on it.
  Future<List<ShiftModel>> getShifts() {
    return _guard(() async {
      final rows = await _db.rawQuery('''
        SELECT s.id,
               s.name,
               s.start_work,
               s.end_work,
               s.late_grace_minutes,
               s.early_out_grace_minutes,
               s.rest_days,
               (SELECT COUNT(*) FROM $_employees e WHERE e.shift_id = s.id)
                 AS in_use
          FROM $_shifts s
         ORDER BY s.start_work ASC, s.name COLLATE NOCASE ASC
      ''');
      return rows.map(ShiftModel.fromJson).toList();
    });
  }

  /// Every shift's hours in one object, for the screens that judge a month of
  /// records and cannot go back to the database per employee.
  Future<ShiftSchedules> getSchedules() {
    return _guard(() async {
      final companyDefault = _companyDefault;
      final shifts = await getShifts();
      return ShiftSchedules(
        companyDefault: companyDefault,
        byShiftId: {
          for (final shift in shifts)
            shift.id: shift.scheduleFrom(companyDefault),
        },
      );
    });
  }

  Future<ShiftModel> createShift(ShiftModel shift) {
    return _guard(() async {
      await _validate(shift, exceptId: null);

      final saved = ShiftModel(
        id: DbId.generate(),
        name: shift.name.trim(),
        startWork: shift.startWork,
        endWork: shift.endWork,
        lateGraceMinutes: shift.lateGraceMinutes,
        earlyOutGraceMinutes: shift.earlyOutGraceMinutes,
        restDays: shift.restDays,
      );

      await _db.insert(_shifts, {
        ...saved.toJson(),
        'created_at': DateTime.now().toIso8601String(),
      });

      return saved;
    });
  }

  Future<ShiftModel> updateShift(ShiftModel shift) {
    return _guard(() async {
      await _validate(shift, exceptId: shift.id);

      final saved = shift.copyWith(name: shift.name.trim());
      // The id addresses the row; writing it again would be a no-op at best.
      final values = saved.toJson()..remove('id');
      await _db.update(_shifts, values, where: 'id = ?', whereArgs: [saved.id]);

      return saved;
    });
  }

  /// Removes a shift and puts the people on it back on the company default.
  ///
  /// Deliberately not refused when somebody is on it. A shift being dropped is
  /// exactly when an admin needs to delete it, and blocking that until every
  /// employee has been moved by hand would mean editing them one at a time.
  /// They fall back to the default hours instead, which is a working day the
  /// app can still judge — [ShiftModel.inUse] is what tells the admin how many
  /// that will be before they confirm.
  Future<void> deleteShift(String id) {
    return _guard(() async {
      await _db.transaction((txn) async {
        await txn.update(
          _employees,
          {'shift_id': null, 'updated_at': DateTime.now().toIso8601String()},
          where: 'shift_id = ?',
          whereArgs: [id],
        );
        await txn.delete(_shifts, where: 'id = ?', whereArgs: [id]);
      });
    });
  }

  /// Refuses a shift that cannot be worked, or one whose name is already
  /// taken in any case — two spellings of a shift would be indistinguishable
  /// in the only place a shift is ever chosen.
  Future<void> _validate(ShiftModel shift, {required String? exceptId}) async {
    if (shift.name.trim().isEmpty) {
      throw const ApiException(LangKeys.errorShiftNameRequired);
    }
    if (!shift.scheduleFrom(_companyDefault).isValid) {
      throw const ApiException(LangKeys.errorShiftInvalidHours);
    }

    final rows = await _db.query(
      _shifts,
      columns: ['id'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [shift.name.trim()],
    );
    if (rows.any((row) => row['id'] != exceptId)) {
      throw const ApiException(LangKeys.errorShiftExists);
    }
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
