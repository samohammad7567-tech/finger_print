@Tags(['probe'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/features/attendance/data/data_source/attendance_local_data_source.dart';
import 'package:attendence/features/device/data/data_source/device_sync_data_source.dart';
import 'package:attendence/features/device/data/data_source/zk_device_gate.dart';
import 'package:attendence/features/device/data/data_source/zk_device_data_source.dart';
import 'package:attendence/features/device/data/models/device_settings_model.dart';

/// End-to-end check through the app's own data sources against the real
/// terminal. Excluded from the default suite by its tag.
///
///   flutter test test/device_live_test.dart --tags probe
const _settings = DeviceSettingsModel(
  ip: String.fromEnvironment('ZK_IP', defaultValue: '192.168.1.201'),
  port: int.fromEnvironment('ZK_PORT', defaultValue: 4370),
  // Deliberately blank: this is the case that used to fail, and it must now
  // resolve to the protocol's "no key" value on its own.
  commKey: '',
);

void main() {
  test('the app data source reaches the terminal with a blank comm key', () async {
    final device = ZkDeviceDataSource(ZkDeviceGate());

    final info = await device.testConnection(_settings);
    stdout.writeln('\n=== connection ===');
    stdout.writeln('  name     : ${info.deviceName}');
    stdout.writeln('  serial   : ${info.serialNumber}');
    stdout.writeln('  firmware : ${info.firmware}');
    stdout.writeln('  time     : ${info.deviceTime}');
    stdout.writeln('  drift    : ${info.clockDrift}');

    // A device that answered at all gives us at least one of these.
    expect(
      info.serialNumber ?? info.firmware ?? info.deviceTime?.toString(),
      isNotNull,
      reason: 'the terminal answered but reported nothing identifiable',
    );

    final users = await device.getDeviceUsers(_settings);
    stdout.writeln('\n=== ${users.length} enrolled users ===');
    for (final user in users) {
      stdout.writeln(
        '  id=${user.deviceUserId}  name="${user.name}"  uid=${user.uid}',
      );
    }

    final punches = await device.getPunches(_settings);
    stdout.writeln('\n=== ${punches.length} punches ===');
    for (final punch in punches.take(8)) {
      stdout.writeln(
        '  user=${punch.deviceUserId}  at=${punch.timestamp}  '
        'state=${punch.state} type=${punch.type}',
      );
    }

    // Fold the real punches into a real database and report what happens.
    final database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    final attendance = AttendanceLocalDataSource(database);
    final sync = DeviceSyncDataSource(database);

    final imported = (await sync.importEmployees(users)).created;
    stdout.writeln('\nimported $imported employees from the terminal');

    final result = await sync.ingest(punches, employeesImported: imported);
    stdout.writeln('\n=== fold ===');
    stdout.writeln(
      '  read=${result.punchesRead}  new=${result.punchesNew}  '
      'records=${result.recordsWritten}  unmapped=${result.unmappedUserIds}',
    );

    for (final employee in await attendance.getAllEmployees()) {
      final records = await attendance.getRecordsByEmployee(employee.id);
      for (final record in records) {
        stdout.writeln(
          '  ${employee.fullName.padRight(14)} ${record.date}  '
          'in=${record.checkInTime ?? '--:--'} out=${record.checkOutTime ?? '--:--'} '
          'bo=${record.breakOutTime ?? '--:--'} bi=${record.breakInTime ?? '--:--'} '
          'oi=${record.overtimeInTime ?? '--:--'} oo=${record.overtimeOutTime ?? '--:--'}  '
          '${record.status}',
        );
      }
    }

    await database.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
