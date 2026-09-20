@Tags(['probe'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/features/device/data/data_source/zk_device_gate.dart';
import 'package:attendence/features/device/data/data_source/zk_device_data_source.dart';
import 'package:attendence/features/device/data/data_source/zk_enrollment_data_source.dart';
import 'package:attendence/features/device/data/models/device_settings_model.dart';

/// Proves a user created by the app can be removed from the terminal again,
/// which is what the employee delete now relies on.
const _settings = DeviceSettingsModel(ip: '192.168.1.201', port: 4370);

void main() {
  test('deleteUser removes the person from the terminal', () async {
    final device = ZkDeviceDataSource(ZkDeviceGate());
    final enrollment = ZkEnrollmentDataSource(ZkDeviceGate());

    final before = await device.getDeviceUsers(_settings);
    stdout.writeln('\nbefore: ${before.length} users');

    final created = await enrollment.upsertUser(_settings, name: 'حذف تجريبي');
    stdout.writeln(
      'created deviceUserId=${created.deviceUserId} uid=${created.uid}',
    );

    final mid = await device.getDeviceUsers(_settings);
    expect(mid.length, before.length + 1);

    final removed = await enrollment.deleteUser(
      _settings,
      deviceUserId: created.deviceUserId,
    );
    stdout.writeln('deleteUser returned: $removed');
    expect(removed, isTrue);

    final after = await device.getDeviceUsers(_settings);
    stdout.writeln('after: ${after.length} users');
    for (final u in after) {
      stdout.writeln('  id=${u.deviceUserId} uid=${u.uid} name="${u.name}"');
    }

    expect(
      after.map((u) => u.deviceUserId).toSet(),
      before.map((u) => u.deviceUserId).toSet(),
    );

    // Deleting somebody who is not there is a no-op, not an error.
    final again = await enrollment.deleteUser(
      _settings,
      deviceUserId: created.deviceUserId,
    );
    stdout.writeln('second delete returned: $again (expected false)');
    expect(again, isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
