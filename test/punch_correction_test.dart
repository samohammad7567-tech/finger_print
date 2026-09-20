import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/localization/lang_keys.dart';
import 'package:attendence/core/network/api_exception.dart';
import 'package:attendence/features/attendance/data/data_source/attendance_local_data_source.dart';
import 'package:attendence/features/attendance/data/models/attendance_record_model.dart';

/// The admin's one same-day correction of a day's punches.
///
/// The window is the point of the feature, so it is checked where it is
/// enforced — in the data source — rather than trusted from a disabled button.
void main() {
  late AppDatabase database;
  late AttendanceLocalDataSource attendance;

  setUp(() async {
    database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    attendance = AttendanceLocalDataSource(database);
  });

  tearDown(() async => database.close());

  String today() => AttendanceRecordModel.isoDate(DateTime.now());

  String yesterday() => AttendanceRecordModel.isoDate(
    DateTime.now().subtract(const Duration(days: 1)),
  );

  Future<AttendanceRecordModel> record({
    String? date,
    String? checkIn = '08:00',
    String? checkOut = '17:10',
  }) async {
    final employee = await attendance.createEmployee({
      'full_name': 'Sara',
      'department': 'Ops',
    });
    return attendance.createRecord(
      AttendanceRecordModel(
        id: '',
        employeeId: employee.id,
        date: date ?? today(),
        checkInTime: checkIn,
        checkOutTime: checkOut,
        status: 'present',
      ),
    );
  }

  test('a correction rewrites the times and re-reads the day', () async {
    final r = await record(checkIn: '08:00');

    final corrected = await attendance.correctPunches(
      recordId: r.id,
      checkInTime: '09:20',
      checkOutTime: '17:10',
      correctedBy: 'Khalid',
    );

    expect(corrected.checkInTime, '09:20');
    // The status is worked out again: 09:20 is after the 09:00 start.
    expect(corrected.status, 'late');
    expect(corrected.isCorrected, isTrue);
    expect(corrected.correctedBy, 'Khalid');
  });

  test('the day can only be corrected once', () async {
    final r = await record();

    await attendance.correctPunches(recordId: r.id, checkInTime: '09:00');

    expect(
      () => attendance.correctPunches(recordId: r.id, checkInTime: '08:30'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorCorrectionUsed,
        ),
      ),
    );
  });

  test('a day that is not today cannot be corrected at all', () async {
    final r = await record(date: yesterday());

    expect(
      () => attendance.correctPunches(recordId: r.id, checkInTime: '09:00'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorCorrectionNotToday,
        ),
      ),
    );
  });

  test('a correction may clear a time that never happened', () async {
    final r = await record();

    final corrected = await attendance.correctPunches(
      recordId: r.id,
      checkInTime: '09:00',
      checkOutTime: null,
    );

    expect(corrected.checkOutTime, isNull);
    // Nothing recorded them leaving, so the day reads by its arrival alone.
    expect(corrected.status, 'present');
  });

  test(
    'clearing both times is refused rather than spending the one go',
    () async {
      final r = await record();

      expect(
        () => attendance.correctPunches(recordId: r.id),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorKey,
            'errorKey',
            LangKeys.errorCorrectionEmpty,
          ),
        ),
      );

      // Still available afterwards: a refused correction is not a spent one.
      final unchanged = await attendance.findRecord(r.employeeId, r.date);
      expect(unchanged!.isCorrected, isFalse);
    },
  );

  test('a departure before the arrival is refused', () async {
    final r = await record();

    expect(
      () => attendance.correctPunches(
        recordId: r.id,
        checkInTime: '17:00',
        checkOutTime: '08:00',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorCorrectionOrder,
        ),
      ),
    );
  });

  test('a time that is not a time is refused', () async {
    final r = await record();

    expect(
      () => attendance.correctPunches(recordId: r.id, checkInTime: '25:00'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.errorCorrectionTime,
        ),
      ),
    );
  });

  test(
    'correcting an arrival to after the day ends makes it an absence',
    () async {
      final r = await record(checkIn: '08:00', checkOut: '20:30');

      final corrected = await attendance.correctPunches(
        recordId: r.id,
        checkInTime: '18:00',
        checkOutTime: '20:30',
      );

      expect(corrected.status, 'absent');
    },
  );

  test('the window is judged by the record, not by the caller', () {
    final now = DateTime.now();
    const base = AttendanceRecordModel(id: 'r', employeeId: 'e', date: '');

    final todaysRow = AttendanceRecordModel(
      id: 'r',
      employeeId: 'e',
      date: AttendanceRecordModel.isoDate(now),
    );
    expect(todaysRow.canCorrectOn(now), isTrue);

    // Tomorrow's row is as closed as yesterday's: not before, not after.
    final tomorrow = AttendanceRecordModel(
      id: 'r',
      employeeId: 'e',
      date: AttendanceRecordModel.isoDate(now.add(const Duration(days: 1))),
    );
    expect(tomorrow.canCorrectOn(now), isFalse);

    expect(base.canCorrectOn(now), isFalse);
  });
}
