import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_id.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/utils/work_schedule.dart';
import '../../../holidays/data/models/holiday_model.dart';
import '../../../holidays/data/models/work_calendar.dart';
import '../../../shifts/data/models/shift_model.dart';

/// What one run of the closing pass did, so a caller can say so rather than
/// guess.
class DayClosingResult {
  /// Working days that were examined and marked finished.
  final int daysClosed;

  /// Absence records written across them.
  final int absencesRecorded;

  /// Days passed over because nothing at all was recorded on them — see
  /// [DayClosingDataSource.closeThrough].
  final int daysSkipped;

  /// The last date the pass got through, or null when it did nothing.
  final String? closedThrough;

  const DayClosingResult({
    this.daysClosed = 0,
    this.absencesRecorded = 0,
    this.daysSkipped = 0,
    this.closedThrough,
  });

  bool get didNothing => daysClosed == 0 && daysSkipped == 0;
}

/// Writes down the days people were not here.
///
/// Until this existed, an absence produced no row at all: the device fold only
/// creates a record when there are punches to fold, so somebody who simply did
/// not come in was indistinguishable from somebody the system had no data for
/// yet. Every absence figure in the app was really "absences among people who
/// scanned something", which is not the question anybody was asking.
///
/// The pass is deliberately conservative. It only ever *adds* a row where
/// there is none, so it can never overwrite a punch, a manual entry or an
/// admin's correction — and re-running it is free.
class DayClosingDataSource {
  static const _attendance = 'attendance_records';
  static const _employees = 'employees';
  static const _punches = 'device_punches';
  static const _permissions = 'permission_requests';

  /// Marks a row this pass wrote, so it is distinguishable from an absence an
  /// admin entered by hand and from anything the terminal produced.
  static const source = 'system';

  final AppDatabase _database;

  /// Reads the company default hours, for employees on no shift.
  final WorkSchedule Function()? _readCompanyDefault;

  DayClosingDataSource(this._database, [this._readCompanyDefault]);

  Database get _db => _database.db;

  /// Records an absence for everybody who was expected on a working day and
  /// left no trace of it.
  ///
  /// Runs over the finished days from [from] to [to] inclusive — never today,
  /// because somebody may still be about to scan.
  ///
  /// A date where **nothing at all** was recorded for anybody is skipped
  /// rather than closed. A whole workforce absent on the same day is far more
  /// likely to mean the app was not running or the terminal was unreachable
  /// than that nobody came in, and inventing a company-wide absence from an
  /// outage is the one mistake this must not make.
  ///
  /// Also passed over, per employee: anybody added after the date in question,
  /// anybody whose own schedule rests then, and anybody on approved leave.
  Future<DayClosingResult> closeThrough({
    required String from,
    required String to,
    required WorkCalendar calendar,
  }) async {
    return _guard(() async {
      final start = DateTime.tryParse(from);
      final end = DateTime.tryParse(to);
      if (start == null || end == null || end.isBefore(start)) {
        return const DayClosingResult();
      }

      final companyDefault = _readCompanyDefault?.call() ?? kDefaultSchedule;

      var closed = 0;
      var skipped = 0;
      var written = 0;
      String? through;

      for (
        var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      ) {
        final date = HolidayModel.isoDate(day);

        // The marker moves past a skipped day too: revisiting it on every
        // launch would re-run the same queries forever for a day that is only
        // going to look the same. Punches arriving later still land through
        // the fold, which widens a row rather than needing this pass.
        through = date;

        if (!await _anythingRecordedOn(date)) {
          skipped++;
          continue;
        }

        written += await _closeDay(date, day, calendar, companyDefault);
        closed++;
      }

      return DayClosingResult(
        daysClosed: closed,
        absencesRecorded: written,
        daysSkipped: skipped,
        closedThrough: through,
      );
    });
  }

  /// True when anybody left any trace on [date] — a punch off the terminal or
  /// a record somebody entered. Its absence means the day has no evidence
  /// either way, which is not the same as evidence of absence.
  Future<bool> _anythingRecordedOn(String date) async {
    final punches = await _db.rawQuery(
      'SELECT 1 FROM $_punches WHERE punch_time LIKE ? LIMIT 1',
      ['$date%'],
    );
    if (punches.isNotEmpty) return true;

    final records = await _db.rawQuery(
      'SELECT 1 FROM $_attendance WHERE date = ? LIMIT 1',
      [date],
    );
    return records.isNotEmpty;
  }

  /// Writes the absences for one date. Returns how many were written.
  Future<int> _closeDay(
    String date,
    DateTime day,
    WorkCalendar calendar,
    WorkSchedule companyDefault,
  ) async {
    // Everybody who could still be marked absent for this date. The three
    // exclusions are done in SQL rather than in Dart because each of them can
    // rule out most of the workforce on a given day, and this runs per date.
    final rows = await _db.rawQuery(
      '''
      SELECT e.id,
             s.start_work, s.end_work,
             s.late_grace_minutes, s.early_out_grace_minutes, s.rest_days
        FROM $_employees e
        LEFT JOIN shifts s ON s.id = e.shift_id
       WHERE e.is_active = 1
         -- Nobody is absent from a day before they were on file.
         AND substr(e.created_at, 1, 10) <= ?
         -- A day already accounted for is never touched.
         AND NOT EXISTS (
               SELECT 1 FROM $_attendance a
                WHERE a.employee_id = e.id AND a.date = ?)
         -- Approved leave is the opposite of an unexplained absence.
         AND NOT EXISTS (
               SELECT 1 FROM $_permissions p
                WHERE p.employee_id = e.id
                  AND p.date = ?
                  AND p.status = 'approved'
                  AND p.permission_type = 'vacation')
    ''',
      [date, date, date],
    );

    if (rows.isEmpty) return 0;

    final now = DateTime.now().toIso8601String();
    final batch = _db.batch();
    var written = 0;

    for (final row in rows) {
      // Their own working week, which is why the shift is joined in above:
      // the evening shift may rest on days the morning shift works.
      final schedule = ShiftModel.scheduleFromRow(row, companyDefault);
      if (!isWorkingDay(calendar.kindOf(day, schedule))) continue;

      batch.insert(_attendance, {
        'id': DbId.generate(),
        'employee_id': row['id'] as String,
        'date': date,
        'status': 'absent',
        'is_early_leave': 0,
        'source': source,
        'created_at': now,
        'updated_at': now,
      });
      written++;
    }

    if (written == 0) return 0;

    // continueOnError so one row losing a race with a sync writing the same
    // day cannot discard the rest of the batch. The unique index on
    // (employee_id, date) is what makes that safe to ignore.
    await batch.commit(noResult: true, continueOnError: true);
    return written;
  }

  /// Removes the rows this pass wrote over a date range, for an admin undoing
  /// a closing that ran against a misconfigured calendar.
  ///
  /// Only ever touches rows carrying [source], so a real punch, a manual entry
  /// and a correction are all untouchable by it.
  Future<int> reopenRange(String from, String to) {
    return _guard(() async {
      return _db.delete(
        _attendance,
        // Belt and braces on top of the source check: a row carrying times is
        // never one of these, whatever its source column says.
        where:
            'date >= ? AND date <= ? AND source = ? '
            'AND check_in_time IS NULL AND check_out_time IS NULL',
        whereArgs: [from, to, source],
      );
    });
  }

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
