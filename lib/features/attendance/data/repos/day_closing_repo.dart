import '../../../holidays/data/models/holiday_model.dart';
import '../../../holidays/data/repos/holidays_repo.dart';
import '../../../settings/data/data_source/settings_local_data_source.dart';
import '../data_source/day_closing_data_source.dart';

/// Decides which days still need closing, and remembers how far the app has
/// got.
///
/// The marker is the whole reason this sits above the data source: without one
/// the pass would rescan every day the company has ever worked on each launch,
/// and with one it does a few queries and stops.
class DayClosingRepo {
  /// How far back a first run will reach.
  ///
  /// Bounded because an install that has been collecting punches for a year
  /// should not spend its first launch after the update writing a year of
  /// absences. Two months covers the current payroll month and the one before
  /// it, which is as far back as anybody disputes.
  ///
  /// In practice the data source's own guard does most of the work: a date
  /// with no punches and no records at all is skipped, so the days before this
  /// app was in use cost a query each and write nothing.
  static const firstRunLookbackDays = 62;

  final DayClosingDataSource _dataSource;
  final HolidaysRepo _holidays;
  final SettingsLocalDataSource _settings;

  DayClosingRepo(this._dataSource, this._holidays, this._settings);

  /// Closes every finished working day the app has not closed yet.
  ///
  /// Never closes today: somebody may still be about to scan, and a day marked
  /// absent at nine in the morning would be wrong for the rest of it.
  ///
  /// Safe to call as often as you like — it is bounded by the marker and the
  /// data source only ever adds rows where none exist.
  Future<DayClosingResult> closeFinishedDays({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final end = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));

    final start = _startFrom(end);
    if (start.isAfter(end)) return const DayClosingResult();

    final result = await _dataSource.closeThrough(
      from: HolidayModel.isoDate(start),
      to: HolidayModel.isoDate(end),
      calendar: await _holidays.getCalendar(),
    );

    final through = result.closedThrough;
    if (through != null) await _settings.setClosedThrough(through);

    return result;
  }

  /// Deletes the absences this pass wrote across a range and rewinds the
  /// marker, so a closing that ran against a calendar the admin had not
  /// finished setting up can be undone and redone.
  Future<int> reopenRange(String from, String to) async {
    final removed = await _dataSource.reopenRange(from, to);

    // Rewind only if the marker is inside or past the reopened range —
    // otherwise the days just cleared would never be revisited.
    final marker = _settings.getClosedThrough();
    if (marker != null && marker.compareTo(from) >= 0) {
      final before = DateTime.tryParse(from)?.subtract(const Duration(days: 1));
      if (before != null) {
        await _settings.setClosedThrough(HolidayModel.isoDate(before));
      }
    }

    return removed;
  }

  /// The day after the marker, or the bounded lookback on a first run.
  DateTime _startFrom(DateTime end) {
    final marker = DateTime.tryParse(_settings.getClosedThrough() ?? '');
    if (marker != null) return marker.add(const Duration(days: 1));
    return end.subtract(const Duration(days: firstRunLookbackDays));
  }
}
