import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/core/utils/attendance_utils.dart';
import 'package:attendence/core/utils/work_schedule.dart';
import 'package:attendence/features/attendance/data/models/attendance_day_totals.dart';
import 'package:attendence/features/attendance/data/models/attendance_record_model.dart';
import 'package:attendence/features/attendance/data/models/employee_model.dart';
import 'package:attendence/core/style/theme/color_extension.dart';

/// Everything unusual about one day, rather than the single word the stored
/// status collapses to.
///
/// The case that matters most is the pair: somebody late in *and* early out is
/// filed as an early leave, and before this the lateness was simply gone. The
/// flags are worked out from the times on read, so these check the arithmetic
/// rather than anything that was written down.
void main() {
  const schedule = WorkSchedule(
    workStart: '09:00',
    workEnd: '17:00',
    overtimeStart: '17:30',
    overtimeEnd: '22:00',
  );

  const employee = EmployeeModel(id: 'e1', fullName: 'Sara', department: 'Ops');

  /// A Monday, so no Thursday travel allowance is in play.
  const date = '2026-08-10';

  AttendanceDayTotals day({
    String? checkIn = '08:55',
    String? checkOut = '17:05',
    String status = 'present',
    List<AttendanceBreak> breaks = const [],
    String? correctedAt,
    WorkSchedule using = schedule,
  }) => AttendanceDayTotals.forEmployee(
    record: AttendanceRecordModel(
      id: 'r1',
      employeeId: employee.id,
      date: date,
      checkInTime: checkIn,
      checkOutTime: checkOut,
      status: status,
      breaks: breaks,
      correctedAt: correctedAt,
    ),
    employee: employee,
    schedule: using,
  );

  test('an ordinary day carries no flags at all', () {
    expect(day().flags, isEmpty);
    // And still says what it always said.
    expect(day().labelKeys, ['present']);
  });

  test('late in and early out are both kept', () {
    // The whole point. The stored status can only be one of these, and before
    // the flags existed the lateness was the one that got dropped.
    final totals = day(checkIn: '09:20', checkOut: '16:30');

    expect(totals.flags, [
      AttendanceFlag.arrivedLate,
      AttendanceFlag.leftEarly,
    ]);
    expect(totals.labelKeys, ['late', 'early_leave']);
  });

  test('late in on its own is just late', () {
    expect(day(checkIn: '09:20').flags, [AttendanceFlag.arrivedLate]);
  });

  test('early out on its own is just an early leave', () {
    expect(day(checkOut: '16:30').flags, [AttendanceFlag.leftEarly]);
  });

  test('a shift allowance is honoured, not flagged', () {
    const forgiving = WorkSchedule(
      workStart: '09:00',
      workEnd: '17:00',
      overtimeStart: '17:30',
      overtimeEnd: '22:00',
      lateGraceMinutes: 30,
      earlyOutGraceMinutes: 30,
    );

    // Ten past nine and ten to five, both inside what the shift forgives.
    expect(
      day(checkIn: '09:10', checkOut: '16:50', using: forgiving).flags,
      isEmpty,
    );

    // A minute outside each is flagged again.
    expect(day(checkIn: '09:31', checkOut: '16:29', using: forgiving).flags, [
      AttendanceFlag.arrivedLate,
      AttendanceFlag.leftEarly,
    ]);
  });

  test('scanning in and never out is called out on its own', () {
    final totals = day(checkIn: '08:55', checkOut: null);

    expect(totals.flags, [AttendanceFlag.missingCheckOut]);
    expect(totals.labelKeys, ['flag_missing_checkout']);
  });

  test('a late arrival with no departure carries both', () {
    expect(day(checkIn: '09:20', checkOut: null).flags, [
      AttendanceFlag.arrivedLate,
      AttendanceFlag.missingCheckOut,
    ]);
  });

  test('a day nobody scanned is not recorded rather than flagged', () {
    // Silence is not the same as a missing departure, and it is not an
    // absence either — nobody has said the day was missed.
    final totals = day(checkIn: null, checkOut: null, status: 'pending');

    expect(totals.flags, isEmpty);
    expect(totals.labelKeys, ['not_recorded']);
  });

  test('an unclosed break is flagged, a closed one is not', () {
    expect(
      day(
        breaks: const [AttendanceBreak(out: '12:00', backIn: '12:30')],
      ).flags,
      isEmpty,
    );
    expect(day(breaks: const [AttendanceBreak(out: '12:00')]).flags, [
      AttendanceFlag.openBreak,
    ]);
  });

  test('a corrected day says so, alongside whatever else it was', () {
    final totals = day(
      checkIn: '09:20',
      checkOut: '16:30',
      correctedAt: '2026-08-10T18:00:00.000',
    );

    expect(totals.flags, [
      AttendanceFlag.arrivedLate,
      AttendanceFlag.leftEarly,
      AttendanceFlag.corrected,
    ]);
  });

  test('a missed day is only absent, not also late', () {
    // Turning up after the working day ended. Calling that "late" as well
    // would be describing an arrival that never counted for anything.
    final totals = day(checkIn: '17:30', checkOut: '19:00');

    expect(totals.status, 'absent');
    expect(totals.flags, [AttendanceFlag.absent]);
  });

  test('a day marked absent by hand is flagged absent', () {
    final totals = day(checkIn: null, checkOut: null, status: 'absent');

    expect(totals.flags, [AttendanceFlag.absent]);
    expect(totals.labelKeys, ['absent']);
  });

  test('an absent day still reports a break nobody closed', () {
    final totals = day(
      checkIn: '17:30',
      checkOut: '19:00',
      breaks: const [AttendanceBreak(out: '18:00')],
    );

    expect(totals.flags, [AttendanceFlag.absent, AttendanceFlag.openBreak]);
  });

  test('every flag has a label and a colour', () {
    for (final flag in AttendanceFlag.values) {
      // The label stands on its own — the exporters name a day without a
      // theme to read — while the colour resolves against a palette.
      expect(flagLabelKey(flag), isNotEmpty, reason: '$flag has no label');

      final display = getFlagDisplay(flag, MyColors.light);
      expect(display.labelKey, flagLabelKey(flag));
      expect(display.color.a, 1.0, reason: '$flag has no colour');
    }
  });
}
