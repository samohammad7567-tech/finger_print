import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/localization/lang_keys.dart';
import 'package:attendence/core/network/api_exception.dart';
import 'package:attendence/core/utils/attendance_utils.dart';
import 'package:attendence/core/utils/work_schedule.dart';
import 'package:attendence/features/attendance/data/models/attendance_day_totals.dart';
import 'package:attendence/features/attendance/data/models/attendance_record_model.dart';
import 'package:attendence/features/attendance/data/models/employee_model.dart';
import 'package:attendence/features/holidays/data/data_source/holidays_local_data_source.dart';
import 'package:attendence/features/holidays/data/models/holiday_model.dart';
import 'package:attendence/features/holidays/data/models/work_calendar.dart';

/// Which dates anybody was expected to work.
///
/// This is the question that has to be answered before any punch is read, so
/// what these check is that it *is* answered first: nobody is late for a day
/// they do not work, and nobody is absent from one.
void main() {
  const schedule = WorkSchedule(
    workStart: '09:00',
    workEnd: '17:00',
    overtimeStart: '17:30',
    overtimeEnd: '22:00',
  );

  const employee = EmployeeModel(id: 'e1', fullName: 'Sara', department: 'Ops');

  // 2026-08-10 is a Monday, so 2026-08-14 is a Friday and 15 a Saturday.
  const monday = '2026-08-10';
  const friday = '2026-08-14';

  group('rest days on the schedule', () {
    test('an empty set means every day is a working day', () {
      expect(schedule.isRestDay(DateTime.parse(friday)), isFalse);
      expect(schedule.isRestDay(DateTime.parse(monday)), isFalse);
    });

    test('a rest day is recognised by weekday, not by date', () {
      const resting = WorkSchedule(restDays: {DateTime.friday});

      expect(resting.isRestDay(DateTime.parse(friday)), isTrue);
      expect(resting.isRestDay(DateTime.parse(monday)), isFalse);
      // The Friday a week later, too.
      expect(resting.isRestDay(DateTime.parse('2026-08-21')), isTrue);
    });

    test('rest days survive a round trip through storage', () {
      const days = {DateTime.friday, DateTime.saturday};
      final encoded = WorkSchedule.encodeRestDays(days);

      expect(encoded, '5,6');
      expect(WorkSchedule.parseRestDays(encoded), days);
    });

    test('a malformed stored value means no rest days, not a crash', () {
      expect(WorkSchedule.parseRestDays('nonsense'), isEmpty);
      expect(WorkSchedule.parseRestDays(''), isEmpty);
      expect(WorkSchedule.parseRestDays(null), isEmpty);
      // Out-of-range days are dropped rather than kept as nonsense.
      expect(WorkSchedule.parseRestDays('0,5,9'), {DateTime.friday});
    });

    test('a shift that rests every day cannot be saved', () {
      const always = WorkSchedule(restDays: {1, 2, 3, 4, 5, 6, 7});
      expect(always.isValid, isFalse);
    });
  });

  group('the calendar', () {
    final eid = HolidayModel(
      id: 'h1',
      name: 'Eid',
      startDate: '2026-08-17',
      endDate: '2026-08-20',
    );

    test('a holiday covers every day of its range, both ends included', () {
      expect(eid.covers('2026-08-16'), isFalse);
      expect(eid.covers('2026-08-17'), isTrue);
      expect(eid.covers('2026-08-19'), isTrue);
      expect(eid.covers('2026-08-20'), isTrue);
      expect(eid.covers('2026-08-21'), isFalse);
      expect(eid.dayCount, 4);
    });

    test('a one-day holiday is a range whose ends match', () {
      const day = HolidayModel(
        id: 'h2',
        name: 'National Day',
        startDate: '2026-09-23',
        endDate: '2026-09-23',
      );
      expect(day.dayCount, 1);
      expect(day.covers('2026-09-23'), isTrue);
    });

    test('an empty calendar makes every date a working day', () {
      const calendar = WorkCalendar();
      expect(calendar.kindOfDate(monday, schedule), WorkingDayKind.working);
      expect(calendar.kindOfDate(friday, schedule), WorkingDayKind.working);
    });

    test('a rest day and a holiday are told apart', () {
      final calendar = WorkCalendar(holidays: [eid]);
      const resting = WorkSchedule(restDays: {DateTime.friday});

      expect(calendar.kindOfDate(monday, resting), WorkingDayKind.working);
      expect(calendar.kindOfDate(friday, resting), WorkingDayKind.restDay);
      expect(
        calendar.kindOfDate('2026-08-18', resting),
        WorkingDayKind.holiday,
      );
    });

    test('a holiday landing on a rest day is named as the holiday', () {
      // 2026-08-21 is a Friday, and this holiday covers it.
      final calendar = WorkCalendar(
        holidays: [
          const HolidayModel(
            id: 'h3',
            name: 'Shutdown',
            startDate: '2026-08-21',
            endDate: '2026-08-21',
          ),
        ],
      );
      const resting = WorkSchedule(restDays: {DateTime.friday});

      expect(
        calendar.kindOfDate('2026-08-21', resting),
        WorkingDayKind.holiday,
      );
    });

    test('an unparseable date is treated as a working day', () {
      final calendar = WorkCalendar(holidays: [eid]);
      expect(
        calendar.kindOfDate('not-a-date', schedule),
        WorkingDayKind.working,
      );
    });
  });

  group('how a day off is judged', () {
    AttendanceDayTotals day({
      String? checkIn,
      String? checkOut,
      String status = 'present',
      required WorkingDayKind kind,
      String date = friday,
    }) => AttendanceDayTotals.forEmployee(
      record: AttendanceRecordModel(
        id: 'r1',
        employeeId: employee.id,
        date: date,
        checkInTime: checkIn,
        checkOutTime: checkOut,
        status: status,
      ),
      employee: employee,
      schedule: schedule,
      dayKind: kind,
    );

    test('nobody is late for a rest day', () {
      // 11:00 is two hours past a 09:00 start — late on any working day.
      final totals = day(
        checkIn: '11:00',
        checkOut: '15:00',
        kind: WorkingDayKind.restDay,
      );

      expect(totals.flags, [AttendanceFlag.workedRestDay]);
      expect(totals.labelKeys, ['flag_rest_day']);
    });

    test('nobody leaves a holiday early', () {
      final totals = day(
        checkIn: '09:00',
        checkOut: '11:00',
        kind: WorkingDayKind.holiday,
      );

      expect(totals.flags, [AttendanceFlag.workedHoliday]);
      expect(totals.flags, isNot(contains(AttendanceFlag.leftEarly)));
    });

    test('turning up after hours on a rest day is not an absence', () {
      // On a working day this arrival — past the 17:00 end — reads as absent.
      final working = day(
        checkIn: '18:00',
        checkOut: '20:00',
        kind: WorkingDayKind.working,
      );
      expect(working.isAbsentArrival, isTrue);
      expect(working.flags, [AttendanceFlag.absent]);

      final resting = day(
        checkIn: '18:00',
        checkOut: '20:00',
        kind: WorkingDayKind.restDay,
      );
      expect(resting.isAbsentArrival, isFalse);
      expect(resting.flags, [AttendanceFlag.workedRestDay]);
    });

    test('the same times on a working day are judged as they always were', () {
      final totals = day(
        checkIn: '09:20',
        checkOut: '16:30',
        kind: WorkingDayKind.working,
        date: monday,
      );

      expect(totals.flags, [
        AttendanceFlag.arrivedLate,
        AttendanceFlag.leftEarly,
      ]);
    });

    test('a day off with nobody on it is named, not called "not recorded"', () {
      expect(dayKindLabelKey(WorkingDayKind.restDay), 'flag_rest_day');
      expect(dayKindLabelKey(WorkingDayKind.holiday), 'flag_holiday');
      expect(dayKindLabelKey(WorkingDayKind.working), 'not_recorded');
    });
  });

  group('storing holidays', () {
    late AppDatabase database;
    late HolidaysLocalDataSource holidays;

    setUp(() async {
      database = AppDatabase();
      await database.init(overridePath: inMemoryDatabasePath);
      holidays = HolidaysLocalDataSource(database);
    });

    tearDown(() async => database.close());

    Future<HolidayModel> add({
      String name = 'Eid',
      String start = '2026-08-17',
      String end = '2026-08-20',
      bool isPaid = true,
    }) => holidays.createHoliday(
      HolidayModel(
        id: '',
        name: name,
        startDate: start,
        endDate: end,
        isPaid: isPaid,
      ),
    );

    test('a stored holiday comes back with its range and paid flag', () async {
      await add(isPaid: false);

      final all = await holidays.getHolidays();
      expect(all, hasLength(1));
      expect(all.single.name, 'Eid');
      expect(all.single.startDate, '2026-08-17');
      expect(all.single.endDate, '2026-08-20');
      expect(all.single.isPaid, isFalse);
      expect(all.single.dayCount, 4);
    });

    test('a range that ends before it starts is refused', () async {
      expect(
        () => add(start: '2026-08-20', end: '2026-08-17'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorKey,
            'errorKey',
            LangKeys.errorHolidayInvalidRange,
          ),
        ),
      );
    });

    test('a blank name is refused', () async {
      expect(
        () => add(name: '   '),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorKey,
            'errorKey',
            LangKeys.errorHolidayNameRequired,
          ),
        ),
      );
    });

    test('the calendar read back from storage judges dates', () async {
      await add();

      final calendar = await holidays.getCalendar();
      expect(calendar.isEmpty, isFalse);
      expect(
        calendar.kindOfDate('2026-08-18', schedule),
        WorkingDayKind.holiday,
      );
      expect(calendar.kindOfDate(monday, schedule), WorkingDayKind.working);
    });

    test('deleting a holiday makes its dates working days again', () async {
      final saved = await add();
      await holidays.deleteHoliday(saved.id);

      final calendar = await holidays.getCalendar();
      expect(calendar.isEmpty, isTrue);
      expect(
        calendar.kindOfDate('2026-08-18', schedule),
        WorkingDayKind.working,
      );
    });
  });
}
