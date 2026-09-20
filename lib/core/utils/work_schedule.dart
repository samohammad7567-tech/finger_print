/// The hours a working day is judged by, as the admin set them.
///
/// Lives in core rather than a feature: the device fold, the check-in screen,
/// the reports and the admin summaries all judge a time against these, and they
/// must all judge it against the same ones.
///
/// There are two ways one of these reaches a judgement. The settings feature
/// stores the *company default* — the hours used by anybody who has not been
/// put on a shift. The shifts feature stores a named set of hours per shift,
/// and [forShift] turns one of those into a schedule of its own. Everything
/// downstream is handed a finished [WorkSchedule] and never has to know which
/// of the two it came from.
class WorkSchedule {
  /// When the working day begins. Arriving after it, past [lateGraceMinutes],
  /// is late.
  final String workStart;

  /// When the working day ends. Leaving before it, before
  /// [earlyOutGraceMinutes] is allowed for, is an early leave — and it is where
  /// paid work time stops being counted.
  final String workEnd;

  /// When overtime starts counting. Normally a little after [workEnd], so
  /// taking a few minutes to pack up is not overtime.
  final String overtimeStart;

  /// When overtime stops counting. Time past it is not paid as overtime — a
  /// forgotten scan at midnight should not read as seven hours' work.
  final String overtimeEnd;

  /// How late somebody may arrive before the day reads as late. Minutes past
  /// [workStart]; zero means the start time is the line itself.
  ///
  /// It moves only the *late* line. Arriving after the whole day is over is
  /// still an absence however generous this is — see [endOfDayMinutes].
  final int lateGraceMinutes;

  /// How early somebody may leave before the day reads as an early leave.
  /// Minutes before the end of their own day; zero means the end time is the
  /// line itself.
  ///
  /// It moves only the *early leave* line. Where paid work stops and where
  /// overtime opens from are still the real end of the day, so forgiving a
  /// five-minute head start does not also pay for it.
  final int earlyOutGraceMinutes;

  /// The weekdays this schedule does not work, as [DateTime.weekday] numbers
  /// (Monday 1 … Sunday 7).
  ///
  /// Empty means every day is a working day, which is what every install had
  /// before the calendar existed — so an admin who never opens the rest-day
  /// picker sees exactly the behaviour they had before.
  final Set<int> restDays;

  const WorkSchedule({
    this.workStart = '09:00',
    this.workEnd = '17:00',
    this.overtimeStart = '17:30',
    this.overtimeEnd = '22:00',
    this.lateGraceMinutes = 0,
    this.earlyOutGraceMinutes = 0,
    this.restDays = const {},
  });

  /// Housing staff leave half an hour before everyone else.
  static const housingEarlyMinutes = 30;

  /// Thursday closing time for staff with a travel permission. An absolute
  /// hour rather than an offset — it exists so they can catch the bus home.
  static const travelThursdayEnd = '14:00';

  /// The latest minute a derived overtime window may reach, so a late shift
  /// cannot push it past midnight into the next day's punches.
  static const _lastMinuteOfDay = 23 * 60 + 59;

  int get workStartMinutes => minutesOf(workStart);
  int get workEndMinutes => minutesOf(workEnd);
  int get overtimeStartMinutes => minutesOf(overtimeStart);
  int get overtimeEndMinutes => minutesOf(overtimeEnd);

  /// The last minute somebody can arrive and still be on time.
  int get latestOnTimeArrivalMinutes => workStartMinutes + lateGraceMinutes;

  /// True when [day] falls on one of this schedule's weekly rest days.
  ///
  /// Says nothing about public holidays — those are company-wide and dated
  /// rather than weekly, so they live in their own table and are folded in by
  /// the work calendar.
  bool isRestDay(DateTime day) => restDays.contains(day.weekday);

  /// These same hours moved onto a shift's start and end.
  ///
  /// Called on the company default, so a shift only has to carry the four
  /// things the admin sets for it. The overtime window follows the shift by
  /// the same distance it sits from the end of the default day: a company that
  /// opens overtime half an hour after work ends means that for the evening
  /// shift too, and nobody has to key it in twice.
  WorkSchedule forShift({
    required String startWork,
    required String endWork,
    int lateGraceMinutes = 0,
    int earlyOutGraceMinutes = 0,
    Set<int> restDays = const {},
  }) {
    final end = minutesOf(endWork);
    final opensAfter = overtimeStartMinutes - workEndMinutes;
    final closesAfter = overtimeEndMinutes - workEndMinutes;

    return WorkSchedule(
      workStart: startWork,
      workEnd: endWork,
      overtimeStart: _clock(end + opensAfter),
      overtimeEnd: _clock(end + closesAfter),
      lateGraceMinutes: lateGraceMinutes,
      earlyOutGraceMinutes: earlyOutGraceMinutes,
      restDays: restDays,
    );
  }

  /// When this person's day is scheduled to end, in minutes from midnight.
  ///
  /// The real end of the day, before any early-leave allowance: it is where
  /// paid work time stops, where the overtime window opens from, and the line
  /// an arrival is judged an absence against. [earliestOnTimeLeaveMinutes] is
  /// what a *departure* is measured against instead.
  int endOfDayMinutes(
    DateTime day, {
    bool hasHousing = false,
    bool hasTravelPermission = false,
  }) {
    if (hasTravelPermission && day.weekday == DateTime.thursday) {
      // Never later than the working end, however the two are configured.
      final travel = minutesOf(travelThursdayEnd);
      return travel < workEndMinutes ? travel : workEndMinutes;
    }
    if (hasHousing) {
      final housing = workEndMinutes - housingEarlyMinutes;
      return housing < 0 ? 0 : housing;
    }
    return workEndMinutes;
  }

  /// The earliest this person may leave without the day reading as an early
  /// leave: the end of their own day, less the allowance their shift grants.
  int earliestOnTimeLeaveMinutes(
    DateTime day, {
    bool hasHousing = false,
    bool hasTravelPermission = false,
  }) {
    final accepted =
        endOfDayMinutes(
          day,
          hasHousing: hasHousing,
          hasTravelPermission: hasTravelPermission,
        ) -
        earlyOutGraceMinutes;
    return accepted < 0 ? 0 : accepted;
  }

  /// Overtime worked between [from] and [to], both in minutes from midnight,
  /// clipped to the overtime window and to the end of this person's own day.
  ///
  /// Returns null when none of it falls inside the window.
  Duration? overtimeBetween(int? from, int? to, {required int endOfDay}) {
    if (from == null || to == null) return null;

    final windowStart = [
      from,
      overtimeStartMinutes,
      endOfDay,
    ].reduce((a, b) => a > b ? a : b);
    final windowEnd = to < overtimeEndMinutes ? to : overtimeEndMinutes;

    return windowEnd > windowStart
        ? Duration(minutes: windowEnd - windowStart)
        : null;
  }

  /// True when the times make a day that can actually be worked.
  ///
  /// The two allowances are part of that: between them they must still leave a
  /// stretch of the day nobody is forgiven for missing, or every arrival would
  /// be on time and every departure acceptable and the day would judge nothing
  /// at all.
  bool get isValid =>
      workEndMinutes > workStartMinutes &&
      overtimeStartMinutes >= workEndMinutes &&
      overtimeEndMinutes > overtimeStartMinutes &&
      lateGraceMinutes >= 0 &&
      earlyOutGraceMinutes >= 0 &&
      latestOnTimeArrivalMinutes < workEndMinutes - earlyOutGraceMinutes &&
      // Resting every day of the week is not a shift anybody works.
      restDays.length < DateTime.daysPerWeek;

  WorkSchedule copyWith({
    String? workStart,
    String? workEnd,
    String? overtimeStart,
    String? overtimeEnd,
    int? lateGraceMinutes,
    int? earlyOutGraceMinutes,
    Set<int>? restDays,
  }) => WorkSchedule(
    workStart: workStart ?? this.workStart,
    workEnd: workEnd ?? this.workEnd,
    overtimeStart: overtimeStart ?? this.overtimeStart,
    overtimeEnd: overtimeEnd ?? this.overtimeEnd,
    lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
    earlyOutGraceMinutes: earlyOutGraceMinutes ?? this.earlyOutGraceMinutes,
    restDays: restDays ?? this.restDays,
  );

  /// Rest days as they are stored — '5,6' for Friday and Saturday. A single
  /// column rather than seven, because they are only ever read as a set.
  static String encodeRestDays(Set<int> days) {
    final ordered =
        days.where((d) => d >= 1 && d <= DateTime.daysPerWeek).toList()..sort();
    return ordered.join(',');
  }

  /// The inverse of [encodeRestDays], forgiving of anything it does not
  /// recognise: a malformed value means "no rest days", never a crash on a
  /// screen somebody needs.
  static Set<int> parseRestDays(String? value) {
    if (value == null || value.trim().isEmpty) return const {};
    final days = <int>{};
    for (final part in value.split(',')) {
      final day = int.tryParse(part.trim());
      if (day != null && day >= 1 && day <= DateTime.daysPerWeek) days.add(day);
    }
    return days;
  }

  /// 'HH:mm' as minutes from midnight. Kept here rather than borrowed from
  /// attendance_utils so that file can depend on this one and not the reverse.
  static int minutesOf(String? time) {
    if (time == null || time.isEmpty) return 0;
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// Minutes from midnight back as 'HH:mm', kept inside the same day.
  static String _clock(int minutes) {
    final clamped = minutes < 0
        ? 0
        : (minutes > _lastMinuteOfDay ? _lastMinuteOfDay : minutes);
    final hours = (clamped ~/ 60).toString().padLeft(2, '0');
    final rest = (clamped % 60).toString().padLeft(2, '0');
    return '$hours:$rest';
  }
}
