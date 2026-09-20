import '../../../../core/utils/attendance_utils.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../cubit/punch_report_cubit.dart';

/// What one person's days add up to over the range on screen.
///
/// The flags say what was unusual about a *day*. This is the question an admin
/// actually asks — "how is this person doing?" — and it is the only view in
/// the app that answers it without them counting rows by eye.
///
/// Purely derived: no new arithmetic, only a tally of what
/// [AttendanceDayTotals] already worked out for each day. Nothing is stored,
/// so a shift or a holiday changed this morning is reflected the next time the
/// report is opened.
class EmployeePattern {
  final EmployeeModel employee;

  /// How many days of theirs the range covers at all.
  final int daysCovered;

  /// Days carrying at least one thing worth attention.
  final int daysWithIssues;

  /// How many times each flag came up.
  final Map<AttendanceFlag, int> counts;

  /// Lateness and early departure summed across the range, in minutes. The
  /// figures payroll asks for, and the ones that separate somebody five
  /// minutes late six times from somebody an hour late once.
  final int lateMinutes;
  final int earlyOutMinutes;

  const EmployeePattern({
    required this.employee,
    this.daysCovered = 0,
    this.daysWithIssues = 0,
    this.counts = const {},
    this.lateMinutes = 0,
    this.earlyOutMinutes = 0,
  });

  int countOf(AttendanceFlag flag) => counts[flag] ?? 0;

  /// True when nothing about this person's range needs looking at.
  bool get isClean => daysWithIssues == 0;

  /// The flags they actually carry, worst first, so a row of chips leads with
  /// the thing most worth reading.
  ///
  /// Ordered deliberately rather than by count: an absence outranks a lateness
  /// however many times the lateness happened, because they are different
  /// kinds of problem and a frequent small one must not bury a rare large one.
  List<AttendanceFlag> get presentFlags => [
    for (final flag in _severityOrder)
      if (countOf(flag) > 0) flag,
  ];

  static const _severityOrder = [
    AttendanceFlag.absent,
    AttendanceFlag.missingCheckOut,
    AttendanceFlag.arrivedLate,
    AttendanceFlag.leftEarly,
    AttendanceFlag.openBreak,
    AttendanceFlag.workedRestDay,
    AttendanceFlag.workedHoliday,
    AttendanceFlag.corrected,
  ];

  /// One entry per employee in [rows], worst first.
  ///
  /// Sorted by days with issues rather than by name: the point of the list is
  /// that the people who need attention are at the top of it. Ties fall back
  /// to the name so the order is stable between refreshes.
  static List<EmployeePattern> from(List<PunchReportRow> rows) {
    final byEmployee = <String, List<PunchReportRow>>{};
    final employees = <String, EmployeeModel>{};

    for (final row in rows) {
      byEmployee.putIfAbsent(row.employee.id, () => []).add(row);
      employees[row.employee.id] = row.employee;
    }

    final patterns =
        [
          for (final entry in byEmployee.entries)
            _forEmployee(employees[entry.key]!, entry.value),
        ]..sort((a, b) {
          final byIssues = b.daysWithIssues.compareTo(a.daysWithIssues);
          if (byIssues != 0) return byIssues;
          return a.employee.fullName.compareTo(b.employee.fullName);
        });

    return patterns;
  }

  static EmployeePattern _forEmployee(
    EmployeeModel employee,
    List<PunchReportRow> rows,
  ) {
    final counts = <AttendanceFlag, int>{};
    var withIssues = 0;
    var late = 0;
    var early = 0;

    for (final row in rows) {
      for (final flag in row.flags) {
        counts[flag] = (counts[flag] ?? 0) + 1;
      }
      if (row.hasIssue) withIssues++;
      late += row.lateMinutes;
      early += row.earlyOutMinutes;
    }

    return EmployeePattern(
      employee: employee,
      daysCovered: rows.length,
      daysWithIssues: withIssues,
      counts: counts,
      lateMinutes: late,
      earlyOutMinutes: early,
    );
  }
}
