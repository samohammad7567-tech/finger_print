import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/utils/work_schedule.dart';
import 'package:attendence/features/attendance/data/data_source/attendance_local_data_source.dart';
import 'package:attendence/features/attendance/data/data_source/day_closing_data_source.dart';
import 'package:attendence/features/attendance/data/models/attendance_record_model.dart';
import 'package:attendence/features/device/data/data_source/device_sync_data_source.dart';
import 'package:attendence/features/device/data/models/device_settings_model.dart';
import 'package:attendence/features/holidays/data/models/holiday_model.dart';
import 'package:attendence/features/holidays/data/models/work_calendar.dart';
import 'package:attendence/features/permissions/data/data_source/permissions_local_data_source.dart';
import 'package:attendence/features/permissions/data/models/permission_request_model.dart';
import 'package:attendence/features/shifts/data/data_source/shifts_local_data_source.dart';
import 'package:attendence/features/shifts/data/models/shift_model.dart';

/// Writing down the days people were not here.
///
/// The device fold only ever creates a record when there are punches to fold,
/// so before this an absence produced no row at all. What these check is that
/// the pass fills that gap without ever inventing one: it adds a row only
/// where there is none, only on a day somebody was expected, and never on a
/// day the system itself has no evidence about.
void main() {
  const companyDefault = WorkSchedule(
    workStart: '09:00',
    workEnd: '17:00',
    overtimeStart: '17:30',
    overtimeEnd: '22:00',
  );

  // 2026-08-10 is a Monday; 2026-08-14 a Friday.
  const monday = '2026-08-10';
  const tuesday = '2026-08-11';
  const friday = '2026-08-14';

  late AppDatabase database;
  late AttendanceLocalDataSource attendance;
  late DayClosingDataSource closing;
  late DeviceSyncDataSource sync;
  late ShiftsLocalDataSource shifts;
  late PermissionsLocalDataSource permissions;

  /// The employee whose punches prove the system was running on a given day.
  String? witnessId;

  setUp(() async {
    database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    attendance = AttendanceLocalDataSource(database, () => companyDefault);
    closing = DayClosingDataSource(database, () => companyDefault);
    sync = DeviceSyncDataSource(database, () => companyDefault);
    shifts = ShiftsLocalDataSource(database, () => companyDefault);
    permissions = PermissionsLocalDataSource(database);
  });

  tearDown(() async {
    witnessId = null;
    await database.close();
  });

  /// Creates somebody who was already on file before the dates under test.
  ///
  /// The pass refuses to mark anybody absent from a day that predates their
  /// own record, which is right — but it means a test employee created "now"
  /// would be excluded from every past date. Backdating them is what makes
  /// these tests describe the ordinary case rather than that edge.
  Future<String> addEmployee({
    String name = 'Sara',
    String deviceUserId = '7',
    String? shiftId,
    String onFileSince = '2026-01-01T00:00:00.000',
  }) async {
    final employee = await attendance.createEmployee({
      'full_name': name,
      'department': 'Ops',
      'device_user_id': deviceUserId,
      'shift_id': shiftId,
    });
    await database.db.update(
      'employees',
      {'created_at': onFileSince},
      where: 'id = ?',
      whereArgs: [employee.id],
    );
    return employee.id;
  }

  ZkPunchModel punch(String userId, String iso) =>
      ZkPunchModel(deviceUserId: userId, timestamp: DateTime.parse(iso));

  /// One employee who did turn up, so the day has evidence the system was
  /// running. The pass refuses to close a day nothing at all was recorded on,
  /// so most of these tests need one.
  ///
  /// The same person every time — a second employee on the same terminal id
  /// would be refused, and the point is only that somebody scanned.
  Future<String> witness(String date) async {
    final id = witnessId ??= await addEmployee(
      name: 'Witness',
      deviceUserId: '99',
    );
    await sync.ingest([
      punch('99', '$date 08:55:00'),
      punch('99', '$date 17:05:00'),
    ]);
    return id;
  }

  /// The `source` column, which the record model does not expose — nothing in
  /// the app displays it, and it is read here only to prove a placeholder is
  /// distinguishable from a real punch.
  Future<String?> sourceOf(String employeeId, String date) async {
    final rows = await database.db.query(
      'attendance_records',
      columns: ['source'],
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['source'] as String?;
  }

  Future<DayClosingResult> close(
    String from,
    String to, {
    WorkCalendar calendar = const WorkCalendar(),
  }) => closing.closeThrough(from: from, to: to, calendar: calendar);

  test('somebody who never came in gets an absence', () async {
    await witness(monday);
    final absent = await addEmployee(name: 'Omar', deviceUserId: '1');

    final result = await close(monday, monday);

    expect(result.daysClosed, 1);
    expect(result.absencesRecorded, 1);

    final record = await attendance.findRecord(absent, monday);
    expect(record, isNotNull);
    expect(record!.status, 'absent');
    expect(record.checkInTime, isNull);
    expect(await sourceOf(absent, monday), DayClosingDataSource.source);
  });

  test('somebody who did come in is left alone', () async {
    final present = await witness(monday);

    await close(monday, monday);

    final record = await attendance.findRecord(present, monday);
    expect(record!.status, 'present');
    expect(record.checkInTime, '08:55');
    expect(await sourceOf(present, monday), 'device');
  });

  test('running it twice writes nothing the second time', () async {
    await witness(monday);
    await addEmployee(name: 'Omar', deviceUserId: '1');

    final first = await close(monday, monday);
    final second = await close(monday, monday);

    expect(first.absencesRecorded, 1);
    expect(second.absencesRecorded, 0);
  });

  test('a day nothing was recorded on is skipped, not closed', () async {
    // The whole workforce absent on one day is far more likely to mean the app
    // was not running. Inventing a company-wide absence from an outage is the
    // one mistake this must not make.
    await addEmployee(name: 'Omar', deviceUserId: '1');

    final result = await close(monday, monday);

    expect(result.daysClosed, 0);
    expect(result.daysSkipped, 1);
    expect(result.absencesRecorded, 0);
    // The marker still moves, so it is not rescanned forever.
    expect(result.closedThrough, monday);
  });

  test('a rest day is never an absence', () async {
    final resting = await shifts.createShift(
      const ShiftModel(
        id: '',
        name: 'Weekdays',
        startWork: '09:00',
        endWork: '17:00',
        restDays: {DateTime.friday},
      ),
    );
    await witness(friday);
    final off = await addEmployee(
      name: 'Omar',
      deviceUserId: '1',
      shiftId: resting.id,
    );

    final result = await close(friday, friday);

    expect(result.absencesRecorded, 0);
    expect(await attendance.findRecord(off, friday), isNull);
  });

  test('a holiday is never an absence', () async {
    await witness(monday);
    final off = await addEmployee(name: 'Omar', deviceUserId: '1');

    final calendar = WorkCalendar(
      holidays: [
        const HolidayModel(
          id: 'h1',
          name: 'Eid',
          startDate: monday,
          endDate: monday,
        ),
      ],
    );

    final result = await close(monday, monday, calendar: calendar);

    expect(result.absencesRecorded, 0);
    expect(await attendance.findRecord(off, monday), isNull);
  });

  test('one shift rests while another works the same day', () async {
    final resting = await shifts.createShift(
      const ShiftModel(
        id: '',
        name: 'Weekdays',
        startWork: '09:00',
        endWork: '17:00',
        restDays: {DateTime.friday},
      ),
    );
    await witness(friday);

    final off = await addEmployee(
      name: 'Omar',
      deviceUserId: '1',
      shiftId: resting.id,
    );
    // On no shift, so the company default — which rests on nothing.
    final working = await addEmployee(name: 'Lina', deviceUserId: '2');

    await close(friday, friday);

    expect(await attendance.findRecord(off, friday), isNull);
    expect((await attendance.findRecord(working, friday))!.status, 'absent');
  });

  test('approved leave is not an absence', () async {
    await witness(monday);
    final onLeave = await addEmployee(name: 'Omar', deviceUserId: '1');

    await permissions.createPermission(
      PermissionRequestModel(
        id: '',
        employeeId: onLeave,
        permissionType: 'vacation',
        date: monday,
        status: 'approved',
      ),
    );

    final result = await close(monday, monday);

    expect(result.absencesRecorded, 0);
    expect(await attendance.findRecord(onLeave, monday), isNull);
  });

  test('nobody is absent from a day before they were on file', () async {
    await witness(monday);
    // On file only from the Tuesday, so the Monday predates them.
    await addEmployee(
      name: 'New Starter',
      deviceUserId: '1',
      onFileSince:
          '$tuesday'
          'T09:00:00.000',
    );

    final result = await close(monday, monday);

    expect(result.absencesRecorded, 0);
  });

  test('an inactive employee is not marked absent', () async {
    await witness(monday);
    final left = await addEmployee(name: 'Omar', deviceUserId: '1');
    await attendance.updateEmployee(left, {'is_active': false});

    final result = await close(monday, monday);

    expect(result.absencesRecorded, 0);
  });

  test('a hand-entered record is never overwritten', () async {
    await witness(monday);
    final id = await addEmployee(name: 'Omar', deviceUserId: '1');

    await attendance.createRecord(
      AttendanceRecordModel(
        id: '',
        employeeId: id,
        date: monday,
        checkInTime: '09:30',
        status: 'late',
      ),
    );

    await close(monday, monday);

    final record = await attendance.findRecord(id, monday);
    expect(record!.status, 'late');
    expect(record.checkInTime, '09:30');
  });

  test('punches arriving later reclaim the closed day', () async {
    await witness(monday);
    final late = await addEmployee(name: 'Omar', deviceUserId: '1');

    await close(monday, monday);
    expect((await attendance.findRecord(late, monday))!.status, 'absent');

    // The terminal was unreachable when the day was closed; the backlog
    // arrives now.
    await sync.ingest([
      punch('1', '$monday 09:20:00'),
      punch('1', '$monday 17:10:00'),
    ]);

    final record = await attendance.findRecord(late, monday);
    expect(record!.checkInTime, '09:20');
    expect(record.checkOutTime, '17:10');
    expect(record.status, 'late');
    // No longer a placeholder, so a reopen cannot clear it away.
    expect(await sourceOf(late, monday), 'device');
  });

  test('a range closes every day in it', () async {
    await witness(monday);
    await witness(tuesday);
    final absent = await addEmployee(name: 'Omar', deviceUserId: '1');

    final result = await close(monday, tuesday);

    expect(result.daysClosed, 2);
    expect(result.absencesRecorded, 2);
    expect(result.closedThrough, tuesday);
    expect((await attendance.findRecord(absent, monday))!.status, 'absent');
    expect((await attendance.findRecord(absent, tuesday))!.status, 'absent');
  });

  test('a backwards range does nothing', () async {
    await witness(monday);
    await addEmployee(name: 'Omar', deviceUserId: '1');

    final result = await close(tuesday, monday);

    expect(result.didNothing, isTrue);
    expect(result.absencesRecorded, 0);
  });

  test('reopening clears the placeholders and nothing else', () async {
    final present = await witness(monday);
    final absent = await addEmployee(name: 'Omar', deviceUserId: '1');

    await close(monday, monday);
    final removed = await closing.reopenRange(monday, monday);

    expect(removed, 1);
    expect(await attendance.findRecord(absent, monday), isNull);
    // The day somebody actually worked survives it.
    expect(
      (await attendance.findRecord(present, monday))!.checkInTime,
      '08:55',
    );
  });
}
