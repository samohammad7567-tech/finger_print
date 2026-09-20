import 'dart:ui';

import 'package:intl/intl.dart';

import '../style/theme/color_extension.dart';
import 'work_schedule.dart';

/// The hours used when a caller has not been handed the admin's schedule.
/// Only the app's own defaults — nothing reads the saved settings from here.
const kDefaultSchedule = WorkSchedule();

int timeToMinutes(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return 0;
  final parts = timeStr.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String minutesToTime(int mins) {
  final h = (mins ~/ 60).toString().padLeft(2, '0');
  final m = (mins % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

String getCurrentTime() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

String getTodayDate() {
  return DateFormat('yyyy-MM-dd').format(DateTime.now());
}

bool isThursday() => DateTime.now().weekday == DateTime.thursday;

String computeCheckInStatus(
  String checkInTime, {
  bool hasHousing = false,
  bool hasTravelPermission = false,
  WorkSchedule schedule = kDefaultSchedule,
}) => computeCheckInStatusOn(
  DateTime.now(),
  checkInTime,
  hasHousing: hasHousing,
  hasTravelPermission: hasTravelPermission,
  schedule: schedule,
);

/// The check-in rules evaluated against [day] rather than today, for the same
/// reason [computeCheckOutStatusOn] exists: the device sync folds punches from
/// any date and cannot ask today what weekday they fell on.
///
/// Arriving at or after the end of this person's own working day is an
/// absence. They did not work the day — turning up once it was over cannot
/// make it a late one. Anything they do from there is overtime, which the
/// report counts separately and only inside the overtime window.
String computeCheckInStatusOn(
  DateTime day,
  String checkInTime, {
  bool hasHousing = false,
  bool hasTravelPermission = false,
  WorkSchedule schedule = kDefaultSchedule,
}) {
  final arrival = timeToMinutes(checkInTime);
  final end = expectedWorkEndMinutes(
    day,
    hasHousing: hasHousing,
    hasTravelPermission: hasTravelPermission,
    schedule: schedule,
  );

  if (arrival >= end) return 'absent';
  // The shift may forgive a few minutes' lateness; arriving inside that is an
  // ordinary day, not a late one.
  return arrival <= schedule.latestOnTimeArrivalMinutes ? 'present' : 'late';
}

bool isEarlyCheckout(
  String checkOutTime, {
  bool hasHousing = false,
  bool hasTravelPermission = false,
  WorkSchedule schedule = kDefaultSchedule,
}) => isEarlyCheckoutOn(
  DateTime.now(),
  checkOutTime,
  hasHousing: hasHousing,
  hasTravelPermission: hasTravelPermission,
  schedule: schedule,
);

String computeCheckOutStatus(
  String checkOutTime, {
  bool hasHousing = false,
  bool hasTravelPermission = false,
  WorkSchedule schedule = kDefaultSchedule,
}) => computeCheckOutStatusOn(
  DateTime.now(),
  checkOutTime,
  hasHousing: hasHousing,
  hasTravelPermission: hasTravelPermission,
  schedule: schedule,
);

/// The check-out rules evaluated against [day] rather than today.
///
/// The device sync folds punches from any date, including a backlog pulled
/// after a weekend, so it cannot use today's weekday to decide whether the
/// Thursday travel allowance applied.
String computeCheckOutStatusOn(
  DateTime day,
  String checkOutTime, {
  bool hasHousing = false,
  bool hasTravelPermission = false,
  WorkSchedule schedule = kDefaultSchedule,
}) {
  final checkout = timeToMinutes(checkOutTime);
  // Judged against the accepted line rather than the true end of the day, so
  // the allowance the shift grants is honoured here and nowhere else — paid
  // time and overtime still stop at the real end.
  final end = acceptedLeaveMinutes(
    day,
    hasHousing: hasHousing,
    hasTravelPermission: hasTravelPermission,
    schedule: schedule,
  );

  if (hasTravelPermission && day.weekday == DateTime.thursday) {
    return checkout >= end ? 'travel_permission' : 'early_leave';
  }
  return checkout >= end ? 'present' : 'early_leave';
}

/// What one day reads as, from the pair of times it was worked between.
///
/// The device fold and an admin's correction both come through here, so a day
/// means the same thing however the times reached the record.
String computeDayStatus({
  required DateTime day,
  required String? checkIn,
  required String? checkOut,
  bool hasHousing = false,
  bool hasTravelPermission = false,
  WorkSchedule schedule = kDefaultSchedule,
}) {
  if (checkIn == null || checkIn.isEmpty) return 'pending';

  final arriving = computeCheckInStatusOn(
    day,
    checkIn,
    hasHousing: hasHousing,
    hasTravelPermission: hasTravelPermission,
    schedule: schedule,
  );

  // Turning up only after the working day was over means the day itself was
  // missed, whatever they did afterwards. Their departure cannot undo that,
  // and the hours they put in are read as overtime rather than attendance.
  if (arriving == 'absent') return 'absent';
  if (checkOut == null || checkOut.isEmpty) return arriving;

  final leaving = computeCheckOutStatusOn(
    day,
    checkOut,
    hasHousing: hasHousing,
    hasTravelPermission: hasTravelPermission,
    schedule: schedule,
  );

  // Arriving late is the more significant fact about the day, so it survives a
  // normal departure. An early leave still overrides it.
  if (leaving == 'present' && arriving == 'late') return 'late';
  return leaving;
}

/// [isEarlyCheckout] evaluated against [day] rather than today.
bool isEarlyCheckoutOn(
  DateTime day,
  String checkOutTime, {
  bool hasHousing = false,
  bool hasTravelPermission = false,
  WorkSchedule schedule = kDefaultSchedule,
}) =>
    timeToMinutes(checkOutTime) <
    acceptedLeaveMinutes(
      day,
      hasHousing: hasHousing,
      hasTravelPermission: hasTravelPermission,
      schedule: schedule,
    );

/// When this person's working day is scheduled to end, in minutes from
/// midnight. Housing and the Thursday travel allowance move it earlier.
///
/// The true end of the day: where paid work stops, where overtime opens from,
/// and the line an arrival is judged an absence against. A *departure* is
/// measured against [acceptedLeaveMinutes] instead.
int expectedWorkEndMinutes(
  DateTime day, {
  bool hasHousing = false,
  bool hasTravelPermission = false,
  WorkSchedule schedule = kDefaultSchedule,
}) => schedule.endOfDayMinutes(
  day,
  hasHousing: hasHousing,
  hasTravelPermission: hasTravelPermission,
);

/// The earliest this person may leave without it reading as an early leave:
/// the end of their day less the allowance their shift grants.
///
/// Identical to [expectedWorkEndMinutes] on a schedule that grants none, which
/// is every schedule until an admin sets up a shift — so nothing about an
/// existing install changes by this being here.
int acceptedLeaveMinutes(
  DateTime day, {
  bool hasHousing = false,
  bool hasTravelPermission = false,
  WorkSchedule schedule = kDefaultSchedule,
}) => schedule.earliestOnTimeLeaveMinutes(
  day,
  hasHousing: hasHousing,
  hasTravelPermission: hasTravelPermission,
);

String formatDateLocalized(String? dateStr, {bool isArabic = false}) {
  if (dateStr == null || dateStr.isEmpty) return '';
  final d = DateTime.tryParse(dateStr);
  if (d == null) return dateStr;
  final locale = isArabic ? 'ar' : 'en';
  return DateFormat('EEEE, d MMMM yyyy', locale).format(d);
}

String? calcWorkingHours(String? checkIn, String? checkOut) {
  if (checkIn == null || checkOut == null) return null;
  final diff = timeToMinutes(checkOut) - timeToMinutes(checkIn);
  if (diff <= 0) return null;
  final h = diff ~/ 60;
  final m = diff % 60;
  return '${h}h ${m}m';
}

enum AttendanceStatus {
  present,
  late,
  absent,
  earlyLeave,
  travelPermission,
  pending,
}

AttendanceStatus parseStatus(String? status) {
  switch (status) {
    case 'present':
      return AttendanceStatus.present;
    case 'late':
      return AttendanceStatus.late;
    case 'absent':
      return AttendanceStatus.absent;
    case 'early_leave':
      return AttendanceStatus.earlyLeave;
    case 'travel_permission':
      return AttendanceStatus.travelPermission;
    default:
      return AttendanceStatus.pending;
  }
}

/// What kind of day a date is for one person, before anybody's punches are
/// looked at.
///
/// The calendar decides this: a weekly rest day comes from their schedule, a
/// public holiday from the company's holiday list. It is the question that has
/// to be answered *first* — judging somebody late for a Friday they were never
/// expected to work is nonsense, and counting that Friday as an absence is
/// worse.
enum WorkingDayKind {
  /// An ordinary working day. What every date was before the calendar existed.
  working,

  /// A weekly rest day for this person's schedule.
  restDay,

  /// A company holiday. Outranks a rest day when a holiday lands on one, so a
  /// day off is named by the reason it is off.
  holiday,
}

/// True when this kind of day is one somebody was expected to work.
bool isWorkingDay(WorkingDayKind kind) => kind == WorkingDayKind.working;

/// Everything unusual about one day, rather than the single word it collapses
/// to.
///
/// [computeDayStatus] has to answer with one status, because that is what the
/// `status` column holds and what every existing screen reads. Answering with
/// one word means losing the others: somebody who arrived late *and* left
/// early is stored as an early leave, and the lateness is gone. These are the
/// facts that word threw away, worked out again from the times whenever a day
/// is displayed — so a record folded under any older rule reads correctly
/// without being re-synced.
enum AttendanceFlag {
  /// Arrived after the start of their day, past whatever their shift forgives.
  arrivedLate,

  /// Left before the end of their day, past whatever their shift forgives.
  leftEarly,

  /// Did not work the day at all — no scans, or a first scan after it ended.
  absent,

  /// Scanned in and never scanned out.
  missingCheckOut,

  /// Left mid-day and never scanned back in.
  openBreak,

  /// The punches were edited by hand by an admin.
  corrected,

  /// They worked on their weekly rest day.
  workedRestDay,

  /// They worked on a company holiday.
  workedHoliday,
}

/// The label for one flag.
///
/// The first three reuse the status labels they came from, so a day reading
/// "Late" means the same word wherever it is shown. Split from the colour so
/// the exporters — which have no theme to read — can still name a day.
String flagLabelKey(AttendanceFlag flag) => switch (flag) {
  AttendanceFlag.arrivedLate => 'late',
  AttendanceFlag.leftEarly => 'early_leave',
  AttendanceFlag.absent => 'absent',
  AttendanceFlag.missingCheckOut => 'flag_missing_checkout',
  AttendanceFlag.openBreak => 'flag_open_break',
  AttendanceFlag.corrected => 'flag_corrected',
  AttendanceFlag.workedRestDay => 'flag_rest_day',
  AttendanceFlag.workedHoliday => 'flag_holiday',
};

/// The label and colour for one flag, resolved against the active palette.
({String labelKey, Color color}) getFlagDisplay(
  AttendanceFlag flag,
  MyColors colors,
) => (
  labelKey: flagLabelKey(flag),
  color: switch (flag) {
    AttendanceFlag.arrivedLate => colors.warning,
    AttendanceFlag.leftEarly => colors.warningSoft,
    AttendanceFlag.absent => colors.destructive,
    AttendanceFlag.missingCheckOut => colors.destructive,
    AttendanceFlag.openBreak => colors.warningSoft,
    AttendanceFlag.corrected => colors.infoSoft,
    AttendanceFlag.workedRestDay => colors.info,
    AttendanceFlag.workedHoliday => colors.info,
  },
);

/// The label a day off is shown under when nobody scanned on it at all.
///
/// The monthly workbook prints a line for every date, including the ones
/// nobody worked. Saying "Rest day" there rather than "Not recorded" is the
/// difference between a file that explains itself and one that looks like it
/// lost some rows.
String dayKindLabelKey(WorkingDayKind kind) {
  switch (kind) {
    case WorkingDayKind.restDay:
      return 'flag_rest_day';
    case WorkingDayKind.holiday:
      return 'flag_holiday';
    case WorkingDayKind.working:
      return 'not_recorded';
  }
}

/// The labels a day should be shown under, in order.
///
/// The flags when there are any, and otherwise the single status it reads as —
/// an ordinary day still says "Present", and a day nobody scanned still says
/// "Not recorded". Keys rather than words: the exporters have no business
/// knowing the language, so translation stays with whoever is displaying them.
List<String> statusLabelKeys({
  required List<AttendanceFlag> flags,
  required String status,
}) => flags.isEmpty
    ? [statusLabelKey(parseStatus(status))]
    : [for (final flag in flags) flagLabelKey(flag)];

/// The label one status reads as, with no theme involved.
String statusLabelKey(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => 'present',
  AttendanceStatus.late => 'late',
  AttendanceStatus.absent => 'absent',
  AttendanceStatus.earlyLeave => 'early_leave',
  AttendanceStatus.travelPermission => 'travel_permission',
  AttendanceStatus.pending => 'not_recorded',
};

/// The label and colour for one status, resolved against the active palette.
({String labelKey, Color color}) getStatusDisplay(
  AttendanceStatus status,
  MyColors colors,
) => (
  labelKey: statusLabelKey(status),
  color: switch (status) {
    AttendanceStatus.present => colors.success,
    AttendanceStatus.late => colors.warning,
    AttendanceStatus.absent => colors.destructive,
    AttendanceStatus.earlyLeave => colors.warningSoft,
    AttendanceStatus.travelPermission => colors.infoSoft,
    AttendanceStatus.pending => colors.subtleForeground,
  },
);
