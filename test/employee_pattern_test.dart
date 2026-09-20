import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/core/utils/attendance_utils.dart';
import 'package:attendence/core/utils/work_schedule.dart';
import 'package:attendence/features/admin/presentation/cubit/punch_report_cubit.dart';
import 'package:attendence/features/admin/presentation/refactor/employee_pattern.dart';
import 'package:attendence/features/attendance/data/models/attendance_record_model.dart';
import 'package:attendence/features/attendance/data/models/employee_model.dart';

/// What one person's days add up to over a range.
///
/// The flags already say what was unusual about a day; this is the tally an
/// admin reads to answer "how is this person doing". These check the counting
/// and — more importantly — the ordering, because the whole value of the list
/// is that the people who need attention are at the top of it.
void main() {
  const schedule = WorkSchedule(
    workStart: '09:00',
    workEnd: '17:00',
    overtimeStart: '17:30',
    overtimeEnd: '22:00',
  );

  const sara = EmployeeModel(id: 'e1', fullName: 'Sara', department: 'Ops');
  const omar = EmployeeModel(id: 'e2', fullName: 'Omar', department: 'Ops');
  const lina = EmployeeModel(id: 'e3', fullName: 'Lina', department: 'Ops');

  PunchReportRow row(
    EmployeeModel employee, {
    required String date,
    String? checkIn = '08:55',
    String? checkOut = '17:05',
    String status = 'present',
    WorkingDayKind kind = WorkingDayKind.working,
    WorkSchedule using = schedule,
  }) => PunchReportRow(
    employee: employee,
    record: AttendanceRecordModel(
      id: 'r-$date-${employee.id}',
      employeeId: employee.id,
      date: date,
      checkInTime: checkIn,
      checkOutTime: checkOut,
      status: status,
    ),
    schedule: using,
    dayKind: kind,
  );

  test('an ordinary run of days reads as clean', () {
    final patterns = EmployeePattern.from([
      row(sara, date: '2026-08-10'),
      row(sara, date: '2026-08-11'),
    ]);

    expect(patterns, hasLength(1));
    expect(patterns.single.isClean, isTrue);
    expect(patterns.single.daysCovered, 2);
    expect(patterns.single.daysWithIssues, 0);
    expect(patterns.single.presentFlags, isEmpty);
  });

  test('each flag is counted across the range', () {
    final patterns = EmployeePattern.from([
      row(sara, date: '2026-08-10', checkIn: '09:20'),
      row(sara, date: '2026-08-11', checkIn: '09:30'),
      row(sara, date: '2026-08-12', checkOut: '16:00'),
    ]);

    final pattern = patterns.single;
    expect(pattern.countOf(AttendanceFlag.arrivedLate), 2);
    expect(pattern.countOf(AttendanceFlag.leftEarly), 1);
    expect(pattern.daysWithIssues, 3);
    expect(pattern.daysCovered, 3);
  });

  test('a day that is two things at once counts once as a day', () {
    // Late in and early out is one flagged day carrying two flags — the point
    // of counting days and flags separately.
    final pattern = EmployeePattern.from([
      row(sara, date: '2026-08-10', checkIn: '09:20', checkOut: '16:00'),
    ]).single;

    expect(pattern.daysWithIssues, 1);
    expect(pattern.countOf(AttendanceFlag.arrivedLate), 1);
    expect(pattern.countOf(AttendanceFlag.leftEarly), 1);
  });

  test('lateness is summed in minutes, past what the shift forgives', () {
    final pattern = EmployeePattern.from([
      row(sara, date: '2026-08-10', checkIn: '09:20'), // 20 minutes
      row(sara, date: '2026-08-11', checkIn: '09:05'), // 5 minutes
    ]).single;

    expect(pattern.lateMinutes, 25);
  });

  test('a shift allowance is not counted against anybody', () {
    const forgiving = WorkSchedule(
      workStart: '09:00',
      workEnd: '17:00',
      overtimeStart: '17:30',
      overtimeEnd: '22:00',
      lateGraceMinutes: 15,
      earlyOutGraceMinutes: 15,
    );

    final pattern = EmployeePattern.from([
      // Ten past nine, inside the fifteen forgiven: not late at all.
      row(sara, date: '2026-08-10', checkIn: '09:10', using: forgiving),
      // Twenty past: late, but only by the five minutes past the allowance.
      row(sara, date: '2026-08-11', checkIn: '09:20', using: forgiving),
    ]).single;

    expect(pattern.countOf(AttendanceFlag.arrivedLate), 1);
    expect(pattern.lateMinutes, 5);
  });

  test('early departure is summed the same way', () {
    final pattern = EmployeePattern.from([
      row(sara, date: '2026-08-10', checkOut: '16:30'), // 30 minutes
      row(sara, date: '2026-08-11', checkOut: '16:45'), // 15 minutes
    ]).single;

    expect(pattern.earlyOutMinutes, 45);
  });

  test('working a rest day is recorded but is not an issue', () {
    final pattern = EmployeePattern.from([
      row(
        sara,
        date: '2026-08-14',
        checkIn: '10:00',
        kind: WorkingDayKind.restDay,
      ),
    ]).single;

    expect(pattern.countOf(AttendanceFlag.workedRestDay), 1);
    // They did nothing wrong by coming in on their day off.
    expect(pattern.daysWithIssues, 0);
    expect(pattern.isClean, isTrue);
  });

  test('the worst-off person comes first', () {
    final patterns = EmployeePattern.from([
      row(lina, date: '2026-08-10'),
      row(omar, date: '2026-08-10', checkIn: '09:20'),
      row(sara, date: '2026-08-10', checkIn: '09:20'),
      row(sara, date: '2026-08-11', checkIn: '09:40'),
      row(sara, date: '2026-08-12', checkOut: '15:00'),
    ]);

    expect(
      [for (final p in patterns) p.employee.fullName],
      ['Sara', 'Omar', 'Lina'],
    );
    expect(patterns.first.daysWithIssues, 3);
    expect(patterns.last.isClean, isTrue);
  });

  test('people with the same tally are ordered by name, stably', () {
    final patterns = EmployeePattern.from([
      row(sara, date: '2026-08-10', checkIn: '09:20'),
      row(omar, date: '2026-08-10', checkIn: '09:20'),
      row(lina, date: '2026-08-10', checkIn: '09:20'),
    ]);

    expect(
      [for (final p in patterns) p.employee.fullName],
      ['Lina', 'Omar', 'Sara'],
    );
  });

  test('a rare absence outranks a frequent lateness in the chips', () {
    // Ordered by what kind of problem it is, not by how often it happened —
    // otherwise six latenesses would bury one unexplained absence.
    final pattern = EmployeePattern.from([
      row(sara, date: '2026-08-10', checkIn: '09:20'),
      row(sara, date: '2026-08-11', checkIn: '09:20'),
      row(sara, date: '2026-08-12', checkIn: '09:20'),
      row(
        sara,
        date: '2026-08-13',
        checkIn: null,
        checkOut: null,
        status: 'absent',
      ),
    ]).single;

    expect(pattern.presentFlags.first, AttendanceFlag.absent);
    expect(pattern.countOf(AttendanceFlag.arrivedLate), 3);
    expect(pattern.countOf(AttendanceFlag.absent), 1);
  });

  test('an empty range produces no rows at all', () {
    expect(EmployeePattern.from(const []), isEmpty);
  });
}
