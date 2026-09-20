@Tags(['probe'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zkteco/flutter_zkteco.dart';

import 'package:attendence/features/device/data/data_source/zk_device_gate.dart';
import 'package:attendence/features/device/data/data_source/zk_device_data_source.dart';
import 'package:attendence/features/device/data/data_source/zk_enrollment_data_source.dart';
import 'package:attendence/features/device/data/models/device_settings_model.dart';

/// Exercises the whole enrolment path against the real terminal, short of the
/// physical finger press.
///
/// Creates a throwaway user, checks it reads back correctly (including an
/// Arabic name through Windows-1256), asks the device to start capturing,
/// cancels, and then removes the user again — so the terminal is left exactly
/// as it was found.
const _settings = DeviceSettingsModel(ip: '192.168.1.201', port: 4370);
const _testName = 'اختبار البصمة';

void main() {
  test('enrolment round trip leaves the terminal unchanged', () async {
    final device = ZkDeviceDataSource(ZkDeviceGate());
    final enrollment = ZkEnrollmentDataSource(ZkDeviceGate());

    final before = await device.getDeviceUsers(_settings);
    stdout.writeln('\n=== before: ${before.length} users ===');
    for (final u in before) {
      stdout.writeln('  id=${u.deviceUserId} uid=${u.uid} name="${u.name}"');
    }

    // ---------------------------------------------------------------- create
    final created = await enrollment.upsertUser(_settings, name: _testName);
    stdout.writeln(
      '\ncreated uid=${created.uid} '
      'deviceUserId=${created.deviceUserId}',
    );

    expect(created.uid, greaterThan(0));
    expect(created.deviceUserId, isNotEmpty);
    // Must not collide with anyone already on the device.
    expect(
      before.map((u) => u.deviceUserId),
      isNot(contains(created.deviceUserId)),
    );

    final afterCreate = await device.getDeviceUsers(_settings);
    stdout.writeln('=== after create: ${afterCreate.length} users ===');
    final match = afterCreate
        .where((u) => u.deviceUserId == created.deviceUserId)
        .toList();
    expect(match, hasLength(1), reason: 'the new user should be readable back');
    stdout.writeln('  read back name="${match.first.name}"');

    // The name survives the Windows-1256 encode/decode round trip.
    expect(match.first.name, _testName);

    // ----------------------------------------------------------- start/cancel
    final session = await enrollment.beginEnrollment(
      _settings,
      uid: created.uid,
      deviceUserId: created.deviceUserId,
    );
    stdout.writeln(
      '\nbeginEnrollment accepted — the terminal should be asking '
      'for a finger, with the session still open',
    );
    expect(session.isClosed, isFalse);

    // The session staying open is the whole point: closing it is what made the
    // terminal abandon the capture and never prompt.
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(
      session.isClosed,
      isFalse,
      reason: 'the session must outlive the call that started it',
    );

    await enrollment.abortEnrollment(session);
    stdout.writeln('capture cancelled, session closed');
    expect(session.isClosed, isTrue);

    // ---------------------------------------------------------------- cleanup
    final raw = ZKTeco(
      _settings.ip,
      port: _settings.port,
      tcp: true,
      password: '0',
    );
    await raw.connect(ommitPing: true);
    await raw.removeUser(created.uid);
    await raw.disconnect();

    final after = await device.getDeviceUsers(_settings);
    stdout.writeln('\n=== after cleanup: ${after.length} users ===');
    for (final u in after) {
      stdout.writeln('  id=${u.deviceUserId} uid=${u.uid} name="${u.name}"');
    }

    expect(
      after.map((u) => u.deviceUserId).toSet(),
      before.map((u) => u.deviceUserId).toSet(),
      reason: 'the terminal must be left exactly as it was found',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
