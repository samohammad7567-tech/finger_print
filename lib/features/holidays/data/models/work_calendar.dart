import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/utils/work_schedule.dart';
import 'holiday_model.dart';

/// Which dates anybody was expected to work, read once so a screen can judge a
/// whole month without going back to the database per day.
///
/// This is the question that has to be answered before any punch is looked at.
/// Judging somebody late for a Friday they never work is nonsense, and counting
/// that Friday against them is worse — so every screen that reads a day asks
/// this first, and they all ask the same object.
///
/// The two halves come from different places on purpose. A **rest day** is a
/// property of the schedule somebody works, so it lives on their shift and can
/// differ between them — the evening shift may rest on different days from the
/// morning one. A **holiday** is a property of the date itself and applies to
/// everybody, whichever shift they are on.
class WorkCalendar {
  /// Every holiday on file. Small enough to hold — a company has a handful a
  /// year, and scanning them beats a query per date by a wide margin.
  final List<HolidayModel> holidays;

  const WorkCalendar({this.holidays = const []});

  /// The holiday covering [date], or null. [date] is 'yyyy-MM-dd'.
  ///
  /// The first match wins when ranges overlap, which they should not but might
  /// — an admin entering Eid twice should not break a report.
  HolidayModel? holidayOn(String date) {
    for (final holiday in holidays) {
      if (holiday.covers(date)) return holiday;
    }
    return null;
  }

  /// What kind of day this is for somebody on [schedule].
  ///
  /// A holiday outranks a rest day when the two land together, so a day off is
  /// named by the reason it is off rather than by whichever check ran first.
  WorkingDayKind kindOf(DateTime day, WorkSchedule schedule) {
    if (holidayOn(HolidayModel.isoDate(day)) != null) {
      return WorkingDayKind.holiday;
    }
    if (schedule.isRestDay(day)) return WorkingDayKind.restDay;
    return WorkingDayKind.working;
  }

  /// [kindOf] for a stored date string, which is how records carry theirs.
  /// An unparseable date is treated as a working day: it is the answer that
  /// changes nothing, and a bad date is a different problem from a calendar.
  WorkingDayKind kindOfDate(String date, WorkSchedule schedule) {
    final day = DateTime.tryParse(date);
    return day == null ? WorkingDayKind.working : kindOf(day, schedule);
  }

  /// True when nobody has set up any calendar at all, so every date is a
  /// working day. What every install looked like before this existed.
  bool get isEmpty => holidays.isEmpty;
}
