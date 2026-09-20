@Tags(['probe'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/features/device/data/data_source/zk_device_gate.dart';
import 'package:attendence/features/device/data/data_source/zk_device_data_source.dart';
import 'package:attendence/features/device/data/data_source/zk_enrollment_data_source.dart';
import 'package:attendence/features/device/data/data_source/zk_live_capture_data_source.dart';
import 'package:attendence/features/device/data/models/device_settings_model.dart';

/// Reproduces the freeze: with live capture holding the terminal's only
/// session, an enrolment must still get through.
///
/// Before the fix this hung forever on "Registering Event / Waiting for
/// event...", because suspending live capture awaited a generator parked on a
/// stream nothing would ever complete.
const _settings = DeviceSettingsModel(ip: '192.168.1.201', port: 4370);

void main() {
  test('an enrolment interrupts live capture instead of hanging', () async {
    final gate = ZkDeviceGate();
    final live = ZkLiveCaptureDataSource(gate);
    final device = ZkDeviceDataSource(gate);
    final enrollment = ZkEnrollmentDataSource(gate);

    stdout.writeln('\nstarting live capture…');
    await live.start(_settings);
    // Let it get as far as "Waiting for event..." — the state that used to
    // deadlock everything behind it.
    await Future<void>.delayed(const Duration(seconds: 3));
    stdout.writeln('live running: ${live.isRunning}');
    expect(live.isRunning, isTrue);

    // ---- the operation that used to hang -------------------------------
    final watch = Stopwatch()..start();
    final created = await enrollment.upsertUser(
      _settings,
      name: 'بوابة اختبار',
    );
    watch.stop();

    stdout.writeln(
      'upsertUser finished in ${watch.elapsedMilliseconds}ms '
      '-> uid=${created.uid} id=${created.deviceUserId}',
    );
    expect(
      watch.elapsed,
      lessThan(const Duration(seconds: 30)),
      reason: 'the gate must not block on live capture',
    );

    // A second operation right behind it must also get through.
    final users = await device.getDeviceUsers(_settings);
    stdout.writeln('read back ${users.length} users');
    expect(users.any((u) => u.deviceUserId == created.deviceUserId), isTrue);

    // ---- cleanup --------------------------------------------------------
    final removed = await enrollment.deleteUser(
      _settings,
      deviceUserId: created.deviceUserId,
    );
    stdout.writeln('cleanup removed: $removed');
    expect(removed, isTrue);

    // Live capture should have come back on its own after the gate released.
    await Future<void>.delayed(const Duration(seconds: 3));
    stdout.writeln('live running again: ${live.isRunning}');
    expect(
      live.isRunning,
      isTrue,
      reason: 'live capture must resume once the device is free',
    );

    await live.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
