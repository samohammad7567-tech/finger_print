import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/core/utils/work_schedule.dart';
import 'package:attendence/features/admin/presentation/cubit/punch_report_cubit.dart';
import 'package:attendence/features/attendance/data/models/attendance_record_model.dart';
import 'package:attendence/features/attendance/data/models/employee_model.dart';

/// The numbers the punch report puts in front of payroll: worked time, break
/// time and overtime, how they divide a day between them, and how they move
/// when the admin changes the working hours.
void main() {
  const employee = EmployeeModel(id: 'e1', fullName: 'Sara', department: 'Ops');
  const housed = EmployeeModel(
    id: 'e2',
    fullName: 'Omar',
    department: 'Ops',
    hasHousing: true,
  );

  PunchReportRow row({
    EmployeeModel who = employee,
    String date = '2026-08-24',
    String? checkIn = '08:00',
    String? checkOut = '17:00',
    List<AttendanceBreak> breaks = const [],
    String? breakOutTime,
    String? breakInTime,
    String? overtimeIn,
    String? overtimeOut,
    WorkSchedule schedule = const WorkSchedule(),
  }) => PunchReportRow(
    employee: who,
    schedule: schedule,
    record: AttendanceRecordModel(
      id: 'r1',
      employeeId: who.id,
      date: date,
      checkInTime: checkIn,
      checkOutTime: checkOut,
      breaks: breaks,
      breakOutTime: breakOutTime,
      breakInTime: breakInTime,
      overtimeInTime: overtimeIn,
      overtimeOutTime: overtimeOut,
    ),
  );

  test('every break is deducted from worked time, not only the first', () {
    final r = row(
      breaks: const [
        AttendanceBreak(out: '10:00', backIn: '10:15'),
        AttendanceBreak(out: '13:00', backIn: '13:40'),
        AttendanceBreak(out: '15:30', backIn: '15:50'),
      ],
    );

    expect(r.breakTime, const Duration(minutes: 75));
    // 9h on site, 1h15m of it away.
    expect(r.worked, const Duration(hours: 7, minutes: 45));
  });

  test('a break with no return recorded costs nothing', () {
    final r = row(
      breaks: const [
        AttendanceBreak(out: '10:00', backIn: '10:15'),
        AttendanceBreak(out: '15:00'),
      ],
    );

    expect(r.breakTime, const Duration(minutes: 15));
    expect(r.worked, const Duration(hours: 8, minutes: 45));
  });

  test('a day stored before the list still reads as one break', () {
    // Rows folded under the old schema carry only these two columns.
    final r = row(breakOutTime: '12:00', breakInTime: '12:30');

    expect(r.breaks, hasLength(1));
    expect(r.breakTime, const Duration(minutes: 30));
    expect(r.worked, const Duration(hours: 8, minutes: 30));
  });

  test('staying past the overtime hour is overtime without a second pair', () {
    final r = row(checkOut: '19:00');

    // The default window opens at 17:30, not at the end of the day.
    expect(r.overtime, const Duration(hours: 1, minutes: 30));
    // Ordinary time stops where overtime starts, so no minute is counted twice.
    expect(r.worked, const Duration(hours: 9, minutes: 30));
  });

  test('a few minutes past the end is not overtime', () {
    final r = row(checkOut: '17:20');

    expect(r.overtime, isNull);
    expect(r.worked, const Duration(hours: 9, minutes: 20));
  });

  test('an explicit overtime shift is reported on its own', () {
    final r = row(
      checkOut: '17:05',
      breaks: const [AttendanceBreak(out: '12:00', backIn: '12:30')],
      overtimeIn: '18:00',
      overtimeOut: '21:15',
    );

    expect(r.overtime, const Duration(hours: 3, minutes: 15));
    expect(r.worked, const Duration(hours: 8, minutes: 35));
  });

  test('overtime past the closing hour is not counted', () {
    // A forgotten scan at 02:00 must not read as nine hours of overtime.
    final r = row(checkOut: '17:00', overtimeIn: '18:00', overtimeOut: '23:30');

    expect(r.overtime, const Duration(hours: 4));
  });

  test('housing staff finish half an hour before the others', () {
    final r = row(who: housed, checkOut: '18:00');

    expect(r.scheduledEndMinutes, 16 * 60 + 30);
    expect(r.overtime, const Duration(minutes: 30));
    // 16:30 to 17:30 is ordinary time for them, not overtime.
    expect(r.worked, const Duration(hours: 9, minutes: 30));
  });

  test('turning up after the working day has ended is an absence', () {
    final r = row(checkIn: '18:00', checkOut: '20:30');

    expect(r.isAbsentArrival, isTrue);
    expect(r.status, 'absent');
    // The day itself was missed, so none of it is ordinary work time.
    expect(r.worked, isNull);
    // What they did put in still counts, as overtime.
    expect(r.overtime, const Duration(hours: 2, minutes: 30));
  });

  test('an absent arrival is not credited from before they arrived', () {
    // The window opens at 17:30 but nobody was here until 18:00 — the half
    // hour between the two is not theirs.
    final r = row(checkIn: '18:00', checkOut: '19:00');

    expect(r.overtime, const Duration(hours: 1));
  });

  test('an absent arrival earns nothing before the overtime hour', () {
    // In at 17:10 and gone by 17:20: after the day ended, before overtime
    // opens. An absence, and not a minute of it is payable.
    final r = row(checkIn: '17:10', checkOut: '17:20');

    expect(r.status, 'absent');
    expect(r.worked, isNull);
    expect(r.overtime, isNull);
  });

  test('an absent arrival stops earning at the closing hour', () {
    final r = row(checkIn: '20:00', checkOut: '23:45');

    expect(r.status, 'absent');
    // 20:00 to 22:00. The hour and three quarters after it is not overtime.
    expect(r.overtime, const Duration(hours: 2));
  });

  test('housing staff are absent from their own earlier end of day', () {
    // Their day ends at 16:30, so 16:45 missed it — though the overtime window
    // still does not open until 17:30.
    final r = row(who: housed, checkIn: '16:45', checkOut: '19:00');

    expect(r.status, 'absent');
    expect(r.worked, isNull);
    expect(r.overtime, const Duration(hours: 1, minutes: 30));
  });

  test('arriving before the day ends is not an absence, however late', () {
    final r = row(checkIn: '16:55', checkOut: '17:00');

    expect(r.isAbsentArrival, isFalse);
    expect(r.status, 'pending');
    expect(r.worked, const Duration(minutes: 5));
  });

  test('the admin moving the hours moves every figure with them', () {
    const schedule = WorkSchedule(
      workStart: '07:00',
      workEnd: '15:00',
      overtimeStart: '15:00',
      overtimeEnd: '20:00',
    );

    final r = row(
      checkIn: '07:00',
      checkOut: '18:00',
      breaks: const [AttendanceBreak(out: '10:00', backIn: '10:30')],
      schedule: schedule,
    );

    expect(r.scheduledEndMinutes, 15 * 60);
    // Overtime opens the moment the day ends under these hours.
    expect(r.overtime, const Duration(hours: 3));
    expect(r.worked, const Duration(hours: 7, minutes: 30));
  });
}
