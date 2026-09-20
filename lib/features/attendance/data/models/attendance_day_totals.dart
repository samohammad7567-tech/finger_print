import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/utils/work_schedule.dart';
import 'attendance_record_model.dart';
import 'employee_model.dart';

/// What one stored day comes to once the admin's working hours are applied to
/// it: time worked, time on break, time earned as overtime, and whether the
/// working day was missed altogether.
///
/// Every screen that judges a day goes through this, so the punch report, the
/// monthly summary and the exports can never disagree about the same record.
class AttendanceDayTotals {
  final AttendanceRecordModel record;

  /// The hours this day is judged against. Carried here so every figure —
  /// worked, break, overtime — comes from the same schedule.
  final WorkSchedule schedule;

  /// When this person's day was scheduled to end, on this record's date.
  /// Housing and the Thursday travel allowance move it earlier.
  final int endOfDayMinutes;

  /// Whether this date was one they were expected to work at all.
  ///
  /// Defaults to [WorkingDayKind.working], which is what every date was before
  /// the calendar existed — so a caller that has not been handed one reads
  /// exactly as it always did.
  final WorkingDayKind dayKind;

  const AttendanceDayTotals({
    required this.record,
    required this.schedule,
    required this.endOfDayMinutes,
    this.dayKind = WorkingDayKind.working,
  });

  /// The usual way in: the end of the day is worked out from the employee's
  /// own allowances and the date on the record.
  factory AttendanceDayTotals.forEmployee({
    required AttendanceRecordModel record,
    required EmployeeModel employee,
    WorkSchedule schedule = const WorkSchedule(),
    WorkingDayKind dayKind = WorkingDayKind.working,
  }) {
    final day = DateTime.tryParse(record.date) ?? DateTime.now();
    return AttendanceDayTotals(
      record: record,
      schedule: schedule,
      endOfDayMinutes: schedule.endOfDayMinutes(
        day,
        hasHousing: employee.hasHousing,
        hasTravelPermission: employee.hasTravelPermission,
      ),
      dayKind: dayKind,
    );
  }

  /// The date this day is for.
  DateTime get day => DateTime.tryParse(record.date) ?? DateTime.now();

  /// Every break of the day.
  ///
  /// Days folded before the app kept a list still carry only the first
  /// departure and the last return, so those are read as the single break they
  /// were recorded as rather than showing nothing.
  List<AttendanceBreak> get breaks {
    if (record.breaks.isNotEmpty) return record.breaks;
    final out = record.breakOutTime;
    if (out == null || out.isEmpty) return const [];
    return [AttendanceBreak(out: out, backIn: record.breakInTime)];
  }

  /// Time away on breaks — every closed one of them, not just the first.
  Duration get breakTime =>
      breaks.fold(Duration.zero, (sum, b) => sum + (b.length ?? Duration.zero));

  /// True when they first scanned at or after the end of their own working
  /// day: they missed the day entirely, whatever they did afterwards.
  ///
  /// The day is an absence either way. What they work from here can still earn
  /// overtime — see [overtime] — but none of it is attendance.
  bool get isAbsentArrival {
    // Nobody can miss a day they were never expected to work. Without this a
    // Friday scan would read as an absence purely because it fell outside
    // hours the person does not work that day.
    if (!isWorkingDay(dayKind)) return false;
    final arrival = _minutes(record.checkInTime);
    return arrival != null && arrival >= endOfDayMinutes;
  }

  /// The status the day reads as: the stored one, unless the times say the
  /// working day was missed.
  ///
  /// Deriving it rather than trusting the column means a day folded under
  /// older rules reads correctly on screen straight away, without waiting for
  /// a re-sync to rewrite it.
  String get status => isAbsentArrival ? 'absent' : record.status;

  /// The earliest they could have left without it reading as an early leave:
  /// the end of their day, less what their shift forgives.
  ///
  /// Derived from [endOfDayMinutes] rather than recomputed from the employee,
  /// so the allowance is applied to the same end-of-day the rest of this class
  /// measures against — housing and the Thursday travel hour included.
  int get acceptedLeaveMinutes {
    final accepted = endOfDayMinutes - schedule.earlyOutGraceMinutes;
    return accepted < 0 ? 0 : accepted;
  }

  /// Everything unusual about this day, rather than the one word [status]
  /// collapses to.
  ///
  /// A day can be several things at once, and the stored status can only be
  /// one of them — somebody late in *and* early out is filed as an early
  /// leave, and nothing downstream can tell they were also late. This works
  /// the facts out again from the times, so both survive.
  ///
  /// An empty list means an ordinary day. Order is fixed rather than
  /// incidental: arrival, departure, then what was odd about the middle, so a
  /// row of chips reads the same way every time.
  List<AttendanceFlag> get flags {
    final result = <AttendanceFlag>[];

    final arrival = _minutes(record.checkInTime);
    final departure = _minutes(record.checkOutTime);

    // A day that was missed is only that. Calling it late as well would be
    // describing an arrival that never counted, and a missing check-out on a
    // day nobody worked is not news.
    // A rest day or a holiday is named for what it is, and none of the
    // schedule judgements below apply — there were no hours to be late for.
    // Work done on one still shows its times; whether it is paid as overtime
    // is a payroll decision this does not make.
    if (!isWorkingDay(dayKind)) {
      result.add(
        dayKind == WorkingDayKind.holiday
            ? AttendanceFlag.workedHoliday
            : AttendanceFlag.workedRestDay,
      );
      if (breaks.any((b) => !b.isClosed)) result.add(AttendanceFlag.openBreak);
      if (record.isCorrected) result.add(AttendanceFlag.corrected);
      return result;
    }

    final missed = isAbsentArrival || record.status == 'absent';

    if (missed) {
      result.add(AttendanceFlag.absent);
    } else {
      if (arrival != null && arrival > schedule.latestOnTimeArrivalMinutes) {
        result.add(AttendanceFlag.arrivedLate);
      }
      if (departure != null && departure < acceptedLeaveMinutes) {
        result.add(AttendanceFlag.leftEarly);
      }
      // Only once they have actually turned up: a day with no scans at all is
      // "not recorded", not a missing departure.
      if (arrival != null && departure == null) {
        result.add(AttendanceFlag.missingCheckOut);
      }
    }

    if (breaks.any((b) => !b.isClosed)) result.add(AttendanceFlag.openBreak);
    if (record.isCorrected) result.add(AttendanceFlag.corrected);

    return result;
  }

  /// How late they were, in minutes past the last moment that still counted as
  /// on time. Zero when they were not late.
  ///
  /// Measured from the accepted line rather than the shift's start, so a
  /// company forgiving ten minutes does not then count those ten minutes
  /// against anybody. This is the figure a month's lateness is summed from.
  int get lateMinutes {
    if (!flags.contains(AttendanceFlag.arrivedLate)) return 0;
    final arrival = _minutes(record.checkInTime);
    if (arrival == null) return 0;
    final over = arrival - schedule.latestOnTimeArrivalMinutes;
    return over > 0 ? over : 0;
  }

  /// How early they left, in minutes before the earliest acceptable
  /// departure. Zero when they did not leave early.
  int get earlyOutMinutes {
    if (!flags.contains(AttendanceFlag.leftEarly)) return 0;
    final departure = _minutes(record.checkOutTime);
    if (departure == null) return 0;
    final under = acceptedLeaveMinutes - departure;
    return under > 0 ? under : 0;
  }

  /// True when there is something about this day worth an admin's attention.
  ///
  /// A day off that was worked is not an issue — it is a fact, and one the
  /// flags still record.
  bool get hasIssue => flags.any(
    (flag) =>
        flag != AttendanceFlag.workedRestDay &&
        flag != AttendanceFlag.workedHoliday &&
        flag != AttendanceFlag.corrected,
  );

  /// The labels this day should be shown under — its flags, or the single
  /// status when there is nothing unusual to say.
  List<String> get labelKeys => statusLabelKeys(flags: flags, status: status);

  /// Ordinary work time: arrival to departure, minus every closed break, and
  /// stopping where overtime starts. Null until there is both a check-in and a
  /// check-out.
  ///
  /// Worked, break time and overtime never share a minute, and together they
  /// account for the whole day: worked + breaks + overtime is the time between
  /// the first scan and the last, less any gap the admin excluded by putting
  /// the overtime window later than the end of the day.
  Duration? get worked {
    // Nothing of a missed day is ordinary work time, not even the minutes
    // before the overtime window opens.
    if (isAbsentArrival) return null;

    final start = _minutes(record.checkInTime);
    var end = _minutes(record.checkOutTime);
    if (start == null || end == null) return null;

    // Once overtime is being counted, ordinary time stops.
    final overtimeFrom = overtimeStartedAt;
    if (overtimeFrom != null && end > overtimeFrom) end = overtimeFrom;
    if (end <= start) return null;

    final total = (end - start) - breakTime.inMinutes;
    return Duration(minutes: total < 0 ? 0 : total);
  }

  /// Overtime as the app works it out, inside the window the admin set: a scan
  /// back in after leaving marks it explicitly, and otherwise simply staying on
  /// past the overtime hour counts — somebody working late should not have to
  /// punch twice for it.
  ///
  /// Only time inside the overtime window is ever paid. Somebody who turns up
  /// at 17:10 for a day that ended at 17:00 and leaves again at 17:20 earns
  /// nothing: their day is an absence and none of those minutes reached the
  /// overtime hour.
  Duration? get overtime => _explicitOvertime ?? _derivedOvertime;

  /// An overtime shift the person scanned out and back in for.
  Duration? get _explicitOvertime => schedule.overtimeBetween(
    _minutes(record.overtimeInTime),
    _minutes(record.overtimeOutTime),
    endOfDay: endOfDayMinutes,
  );

  /// Staying on past the overtime hour without scanning out first.
  ///
  /// Counted from the later of the end of the day and their arrival: somebody
  /// who only turned up at 18:00 was not here at 17:30, and starting the clock
  /// at the end of a day they never worked would invent overtime they never
  /// did.
  Duration? get _derivedOvertime => schedule.overtimeBetween(
    _laterOf(endOfDayMinutes, _minutes(record.checkInTime)),
    _minutes(record.checkOutTime),
    endOfDay: endOfDayMinutes,
  );

  /// The minute overtime began, if any was earned. Where ordinary work stops.
  int? get overtimeStartedAt {
    if (overtime == null) return null;
    final explicit = _minutes(record.overtimeInTime);
    final from = _explicitOvertime != null && explicit != null
        ? explicit
        : endOfDayMinutes;
    return [
      from,
      schedule.overtimeStartMinutes,
      endOfDayMinutes,
    ].reduce((a, b) => a > b ? a : b);
  }

  static int _laterOf(int a, int? b) => b == null || b < a ? a : b;

  static int? _minutes(String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return (h == null || m == null) ? null : h * 60 + m;
  }
}
