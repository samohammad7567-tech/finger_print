import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/localization/lang_keys.dart';
import 'package:attendence/core/network/api_exception.dart';
import 'package:attendence/core/utils/work_schedule.dart';
import 'package:attendence/features/attendance/data/data_source/attendance_local_data_source.dart';
import 'package:attendence/features/attendance/data/models/attendance_day_totals.dart';
import 'package:attendence/features/attendance/data/models/attendance_record_model.dart';
import 'package:attendence/features/device/data/data_source/device_sync_data_source.dart';
import 'package:attendence/features/device/data/models/device_settings_model.dart';
import 'package:attendence/features/shifts/data/data_source/shifts_local_data_source.dart';
import 'package:attendence/features/shifts/data/models/shift_model.dart';

/// Shifts: the hours a person's day is judged by when the company runs more
/// than one working day.
///
/// A shift is stored as an id on the employee and there is no foreign key
/// behind it, so what these check is the work the constraint would have done —
/// that deleting a shift releases the people on it rather than stranding them,
/// and that an employee on none still has a day that can be judged.
///
/// The rest is the arithmetic the whole app depends on: that two people
/// scanning the same minute land on different sides of "late" when they work
/// different days, and that the two allowances forgive a day without also
/// paying for time nobody worked.
void main() {
  /// The company default these tests measure against, so a change to the
  /// app's own defaults cannot quietly rewrite what they assert.
  const companyDefault = WorkSchedule(
    workStart: '09:00',
    workEnd: '17:00',
    overtimeStart: '17:30',
    overtimeEnd: '22:00',
  );

  late AppDatabase database;
  late AttendanceLocalDataSource attendance;
  late ShiftsLocalDataSource shifts;
  late DeviceSyncDataSource sync;

  setUp(() async {
    database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    attendance = AttendanceLocalDataSource(database, () => companyDefault);
    shifts = ShiftsLocalDataSource(database, () => companyDefault);
    sync = DeviceSyncDataSource(database, () => companyDefault);
  });

  tearDown(() async => database.close());

  Future<ShiftModel> addShift({
    String name = 'Evening',
    String start = '14:00',
    String end = '22:00',
    int lateGrace = 0,
    int earlyOutGrace = 0,
  }) => shifts.createShift(
    ShiftModel(
      id: '',
      name: name,
      startWork: start,
      endWork: end,
      lateGraceMinutes: lateGrace,
      earlyOutGraceMinutes: earlyOutGrace,
    ),
  );

  Future<String> addEmployee({
    String name = 'Sara',
    String deviceUserId = '7',
    String? shiftId,
  }) async {
    final employee = await attendance.createEmployee({
      'full_name': name,
      'department': 'Ops',
      'device_user_id': deviceUserId,
      'shift_id': shiftId,
    });
    return employee.id;
  }

  ZkPunchModel punch(String userId, String iso) =>
      ZkPunchModel(deviceUserId: userId, timestamp: DateTime.parse(iso));

  // ------------------------------------------------------------ the list

  test('a shift is stored with the four times the admin set', () async {
    await addShift(lateGrace: 10, earlyOutGrace: 15);

    final all = await shifts.getShifts();
    expect(all, hasLength(1));
    expect(all.single.name, 'Evening');
    expect(all.single.startWork, '14:00');
    expect(all.single.endWork, '22:00');
    expect(all.single.lateGraceMinutes, 10);
    expect(all.single.earlyOutGraceMinutes, 15);
    expect(all.single.inUse, 0);
  });

  test('the same name in another case is refused', () async {
    await addShift(name: 'Evening');

    expect(
      () => addShift(name: 'evening', start: '15:00'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorShiftExists,
        ),
      ),
    );
  });

  test('a shift that ends before it starts is refused', () async {
    expect(
      () => addShift(start: '17:00', end: '09:00'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorShiftInvalidHours,
        ),
      ),
    );
  });

  test('allowances that swallow the whole day are refused', () async {
    // Eight hours of day, four forgiven at each end: every arrival would be on
    // time and every departure acceptable, and the day would judge nothing.
    expect(
      () => addShift(
        start: '09:00',
        end: '17:00',
        lateGrace: 240,
        earlyOutGrace: 240,
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorShiftInvalidHours,
        ),
      ),
    );
  });

  test(
    'the count of people on a shift is what the admin is warned with',
    () async {
      final shift = await addShift();
      await addEmployee(name: 'Sara', deviceUserId: '1', shiftId: shift.id);
      await addEmployee(name: 'Omar', deviceUserId: '2', shiftId: shift.id);
      await addEmployee(name: 'Lina', deviceUserId: '3');

      final all = await shifts.getShifts();
      expect(all.single.inUse, 2);
    },
  );

  test('deleting a shift puts its people back on the default hours', () async {
    final shift = await addShift();
    final id = await addEmployee(shiftId: shift.id);

    await shifts.deleteShift(shift.id);

    expect(await shifts.getShifts(), isEmpty);
    // Released, not deleted with it.
    final employee = await attendance.getEmployeeById(id);
    expect(employee, isNotNull);
    expect(employee!.shiftId, isNull);

    final schedules = await shifts.getSchedules();
    expect(schedules.of(employee).workStart, companyDefault.workStart);
  });

  // ------------------------------------------------------- resolving hours

  test('an employee on no shift is judged by the company default', () async {
    final id = await addEmployee();
    final employee = await attendance.getEmployeeById(id);

    final schedules = await shifts.getSchedules();
    expect(schedules.of(employee!).workStart, '09:00');
    expect(schedules.of(employee).workEnd, '17:00');
  });

  test(
    'a shift inherits the overtime window by its distance from the day',
    () async {
      // The default opens overtime 30 minutes after work ends and closes it 5
      // hours after. An evening shift ending at 22:00 gets the same distances.
      final shift = await addShift(start: '14:00', end: '22:00');
      final schedule = shift.scheduleFrom(companyDefault);

      expect(schedule.overtimeStart, '22:30');
      expect(schedule.overtimeEnd, '23:59'); // clamped rather than wrapping
    },
  );

  // -------------------------------------------------------------- the fold

  test(
    'two people scanning the same minute are judged by their own shifts',
    () async {
      final evening = await addShift(start: '14:00', end: '22:00');
      final onDefault = await addEmployee(name: 'Lina', deviceUserId: '1');
      final onEvening = await addEmployee(
        name: 'Omar',
        deviceUserId: '2',
        shiftId: evening.id,
      );

      // 14:05 is hours late for a 09:00 day and five minutes late for a 14:00
      // one — the same scan, two answers.
      await sync.ingest([
        punch('1', '2026-08-10 14:05:00'),
        punch('1', '2026-08-10 17:30:00'),
        punch('2', '2026-08-10 14:05:00'),
        punch('2', '2026-08-10 22:10:00'),
      ]);

      final byDefault = await attendance.findRecord(onDefault, '2026-08-10');
      final byEvening = await attendance.findRecord(onEvening, '2026-08-10');

      expect(byDefault!.status, 'late');
      expect(byEvening!.status, 'late');
      // The default day was over at 17:00, so leaving at 17:30 is not early.
      expect(byDefault.isEarlyLeave, isFalse);
      expect(byEvening.isEarlyLeave, isFalse);
    },
  );

  test(
    'leaving at the default closing time is early on an evening shift',
    () async {
      final evening = await addShift(start: '14:00', end: '22:00');
      final id = await addEmployee(shiftId: evening.id);

      await sync.ingest([
        punch('7', '2026-08-10 13:55:00'),
        punch('7', '2026-08-10 17:00:00'),
      ]);

      final record = await attendance.findRecord(id, '2026-08-10');
      expect(record!.status, 'early_leave');
      expect(record.isEarlyLeave, isTrue);
    },
  );

  // --------------------------------------------------------- the allowances

  test('arriving inside the late allowance is not late', () async {
    final shift = await addShift(start: '09:00', end: '17:00', lateGrace: 10);
    final id = await addEmployee(shiftId: shift.id);

    await sync.ingest([
      punch('7', '2026-08-10 09:08:00'),
      punch('7', '2026-08-10 17:05:00'),
    ]);

    final record = await attendance.findRecord(id, '2026-08-10');
    expect(record!.checkInTime, '09:08');
    expect(record.status, 'present');
  });

  test('arriving past the late allowance is still late', () async {
    final shift = await addShift(start: '09:00', end: '17:00', lateGrace: 10);
    final id = await addEmployee(shiftId: shift.id);

    await sync.ingest([
      punch('7', '2026-08-10 09:12:00'),
      punch('7', '2026-08-10 17:05:00'),
    ]);

    final record = await attendance.findRecord(id, '2026-08-10');
    expect(record!.status, 'late');
  });

  test(
    'leaving inside the early-out allowance is not an early leave',
    () async {
      final shift = await addShift(
        start: '09:00',
        end: '17:00',
        earlyOutGrace: 15,
      );
      final id = await addEmployee(shiftId: shift.id);

      await sync.ingest([
        punch('7', '2026-08-10 08:55:00'),
        punch('7', '2026-08-10 16:50:00'),
      ]);

      final record = await attendance.findRecord(id, '2026-08-10');
      expect(record!.checkOutTime, '16:50');
      expect(record.status, 'present');
      expect(record.isEarlyLeave, isFalse);
    },
  );

  test('leaving past the early-out allowance is an early leave', () async {
    final shift = await addShift(
      start: '09:00',
      end: '17:00',
      earlyOutGrace: 15,
    );
    final id = await addEmployee(shiftId: shift.id);

    await sync.ingest([
      punch('7', '2026-08-10 08:55:00'),
      punch('7', '2026-08-10 16:40:00'),
    ]);

    final record = await attendance.findRecord(id, '2026-08-10');
    expect(record!.status, 'early_leave');
    expect(record.isEarlyLeave, isTrue);
  });

  test(
    'the early-out allowance forgives the day without paying for it',
    () async {
      // The allowance moves only the early-leave line. Worked time still stops
      // where they actually left, or the app would pay for minutes nobody was
      // there for.
      final shift = await addShift(
        start: '09:00',
        end: '17:00',
        earlyOutGrace: 15,
      );
      final id = await addEmployee(shiftId: shift.id);

      await sync.ingest([
        punch('7', '2026-08-10 09:00:00'),
        punch('7', '2026-08-10 16:50:00'),
      ]);

      final employee = await attendance.getEmployeeById(id);
      final record = await attendance.findRecord(id, '2026-08-10');
      final schedules = await shifts.getSchedules();

      final totals = AttendanceDayTotals.forEmployee(
        record: record!,
        employee: employee!,
        schedule: schedules.of(employee),
      );

      expect(totals.status, 'present');
      expect(totals.worked, const Duration(hours: 7, minutes: 50));
      expect(totals.overtime, isNull);
    },
  );

  test('a correction is judged by the employee\'s own shift', () async {
    final evening = await addShift(start: '14:00', end: '22:00');
    final id = await addEmployee(shiftId: evening.id);

    // Only the day it happened, so the record has to be today's.
    final created = await attendance.createRecord(
      AttendanceRecordModel(
        id: '',
        employeeId: id,
        date: AttendanceRecordModel.isoDate(DateTime.now()),
        status: 'pending',
      ),
    );

    // On the company default this pair would be an ordinary day. On a 14:00
    // shift it is a departure five hours before the shift ends.
    final corrected = await attendance.correctPunches(
      recordId: created.id,
      checkInTime: '09:00',
      checkOutTime: '17:00',
      correctedBy: 'admin',
    );

    expect(corrected.status, 'early_leave');
    expect(corrected.isEarlyLeave, isTrue);
  });
}
