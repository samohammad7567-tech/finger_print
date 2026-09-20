import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/work_schedule.dart';

/// Where the company's working hours are kept.
///
/// Preferences rather than the database, and [read] is synchronous, because the
/// device fold consults the schedule for every day it rebuilds — it cannot stop
/// to await storage in the middle of a sync.
class WorkScheduleLocalDataSource {
  static const _workStart = 'schedule_work_start';
  static const _workEnd = 'schedule_work_end';
  static const _overtimeStart = 'schedule_overtime_start';
  static const _overtimeEnd = 'schedule_overtime_end';
  static const _restDays = 'schedule_rest_days';

  final SharedPreferences _prefs;

  WorkScheduleLocalDataSource(this._prefs);

  WorkSchedule read() {
    const defaults = WorkSchedule();
    return WorkSchedule(
      workStart: _prefs.getString(_workStart) ?? defaults.workStart,
      workEnd: _prefs.getString(_workEnd) ?? defaults.workEnd,
      overtimeStart: _prefs.getString(_overtimeStart) ?? defaults.overtimeStart,
      overtimeEnd: _prefs.getString(_overtimeEnd) ?? defaults.overtimeEnd,
      restDays: WorkSchedule.parseRestDays(_prefs.getString(_restDays)),
    );
  }

  Future<void> write(WorkSchedule schedule) async {
    await _prefs.setString(_workStart, schedule.workStart);
    await _prefs.setString(_workEnd, schedule.workEnd);
    await _prefs.setString(_overtimeStart, schedule.overtimeStart);
    await _prefs.setString(_overtimeEnd, schedule.overtimeEnd);
    await _prefs.setString(
      _restDays,
      WorkSchedule.encodeRestDays(schedule.restDays),
    );
  }
}
