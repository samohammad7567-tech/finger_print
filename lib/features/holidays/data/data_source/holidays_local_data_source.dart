import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_id.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../models/holiday_model.dart';
import '../models/work_calendar.dart';

/// The company's holiday calendar.
///
/// Deliberately permissive about overlaps: two entries covering the same date
/// is untidy but harmless — [WorkCalendar] takes the first — and refusing it
/// would block the ordinary case of a shutdown that swallows a public holiday.
/// What is refused is a range that cannot exist, because a holiday ending
/// before it starts would silently cover no days at all and the admin would
/// think they had entered it.
class HolidaysLocalDataSource {
  static const _table = 'holidays';

  final AppDatabase _database;

  HolidaysLocalDataSource(this._database);

  Database get _db => _database.db;

  /// Every holiday, soonest first.
  Future<List<HolidayModel>> getHolidays() {
    return _guard(() async {
      final rows = await _db.query(_table, orderBy: 'start_date DESC');
      return rows.map(HolidayModel.fromJson).toList();
    });
  }

  /// The calendar the reports judge dates against.
  ///
  /// Every holiday rather than a date range: a company has a handful a year,
  /// so holding them all costs nothing and saves the caller from having to
  /// know which range it is about to need.
  Future<WorkCalendar> getCalendar() {
    return _guard(() async => WorkCalendar(holidays: await getHolidays()));
  }

  Future<HolidayModel> createHoliday(HolidayModel holiday) {
    return _guard(() async {
      _validate(holiday);

      final saved = HolidayModel(
        id: DbId.generate(),
        name: holiday.name.trim(),
        startDate: holiday.startDate,
        endDate: holiday.endDate,
        isPaid: holiday.isPaid,
      );

      await _db.insert(_table, {
        ...saved.toJson(),
        'created_at': DateTime.now().toIso8601String(),
      });

      return saved;
    });
  }

  Future<HolidayModel> updateHoliday(HolidayModel holiday) {
    return _guard(() async {
      _validate(holiday);

      final saved = holiday.copyWith(name: holiday.name.trim());
      // The id addresses the row; writing it again would be a no-op at best.
      final values = saved.toJson()..remove('id');
      await _db.update(_table, values, where: 'id = ?', whereArgs: [saved.id]);

      return saved;
    });
  }

  /// Removes a holiday. Nothing else points at one — the calendar is consulted
  /// by date, never stored on a record — so there is nothing to release.
  Future<void> deleteHoliday(String id) {
    return _guard(() async {
      await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
    });
  }

  static void _validate(HolidayModel holiday) {
    if (holiday.name.trim().isEmpty) {
      throw const ApiException(LangKeys.errorHolidayNameRequired);
    }
    if (holiday.start == null || holiday.end == null || holiday.dayCount < 1) {
      throw const ApiException(LangKeys.errorHolidayInvalidRange);
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
