import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/network/api_exception.dart';
import 'package:attendence/core/utils/name_matching.dart';
import 'package:attendence/core/utils/work_schedule.dart';
import 'package:attendence/features/attendance/data/data_source/attendance_local_data_source.dart';
import 'package:attendence/features/attendance/data/models/attendance_record_model.dart';
import 'package:attendence/features/device/data/data_source/device_sync_data_source.dart';
import 'package:attendence/features/device/data/models/device_settings_model.dart';

/// Covers the fold from raw terminal punches to day records — the logic that
/// cannot be checked against the hardware until the device is on the network.
void main() {
  late AppDatabase database;
  late DeviceSyncDataSource sync;
  late AttendanceLocalDataSource attendance;

  setUp(() async {
    database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    sync = DeviceSyncDataSource(database);
    attendance = AttendanceLocalDataSource(database);
  });

  tearDown(() async => database.close());

  Future<String> addEmployee({
    String name = 'Sara',
    String deviceUserId = '7',
    bool hasHousing = false,
    bool hasTravelPermission = false,
  }) async {
    final employee = await attendance.createEmployee({
      'full_name': name,
      'department': 'Ops',
      'device_user_id': deviceUserId,
      'has_housing': hasHousing,
      'has_travel_permission': hasTravelPermission,
    });
    return employee.id;
  }

  ZkPunchModel punch(String userId, String iso) =>
      ZkPunchModel(deviceUserId: userId, timestamp: DateTime.parse(iso));

  test('first punch becomes check-in, last becomes check-out', () async {
    final id = await addEmployee();

    await sync.ingest([
      punch('7', '2026-08-10 08:55:00'),
      punch('7', '2026-08-10 12:30:00'),
      punch('7', '2026-08-10 17:05:00'),
    ]);

    final record = await attendance.findRecord(id, '2026-08-10');
    expect(record, isNotNull);
    expect(record!.checkInTime, '08:55');
    expect(record.checkOutTime, '17:05');
    // In before 09:00 and out after 17:00.
    expect(record.status, 'present');
    expect(record.isEarlyLeave, isFalse);
  });

  test('a single punch is a check-in with no check-out', () async {
    final id = await addEmployee();

    await sync.ingest([punch('7', '2026-08-11 09:20:00')]);

    final record = await attendance.findRecord(id, '2026-08-11');
    expect(record!.checkInTime, '09:20');
    expect(record.checkOutTime, isNull);
    // Arrived after 09:00.
    expect(record.status, 'late');
  });

  test('double scans inside the debounce window collapse', () async {
    final id = await addEmployee();

    // A reader firing three times in seven seconds must not look like a shift.
    await sync.ingest([
      punch('7', '2026-08-12 08:30:00'),
      punch('7', '2026-08-12 08:30:03'),
      punch('7', '2026-08-12 08:30:07'),
    ]);

    final record = await attendance.findRecord(id, '2026-08-12');
    expect(record!.checkInTime, '08:30');
    expect(record.checkOutTime, isNull);
  });

  test('re-reading the same buffer writes nothing new', () async {
    await addEmployee();
    final punches = [
      punch('7', '2026-08-13 08:00:00'),
      punch('7', '2026-08-13 17:00:00'),
    ];

    final first = await sync.ingest(punches);
    final second = await sync.ingest(punches);

    expect(first.punchesNew, 2);
    expect(first.recordsWritten, 1);
    // The device returns its whole log every time; the second pass must be inert.
    expect(second.punchesNew, 0);
    expect(second.recordsWritten, 0);
  });

  test('leaving before 17:00 is an early leave', () async {
    final id = await addEmployee();

    await sync.ingest([
      punch('7', '2026-08-14 08:00:00'),
      punch('7', '2026-08-14 15:00:00'),
    ]);

    final record = await attendance.findRecord(id, '2026-08-14');
    expect(record!.status, 'early_leave');
    expect(record.isEarlyLeave, isTrue);
  });

  test('housing staff may leave from 16:30', () async {
    final id = await addEmployee(deviceUserId: '9', hasHousing: true);

    await sync.ingest([
      punch('9', '2026-08-17 08:00:00'),
      punch('9', '2026-08-17 16:35:00'),
    ]);

    final record = await attendance.findRecord(id, '2026-08-17');
    expect(record!.status, 'present');
    expect(record.isEarlyLeave, isFalse);
  });

  test(
    'travel permission uses the Thursday rule for that date, not today',
    () async {
      final id = await addEmployee(
        deviceUserId: '4',
        hasTravelPermission: true,
      );

      // 2026-08-13 is a Thursday; leaving at 14:30 is allowed.
      await sync.ingest([
        punch('4', '2026-08-13 08:00:00'),
        punch('4', '2026-08-13 14:30:00'),
      ]);

      final record = await attendance.findRecord(id, '2026-08-13');
      expect(record!.status, 'travel_permission');
    },
  );

  test(
    'punches for an unmapped id are parked, then applied on mapping',
    () async {
      final result = await sync.ingest([
        punch('88', '2026-08-18 08:10:00'),
        punch('88', '2026-08-18 17:30:00'),
      ]);

      // Nobody is mapped to 88 yet, so nothing is folded but nothing is lost.
      expect(result.punchesNew, 2);
      expect(result.recordsWritten, 0);
      expect(result.unmappedUserIds, contains('88'));

      final pending = await sync.getUnmappedUserIds();
      expect(pending.single.deviceUserId, '88');
      expect(pending.single.punchCount, 2);

      // Mapping the employee must recover the history already on disk.
      final id = await addEmployee(name: 'Omar', deviceUserId: '88');
      final written = await sync.refoldUnmapped();

      expect(written, 1);
      final record = await attendance.findRecord(id, '2026-08-18');
      expect(record!.checkInTime, '08:10');
      expect(record.checkOutTime, '17:30');
      expect(await sync.getUnmappedUserIds(), isEmpty);
    },
  );

  test(
    'device times widen a manual record without erasing its notes',
    () async {
      final id = await addEmployee();

      await attendance.createRecord(
        AttendanceRecordModel(
          id: '',
          employeeId: id,
          date: '2026-08-19',
          checkInTime: '09:30',
          checkOutTime: '16:00',
          status: 'late',
          notes: 'entered by guard',
          guardName: 'Khalid',
        ),
      );

      await sync.ingest([
        punch('7', '2026-08-19 08:45:00'),
        punch('7', '2026-08-19 17:10:00'),
      ]);

      final record = await attendance.findRecord(id, '2026-08-19');
      // Earliest arrival and latest departure win.
      expect(record!.checkInTime, '08:45');
      expect(record.checkOutTime, '17:10');
      // The human's work survives.
      expect(record.notes, 'entered by guard');
      expect(record.guardName, 'Khalid');
    },
  );

  /// A scan that carries the terminal's own mode code. Nothing should read it:
  /// the columns are worked out from the times whatever the device says.
  ZkPunchModel typed(String userId, String iso, ZkPunchType type) =>
      ZkPunchModel(
        deviceUserId: userId,
        timestamp: DateTime.parse(iso),
        type: type.code,
      );

  test('the day is split into its six columns by time alone', () async {
    final id = await addEmployee();

    await sync.ingest([
      punch('7', '2026-08-20 08:02:00'),
      punch('7', '2026-08-20 12:00:00'),
      punch('7', '2026-08-20 12:45:00'),
      punch('7', '2026-08-20 17:01:00'),
      punch('7', '2026-08-20 18:00:00'),
      punch('7', '2026-08-20 20:30:00'),
    ]);

    final r = await attendance.findRecord(id, '2026-08-20');
    expect(r!.checkInTime, '08:02');
    expect(r.breakOutTime, '12:00');
    expect(r.breakInTime, '12:45');
    expect(r.checkOutTime, '17:01');
    expect(r.overtimeInTime, '18:00');
    expect(r.overtimeOutTime, '20:30');
    expect(r.status, 'present');
  });

  test('out-of-order punches still land in the right columns', () async {
    final id = await addEmployee();

    // The device buffer is not guaranteed to arrive sorted.
    await sync.ingest([
      punch('7', '2026-08-21 17:05:00'),
      punch('7', '2026-08-21 08:00:00'),
      punch('7', '2026-08-21 12:30:00'),
      punch('7', '2026-08-21 12:00:00'),
    ]);

    final r = await attendance.findRecord(id, '2026-08-21');
    expect(r!.checkInTime, '08:00');
    expect(r.checkOutTime, '17:05');
    expect(r.breakOutTime, '12:00');
    expect(r.breakInTime, '12:30');
  });

  test('every break of the day is kept, not just the first', () async {
    final id = await addEmployee();

    await sync.ingest([
      punch('7', '2026-08-24 08:00:00'),
      punch('7', '2026-08-24 10:00:00'),
      punch('7', '2026-08-24 10:15:00'),
      punch('7', '2026-08-24 13:00:00'),
      punch('7', '2026-08-24 13:40:00'),
      punch('7', '2026-08-24 15:30:00'),
      punch('7', '2026-08-24 15:50:00'),
      punch('7', '2026-08-24 17:00:00'),
    ]);

    final r = await attendance.findRecord(id, '2026-08-24');
    expect(r!.breaks.map((b) => '${b.out}-${b.backIn}'), [
      '10:00-10:15',
      '13:00-13:40',
      '15:30-15:50',
    ]);
    expect(r.checkInTime, '08:00');
    expect(r.checkOutTime, '17:00');
    // The old single-break columns stay as the summary they always were.
    expect(r.breakOutTime, '10:00');
    expect(r.breakInTime, '15:50');
  });

  test(
    'a break nobody scanned back from stays on record, still open',
    () async {
      final id = await addEmployee();

      await sync.ingest([
        punch('7', '2026-08-30 08:00:00'),
        punch('7', '2026-08-30 10:00:00'),
        punch('7', '2026-08-30 10:20:00'),
        punch('7', '2026-08-30 13:00:00'),
        punch('7', '2026-08-30 17:05:00'),
      ]);

      final r = await attendance.findRecord(id, '2026-08-30');
      expect(r!.breaks, hasLength(2));
      expect(r.breaks.first.backIn, '10:20');
      expect(r.breaks.last.out, '13:00');
      expect(r.breaks.last.isClosed, isFalse);
      expect(r.checkOutTime, '17:05');
    },
  );

  test('the mode the terminal reports is ignored', () async {
    final id = await addEmployee();

    // Every scan claims to be a check-in — how a terminal reports a day when
    // nobody pressed a mode key. The times are what decide.
    await sync.ingest([
      typed('7', '2026-08-25 07:58:00', ZkPunchType.checkIn),
      typed('7', '2026-08-25 12:10:00', ZkPunchType.checkIn),
      typed('7', '2026-08-25 12:50:00', ZkPunchType.checkIn),
      typed('7', '2026-08-25 17:20:00', ZkPunchType.checkIn),
    ]);

    final r = await attendance.findRecord(id, '2026-08-25');
    expect(r!.checkInTime, '07:58');
    expect(r.breakOutTime, '12:10');
    expect(r.breakInTime, '12:50');
    expect(r.checkOutTime, '17:20');
  });

  test('a missed scan back from lunch still leaves a departure', () async {
    final id = await addEmployee();

    // Out at 12:10, back without scanning, gone at 17:20. The odd punch count
    // must not turn the last scan of the day into an arrival.
    await sync.ingest([
      punch('7', '2026-08-28 07:58:00'),
      punch('7', '2026-08-28 12:10:00'),
      punch('7', '2026-08-28 17:20:00'),
    ]);

    final r = await attendance.findRecord(id, '2026-08-28');
    expect(r!.checkInTime, '07:58');
    expect(r.checkOutTime, '17:20');
    expect(r.breaks.single.out, '12:10');
    expect(r.breaks.single.isClosed, isFalse);
    expect(r.breakInTime, isNull);
    expect(r.status, 'present');
  });

  test('leaving and coming back after hours is overtime', () async {
    final id = await addEmployee();

    await sync.ingest([
      punch('7', '2026-08-31 08:00:00'),
      punch('7', '2026-08-31 17:10:00'),
      punch('7', '2026-08-31 18:00:00'),
      punch('7', '2026-08-31 21:15:00'),
    ]);

    final r = await attendance.findRecord(id, '2026-08-31');
    expect(r!.checkInTime, '08:00');
    expect(r.checkOutTime, '17:10');
    expect(r.overtimeInTime, '18:00');
    expect(r.overtimeOutTime, '21:15');
  });

  test('turning up only after the day has ended is an absence', () async {
    final id = await addEmployee();

    // In at 18:00, gone at 20:30. The working day was over before they
    // arrived, so it is an absence — the hours are overtime, not attendance.
    await sync.ingest([
      punch('7', '2026-09-07 18:00:00'),
      punch('7', '2026-09-07 20:30:00'),
    ]);

    final r = await attendance.findRecord(id, '2026-09-07');
    expect(r!.checkInTime, '18:00');
    expect(r.checkOutTime, '20:30');
    expect(r.status, 'absent');
    // Leaving after the end of the day is not an early leave.
    expect(r.isEarlyLeave, isFalse);
  });

  test('an absence stands whatever the departure looks like', () async {
    final id = await addEmployee();

    // In at 17:10 and out at 17:25: after the day ended, and before the
    // overtime window opens. Still an absence, and nothing to pay.
    await sync.ingest([
      punch('7', '2026-09-08 17:10:00'),
      punch('7', '2026-09-08 17:25:00'),
    ]);

    final r = await attendance.findRecord(id, '2026-09-08');
    expect(r!.status, 'absent');
  });

  test('a late scan with no return recorded moves the departure', () async {
    final id = await addEmployee();

    // Out at 17:10, back without scanning, gone at 19:00. With nothing marking
    // the return there is no overtime shift to report — but the day plainly
    // ended at 19:00, not 17:10.
    await sync.ingest([
      punch('7', '2026-09-03 08:00:00'),
      punch('7', '2026-09-03 17:10:00'),
      punch('7', '2026-09-03 19:00:00'),
    ]);

    final r = await attendance.findRecord(id, '2026-09-03');
    expect(r!.checkOutTime, '19:00');
    expect(r.overtimeInTime, isNull);
    expect(r.overtimeOutTime, isNull);
  });

  test('the admin\'s working hours decide where the day ends', () async {
    final id = await addEmployee();

    // A 07:00–15:00 day. The 15:30 scan ends it, which makes the pair after it
    // an overtime shift — under the default 17:00 the same punches would read
    // as a long break instead.
    final early = DeviceSyncDataSource(
      database,
      () => const WorkSchedule(
        workStart: '07:00',
        workEnd: '15:00',
        overtimeStart: '15:00',
        overtimeEnd: '20:00',
      ),
    );

    await early.ingest([
      punch('7', '2026-09-04 07:00:00'),
      punch('7', '2026-09-04 15:30:00'),
      punch('7', '2026-09-04 16:00:00'),
      punch('7', '2026-09-04 18:00:00'),
    ]);

    final r = await attendance.findRecord(id, '2026-09-04');
    expect(r!.checkInTime, '07:00');
    expect(r.checkOutTime, '15:30');
    expect(r.overtimeInTime, '16:00');
    expect(r.overtimeOutTime, '18:00');
    expect(r.breaks, isEmpty);
    expect(r.status, 'present');
  });

  test('a lone scan late in the day is a departure, not an arrival', () async {
    final id = await addEmployee();

    await sync.ingest([punch('7', '2026-09-01 17:40:00')]);

    final r = await attendance.findRecord(id, '2026-09-01');
    expect(r!.checkInTime, isNull);
    expect(r.checkOutTime, '17:40');
    // No arrival on record yet, so the day is not judged.
    expect(r.status, 'pending');
  });

  test(
    'a refold applies the current rules to punches already stored',
    () async {
      final id = await addEmployee();

      await sync.ingest([
        punch('7', '2026-09-02 08:05:00'),
        punch('7', '2026-09-02 12:00:00'),
        punch('7', '2026-09-02 12:40:00'),
        punch('7', '2026-09-02 17:30:00'),
      ]);

      // A day the device wrote is rebuilt, not merged with, so re-reading the
      // punch log can move a time rather than only widen it.
      await attendance.updateRecord(
        (await attendance.findRecord(id, '2026-09-02'))!.id,
        {'check_out_time': '23:00'},
      );

      expect(await sync.refoldRange('2026-09-01', '2026-09-30'), 1);

      final r = await attendance.findRecord(id, '2026-09-02');
      expect(r!.checkOutTime, '17:30');
      expect(r.breakOutTime, '12:00');
    },
  );

  test('a corrected day is not rewritten by a later sync', () async {
    final id = await addEmployee();
    final today = AttendanceRecordModel.isoDate(DateTime.now());

    // The terminal wrote the day first, missing the real arrival.
    await sync.ingest([
      punch('7', '$today 08:00:00'),
      punch('7', '$today 17:10:00'),
    ]);

    final before = await attendance.findRecord(id, today);
    await attendance.correctPunches(
      recordId: before!.id,
      checkInTime: '09:20',
      checkOutTime: '17:10',
    );

    // The punches are read again and still hold the original 08:00.
    await sync.refoldRange(today, today);

    final after = await attendance.findRecord(id, today);
    // The admin's one correction stands.
    expect(after!.checkInTime, '09:20');
    expect(after.status, 'late');
    expect(after.isCorrected, isTrue);
  });

  test('employees are imported from the enrolment list', () async {
    final created = await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '1', name: 'ابو يوسف', uid: 4),
      ZkDeviceUserModel(deviceUserId: '2', name: 'ابو عمرو', uid: 3),
      ZkDeviceUserModel(deviceUserId: '3', name: '', uid: 2),
    ]);
    expect(created.created, 3);
    expect(created.pending, 0);

    final employees = await attendance.getAllEmployees();
    expect(employees.length, 3);
    expect(
      employees.firstWhere((e) => e.deviceUserId == '1').fullName,
      'ابو يوسف',
    );
    // A blank name on the terminal still needs something to show in a list.
    expect(
      employees.firstWhere((e) => e.deviceUserId == '3').fullName,
      'Device #3',
    );

    // Importing again must not duplicate anyone.
    final again = await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '1', name: 'ابو يوسف', uid: 4),
    ]);
    expect(again.created, 0);
    expect((await attendance.getAllEmployees()).length, 3);
  });

  test('somebody already on file is held for review, not duplicated', () async {
    // Entered by hand long before the terminal knew about them, so they carry
    // no device id at all — the case that used to import a second copy.
    final existing = await attendance.createEmployee({
      'full_name': 'ابو خالد',
      'department': 'Ops',
    });

    final outcome = await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '7', name: 'ابو خالد', uid: 9),
    ]);

    expect(outcome.created, 0, reason: 'no second copy may be created');
    expect(outcome.pending, 1);
    expect(await attendance.getAllEmployees(), hasLength(1));

    final matches = await sync.getPendingMatches();
    expect(matches.single.deviceUserId, '7');
    expect(matches.single.candidates.single.employeeId, existing.id);
    expect(matches.single.isUnambiguous, isTrue);

    // And the question must not multiply on every poll.
    final again = await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '7', name: 'ابو خالد', uid: 9),
    ]);
    expect(again.pending, 1);
    expect(await sync.pendingMatchCount(), 1);
  });

  test('a difference in Arabic spelling is still the same person', () async {
    // The form has the hamza; the terminal keypad does not.
    await attendance.createEmployee({
      'full_name': 'أبو خالد',
      'department': 'Ops',
    });

    final outcome = await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '7', name: 'ابو  خالد ', uid: 9),
    ]);

    expect(outcome.created, 0);
    expect(outcome.pending, 1);
  });

  test('a missing family name is offered, but only as a partial', () async {
    await attendance.createEmployee({
      'full_name': 'محمد علي الحربي',
      'department': 'Ops',
    });

    await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '7', name: 'محمد علي', uid: 9),
    ]);

    final match = (await sync.getPendingMatches()).single;
    expect(match.candidates.single.confidence, NameMatchConfidence.partial);
    expect(
      match.isUnambiguous,
      isFalse,
      reason: 'a shortened name is a guess an admin has to confirm',
    );
  });

  test('one shared first name is a coincidence, not a match', () async {
    await attendance.createEmployee({
      'full_name': 'محمد الحربي',
      'department': 'Ops',
    });

    final outcome = await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '7', name: 'محمد السالم', uid: 9),
    ]);

    expect(
      outcome.created,
      1,
      reason: 'a genuine new hire must not be held up',
    );
    expect(outcome.pending, 0);
  });

  test(
    'two people of the same name are both offered and neither chosen',
    () async {
      final first = await attendance.createEmployee({
        'full_name': 'محمد علي',
        'department': 'Ops',
      });
      final second = await attendance.createEmployee({
        'full_name': 'محمد علي',
        'department': 'Security',
      });

      await sync.importEmployees(const [
        ZkDeviceUserModel(deviceUserId: '7', name: 'محمد علي', uid: 9),
      ]);

      final match = (await sync.getPendingMatches()).single;
      expect(match.candidates.map((c) => c.employeeId).toSet(), {
        first.id,
        second.id,
      });
      expect(match.isUnambiguous, isFalse);
      // Nothing may be written while the answer is genuinely unknown.
      expect(await attendance.getAllEmployees(), hasLength(2));
    },
  );

  test(
    'confirming a match links the existing employee and replays history',
    () async {
      final existing = await attendance.createEmployee({
        'full_name': 'ابو خالد',
        'department': 'Ops',
      });

      await sync.importEmployees(const [
        ZkDeviceUserModel(deviceUserId: '7', name: 'ابو خالد', uid: 9),
      ]);

      // Their punches arrive while the question is still open. They are parked,
      // not dropped — that is what makes the wait free.
      await sync.ingest([
        typed('7', '2026-08-28 08:00:00', ZkPunchType.checkIn),
        typed('7', '2026-08-28 17:00:00', ZkPunchType.checkOut),
      ]);
      expect((await sync.getUnmappedUserIds()).single.deviceUserId, '7');
      expect(await attendance.getRecordsByEmployee(existing.id), isEmpty);

      await sync.confirmPendingMatch(
        deviceUserId: '7',
        employeeId: existing.id,
      );
      await sync.refoldUnmapped();

      // Still one person, now carrying the terminal id and the day they worked.
      final employees = await attendance.getAllEmployees();
      expect(employees, hasLength(1));
      expect(employees.single.id, existing.id);
      expect(employees.single.deviceUserId, '7');

      final records = await attendance.getRecordsByEmployee(existing.id);
      expect(records.single.date, '2026-08-28');
      expect(records.single.checkInTime, '08:00');

      expect(await sync.getPendingMatches(), isEmpty);
      expect(await sync.getUnmappedUserIds(), isEmpty);
    },
  );

  test('rejecting a match creates the separate person after all', () async {
    final existing = await attendance.createEmployee({
      'full_name': 'محمد علي',
      'department': 'Ops',
    });

    await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '7', name: 'محمد علي', uid: 9),
    ]);
    await sync.rejectPendingMatch('7');

    final employees = await attendance.getAllEmployees();
    expect(employees, hasLength(2));
    expect(
      employees.firstWhere((e) => e.id == existing.id).deviceUserId,
      isNull,
    );

    final created = employees.firstWhere((e) => e.id != existing.id);
    expect(created.deviceUserId, '7');
    expect(created.fullName, 'محمد علي');
    // Created through the same counter as everyone else.
    expect(created.employeeId, 'EMP002');

    expect(await sync.getPendingMatches(), isEmpty);
  });

  test('linking an employee by hand retires the question', () async {
    final existing = await attendance.createEmployee({
      'full_name': 'ابو خالد',
      'department': 'Ops',
    });

    await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '7', name: 'ابو خالد', uid: 9),
    ]);
    expect(await sync.pendingMatchCount(), 1);

    // The mapping card answers it instead of the review card.
    await attendance.updateEmployee(existing.id, {'device_user_id': '7'});

    expect(
      await sync.getPendingMatches(),
      isEmpty,
      reason: 'the candidate is no longer unlinked, so there is no question',
    );
  });

  test('the pending count follows the questions in and out', () async {
    // What the employee screen's banner reads, so it has to be right at every
    // step and not only once the review screen is open.
    expect(await sync.pendingMatchCount(), 0);

    final first = await attendance.createEmployee({
      'full_name': 'ابو خالد',
      'department': 'Ops',
    });
    await attendance.createEmployee({
      'full_name': 'ابو عمرو',
      'department': 'Ops',
    });

    await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '7', name: 'ابو خالد', uid: 9),
      ZkDeviceUserModel(deviceUserId: '8', name: 'ابو عمرو', uid: 10),
    ]);
    expect(await sync.pendingMatchCount(), 2);

    await sync.confirmPendingMatch(deviceUserId: '7', employeeId: first.id);
    expect(await sync.pendingMatchCount(), 1);

    await sync.rejectPendingMatch('8');
    expect(
      await sync.pendingMatchCount(),
      0,
      reason: 'the banner has to go away once both are answered',
    );
  });

  test('a device user with no name is created rather than held', () async {
    await attendance.createEmployee({
      'full_name': 'ابو خالد',
      'department': 'Ops',
    });

    final outcome = await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '7', name: '', uid: 9),
    ]);

    expect(outcome.created, 1);
    expect(outcome.pending, 0);
  });

  test('imported employees pick up their punches in the same run', () async {
    await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '5', name: 'ابو خالد', uid: 9),
    ]);

    final result = await sync.ingest([
      typed('5', '2026-08-26 08:00:00', ZkPunchType.checkIn),
      typed('5', '2026-08-26 17:00:00', ZkPunchType.checkOut),
    ], employeesImported: 1);

    expect(result.employeesImported, 1);
    expect(result.unmappedUserIds, isEmpty);
    expect(result.recordsWritten, 1);
  });

  test('a dismissed device user is not re-imported by the next sync', () async {
    // Imported once, as a normal sync would.
    const enrolled = [
      ZkDeviceUserModel(deviceUserId: '1', name: 'ابو يوسف', uid: 4),
      ZkDeviceUserModel(deviceUserId: '2', name: 'ابو عمرو', uid: 3),
    ];
    expect((await sync.importEmployees(enrolled)).created, 2);

    // The admin deletes one. The terminal still has them enrolled, so without
    // a tombstone the next sync would silently undo the deletion.
    final target = (await attendance.getAllEmployees()).firstWhere(
      (e) => e.deviceUserId == '1',
    );
    await attendance.deleteEmployee(target.id);
    await sync.dismissDeviceUser('1', removedFromDevice: true);

    expect((await sync.importEmployees(enrolled)).created, 0);

    final remaining = await attendance.getAllEmployees();
    expect(remaining, hasLength(1));
    expect(remaining.single.deviceUserId, '2');
  });

  test('dismissing detaches their punches without destroying them', () async {
    await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '1', name: 'ابو يوسف', uid: 4),
    ]);
    await sync.ingest([
      typed('1', '2026-08-27 08:00:00', ZkPunchType.checkIn),
      typed('1', '2026-08-27 17:00:00', ZkPunchType.checkOut),
    ]);

    final target = (await attendance.getAllEmployees()).single;
    await attendance.deleteEmployee(target.id);
    await sync.dismissDeviceUser('1', removedFromDevice: true);

    // The punches survive as history, now belonging to nobody.
    final unmapped = await sync.getUnmappedUserIds();
    expect(unmapped.single.deviceUserId, '1');
    expect(unmapped.single.punchCount, 2);

    // And a re-fold must not resurrect the employee.
    expect(await sync.refoldUnmapped(), 0);
    expect(await attendance.getAllEmployees(), isEmpty);
  });

  group('deleted people the terminal still knows', () {
    // The state a real database reached: every id on the device carried an old
    // tombstone, so the fetch imported nobody and said only "added 0".
    const enrolled = [
      ZkDeviceUserModel(deviceUserId: '1', name: 'ابو يوسف', uid: 4),
      ZkDeviceUserModel(deviceUserId: '2', name: 'ابو عمرو', uid: 3),
      ZkDeviceUserModel(deviceUserId: '3', name: 'محمد علي', uid: 2),
    ];

    test('a fetch that imports nobody says who it refused', () async {
      for (final user in enrolled) {
        await sync.dismissDeviceUser(
          user.deviceUserId,
          removedFromDevice: false,
        );
      }

      final outcome = await sync.importEmployees(enrolled);

      expect(outcome.created, 0);
      expect(outcome.pending, 0);
      // The part that was missing: a bare zero is indistinguishable from a
      // broken cable, so the refusals are named.
      expect(outcome.dismissed.map((u) => u.deviceUserId).toList(), [
        '1',
        '2',
        '3',
      ]);
      expect(outcome.dismissed.first.name, 'ابو يوسف');
    });

    test('restoring lets the next fetch bring them back', () async {
      for (final user in enrolled) {
        await sync.dismissDeviceUser(
          user.deviceUserId,
          removedFromDevice: false,
        );
      }
      expect((await sync.importEmployees(enrolled)).created, 0);

      final lifted = await sync.restoreDeviceUsers(['1', '3']);
      expect(lifted, 2);

      final outcome = await sync.importEmployees(enrolled);
      expect(outcome.created, 2);
      // The one left ticked off stays out, which is the whole point of asking.
      expect(outcome.dismissed.single.deviceUserId, '2');

      final names = (await attendance.getAllEmployees())
          .map((e) => e.fullName)
          .toSet();
      expect(names, {'ابو يوسف', 'محمد علي'});
    });

    test('restoring replays the punches they made before', () async {
      await sync.importEmployees(const [
        ZkDeviceUserModel(deviceUserId: '1', name: 'ابو يوسف', uid: 4),
      ]);
      await sync.ingest([
        typed('1', '2026-08-30 08:00:00', ZkPunchType.checkIn),
        typed('1', '2026-08-30 17:00:00', ZkPunchType.checkOut),
      ]);

      // Deleted, exactly as the employee screen does it.
      final gone = (await attendance.getAllEmployees()).single;
      await attendance.deleteEmployee(gone.id);
      await sync.dismissDeviceUser('1', removedFromDevice: false);
      expect(await attendance.getAllEmployees(), isEmpty);

      await sync.restoreDeviceUsers(['1']);
      await sync.importEmployees(const [
        ZkDeviceUserModel(deviceUserId: '1', name: 'ابو يوسف', uid: 4),
      ]);
      await sync.refoldUnmapped();

      // Back on file, and the day they worked came with them — the punches
      // were only detached, never destroyed.
      final back = (await attendance.getAllEmployees()).single;
      expect(back.deviceUserId, '1');
      final records = await attendance.getRecordsByEmployee(back.id);
      expect(records.single.date, '2026-08-30');
      expect(records.single.checkInTime, '08:00');
    });

    test('the deleted list reads back for the dialog to show', () async {
      await sync.dismissDeviceUser('1', removedFromDevice: true);
      await sync.dismissDeviceUser('2', removedFromDevice: false);

      final deleted = await sync.getDismissedDeviceUsers();
      expect(deleted.map((d) => d.deviceUserId).toSet(), {'1', '2'});
      expect(
        deleted.firstWhere((d) => d.deviceUserId == '1').removedFromDevice,
        isTrue,
      );
    });

    test('an empty restore is a no-op, not an error', () async {
      expect(await sync.restoreDeviceUsers(const []), 0);
      expect(await sync.restoreDeviceUsers(const ['   ']), 0);
    });
  });

  test('a delete the terminal refused is reported as stranded', () async {
    await sync.dismissDeviceUser('9', removedFromDevice: false);
    await sync.dismissDeviceUser('8', removedFromDevice: true);

    // Only the one still enrolled on the device needs the admin's attention.
    expect(await sync.getStrandedDeviceUsers(), ['9']);
  });

  test('restoring a dismissed user lets them be imported again', () async {
    const enrolled = [
      ZkDeviceUserModel(deviceUserId: '1', name: 'ابو يوسف', uid: 4),
    ];
    await sync.dismissDeviceUser('1', removedFromDevice: false);
    expect((await sync.importEmployees(enrolled)).created, 0);

    await sync.restoreDeviceUser('1');
    expect((await sync.importEmployees(enrolled)).created, 1);
  });

  test('employee numbers run in sequence and never repeat', () async {
    final a = await attendance.createEmployee({
      'full_name': 'A',
      'department': 'Ops',
    });
    final b = await attendance.createEmployee({
      'full_name': 'B',
      'department': 'Ops',
    });
    final c = await attendance.createEmployee({
      'full_name': 'C',
      'department': 'Ops',
    });

    expect(a.employeeId, 'EMP001');
    expect(b.employeeId, 'EMP002');
    expect(c.employeeId, 'EMP003');
  });

  test(
    'deleting closes the gap and the next hire takes the freed number',
    () async {
      await attendance.createEmployee({'full_name': 'A', 'department': 'Ops'});
      final b = await attendance.createEmployee({
        'full_name': 'B',
        'department': 'Ops',
      });
      expect(b.employeeId, 'EMP002');

      // The admin wants a list that always reads 001..N. That trade is deliberate
      // and is the whole of the cost: a number identifies a row in this list, so
      // an exported report kept outside the app now names somebody else.
      await attendance.deleteEmployee(b.id);

      final c = await attendance.createEmployee({
        'full_name': 'C',
        'department': 'Ops',
      });
      expect(
        c.employeeId,
        'EMP002',
        reason: 'the number B gave up is the next one out',
      );

      final numbers =
          (await attendance.getAllEmployees()).map((e) => e.employeeId).toList()
            ..sort();
      expect(numbers, ['EMP001', 'EMP002']);
    },
  );

  test('only the people after the gap are renumbered', () async {
    final names = ['A', 'B', 'C', 'D'];
    final made = [
      for (final name in names)
        await attendance.createEmployee({
          'full_name': name,
          'department': 'Ops',
        }),
    ];
    expect(made.map((e) => e.employeeId), [
      'EMP001',
      'EMP002',
      'EMP003',
      'EMP004',
    ]);

    await attendance.deleteEmployee(made[1].id);

    // A keeps EMP001; C and D move up one. Nobody standing before the gap is
    // touched, which is why creation order is what the renumber follows.
    final after = {
      for (final e in await attendance.getAllEmployees())
        e.fullName: e.employeeId,
    };
    expect(after, {'A': 'EMP001', 'C': 'EMP002', 'D': 'EMP003'});
  });

  test('resequencing repairs a list with a missing number and a gap', () async {
    // The shape a real database drifts into: somebody imported without a
    // number at all, somebody else sitting far up the range.
    await attendance.createEmployee({
      'full_name': 'A',
      'department': 'Ops',
      'employee_id': 'EMP009',
    });
    final b = await attendance.createEmployee({
      'full_name': 'B',
      'department': 'Ops',
    });
    await attendance.updateEmployee(b.id, {'employee_id': null});

    final changed = await attendance.resequenceEmployeeNumbers();
    expect(changed, 2);

    final after = {
      for (final e in await attendance.getAllEmployees())
        e.fullName: e.employeeId,
    };
    expect(after, {'A': 'EMP001', 'B': 'EMP002'});

    // And the counter now points at the end of the list, not past it.
    final next = await attendance.createEmployee({
      'full_name': 'C',
      'department': 'Ops',
    });
    expect(next.employeeId, 'EMP003');
  });

  test('resequencing an already tidy list changes nothing', () async {
    await attendance.createEmployee({'full_name': 'A', 'department': 'Ops'});
    await attendance.createEmployee({'full_name': 'B', 'department': 'Ops'});

    expect(await attendance.resequenceEmployeeNumbers(), 0);
  });

  test('deleting everybody starts the numbering over', () async {
    final a = await attendance.createEmployee({
      'full_name': 'A',
      'department': 'Ops',
    });
    await attendance.deleteEmployee(a.id);

    final next = await attendance.createEmployee({
      'full_name': 'B',
      'department': 'Ops',
    });
    expect(next.employeeId, 'EMP001');
  });

  test('renumbering never disturbs anyone\'s attendance', () async {
    final a = await attendance.createEmployee({
      'full_name': 'A',
      'department': 'Ops',
    });
    final b = await attendance.createEmployee({
      'full_name': 'B',
      'department': 'Ops',
    });
    await attendance.updateEmployee(b.id, {'device_user_id': '7'});

    await sync.ingest([
      typed('7', '2026-08-29 08:00:00', ZkPunchType.checkIn),
      typed('7', '2026-08-29 17:00:00', ZkPunchType.checkOut),
    ]);
    expect(await attendance.getRecordsByEmployee(b.id), hasLength(1));

    // B's number moves from EMP002 to EMP001 when A goes. The records hang off
    // the internal id, so they must not so much as notice.
    await attendance.deleteEmployee(a.id);

    final moved = (await attendance.getAllEmployees()).single;
    expect(moved.id, b.id);
    expect(moved.employeeId, 'EMP001');
    expect(moved.deviceUserId, '7');
    expect(await attendance.getRecordsByEmployee(b.id), hasLength(1));
  });

  group('name clashes', () {
    test('two people of one name are reported, however it is spelt', () async {
      await attendance.createEmployee({
        'full_name': 'أبو خالد',
        'department': 'Ops',
      });
      await attendance.createEmployee({
        'full_name': 'ابو  خالد',
        'department': 'Security',
      });
      await attendance.createEmployee({
        'full_name': 'ابو يوسف',
        'department': 'Ops',
      });

      final clashes = await attendance.findNameClashes();
      expect(clashes, hasLength(1));
      expect(clashes.single.employees, hasLength(2));
      expect(clashes.single.employees.map((e) => e.department).toSet(), {
        'Ops',
        'Security',
      });
    });

    test('two enrolled fingerprints mean certainly different people', () async {
      final a = await attendance.createEmployee({
        'full_name': 'محمد علي',
        'department': 'Ops',
      });
      final b = await attendance.createEmployee({
        'full_name': 'محمد علي',
        'department': 'Security',
      });

      var clash = (await attendance.findNameClashes()).single;
      expect(
        clash.isDefinitelyDistinct,
        isFalse,
        reason: 'neither is enrolled yet, so they may still be one person',
      );

      await attendance.updateEmployee(a.id, {'device_user_id': '7'});
      await attendance.updateEmployee(b.id, {'device_user_id': '8'});

      clash = (await attendance.findNameClashes()).single;
      expect(clash.enrolled, hasLength(2));
      expect(
        clash.isDefinitelyDistinct,
        isTrue,
        reason: 'a fingerprint cannot be shared',
      );
    });

    test('renaming one of them settles it', () async {
      await attendance.createEmployee({
        'full_name': 'محمد علي',
        'department': 'Ops',
      });
      final b = await attendance.createEmployee({
        'full_name': 'محمد علي',
        'department': 'Security',
      });
      expect(await attendance.findNameClashes(), hasLength(1));

      await attendance.updateEmployee(b.id, {'full_name': 'محمد علي الحربي'});

      expect(await attendance.findNameClashes(), isEmpty);
    });

    test('a blank name is a data problem, not a clash', () async {
      await attendance.createEmployee({'full_name': '', 'department': 'Ops'});
      await attendance.createEmployee({
        'full_name': '   ',
        'department': 'Ops',
      });

      expect(await attendance.findNameClashes(), isEmpty);
    });
  });

  test('the sequence steps over a number entered by hand', () async {
    await attendance.createEmployee({
      'full_name': 'A',
      'department': 'Ops',
      'employee_id': 'EMP002',
    });

    final next = await attendance.createEmployee({
      'full_name': 'B',
      'department': 'Ops',
    });
    expect(next.employeeId, 'EMP003');
  });

  test('an explicit number is still honoured', () async {
    final custom = await attendance.createEmployee({
      'full_name': 'Custom',
      'department': 'Ops',
      'employee_id': 'CONTRACTOR-7',
    });
    expect(custom.employeeId, 'CONTRACTOR-7');

    // Trailing digits are what the sequence reads, so this becomes the base.
    final next = await attendance.createEmployee({
      'full_name': 'Next',
      'department': 'Ops',
    });
    expect(next.employeeId, 'EMP008');
  });

  test('a duplicate number is rejected', () async {
    await attendance.createEmployee({
      'full_name': 'A',
      'department': 'Ops',
      'employee_id': 'EMP001',
    });

    await expectLater(
      attendance.createEmployee({
        'full_name': 'B',
        'department': 'Ops',
        'employee_id': 'EMP001',
      }),
      throwsA(isA<ApiException>()),
    );
  });

  test('imported employees also get numbers', () async {
    await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '1', name: 'ابو يوسف', uid: 4),
      ZkDeviceUserModel(deviceUserId: '2', name: 'ابو عمرو', uid: 3),
    ]);

    final numbers = (await attendance.getAllEmployees())
        .map((e) => e.employeeId)
        .toList();
    expect(numbers, everyElement(isNotNull));
    expect(numbers.toSet(), hasLength(2));
  });

  test('the form and the device import share one number sequence', () async {
    final manual = await attendance.createEmployee({
      'full_name': 'Manual',
      'department': 'Ops',
    });
    expect(manual.employeeId, 'EMP001');

    await sync.importEmployees(const [
      ZkDeviceUserModel(deviceUserId: '1', name: 'From device', uid: 4),
    ]);

    final imported = (await attendance.getAllEmployees()).firstWhere(
      (e) => e.deviceUserId == '1',
    );
    expect(imported.employeeId, 'EMP002');

    // Back to the form — it must continue past the imported one.
    final next = await attendance.createEmployee({
      'full_name': 'After',
      'department': 'Ops',
    });
    expect(next.employeeId, 'EMP003');
  });
}
