import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/network/api_exception.dart';
import 'package:attendence/features/device/data/data_source/device_settings_local_data_source.dart';
import 'package:attendence/features/device/data/data_source/device_sync_data_source.dart';
import 'package:attendence/features/device/data/data_source/zk_device_data_source.dart';
import 'package:attendence/features/device/data/data_source/zk_device_gate.dart';
import 'package:attendence/features/device/data/data_source/zk_enrollment_data_source.dart';
import 'package:attendence/features/device/data/data_source/zk_live_capture_data_source.dart';
import 'package:attendence/features/device/data/models/device_settings_model.dart';
import 'package:attendence/features/device/data/repos/device_repo.dart';

/// The terminal's clock is what stamps a punch, so the sync must push this
/// PC's time before it reads anything. These run without hardware by standing
/// in for the socket-facing data source.
void main() {
  late AppDatabase database;
  late DeviceSyncDataSource sync;
  late SharedPreferences prefs;
  late DeviceSettingsModel settings;

  setUp(() async {
    database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    sync = DeviceSyncDataSource(database);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    settings = const DeviceSettingsModel(
      ip: '192.168.1.203',
      importEmployees: false,
    );
  });

  tearDown(() async => database.close());

  DeviceRepo repoFor(ZkDeviceDataSource device) {
    final liveGate = ZkDeviceGate();
    return DeviceRepo(
      device,
      sync,
      DeviceSettingsLocalDataSource(prefs),
      _StubEnrollment(),
      ZkLiveCaptureDataSource(liveGate),
    );
  }

  test('the clock is set before the enrolment list or punches are read', () async {
    final device = _StubDevice();

    await repoFor(device).sync(settings);

    expect(device.calls, ['clock', 'users', 'punches']);
  });

  test('a clock the terminal refuses does not take the sync down', () async {
    final device = _StubDevice(clockFails: true);

    final result = await repoFor(device).sync(settings);

    expect(device.calls, ['clock', 'users', 'punches']);
    expect(result.punchesRead, 0);
  });
}

class _StubDevice extends ZkDeviceDataSource {
  _StubDevice({this.clockFails = false}) : super(ZkDeviceGate());

  final bool clockFails;
  final calls = <String>[];

  @override
  Future<void> syncDeviceClock(DeviceSettingsModel settings) async {
    calls.add('clock');
    if (clockFails) throw const ApiException('clock_failed');
  }

  @override
  Future<List<ZkDeviceUserModel>> getDeviceUsers(
    DeviceSettingsModel settings,
  ) async {
    calls.add('users');
    return const [];
  }

  @override
  Future<List<ZkPunchModel>> getPunches(DeviceSettingsModel settings) async {
    calls.add('punches');
    return const [];
  }
}

class _StubEnrollment extends ZkEnrollmentDataSource {
  _StubEnrollment() : super(ZkDeviceGate());

  @override
  Future<Map<String, Set<int>>> enrolledFingersForUsers(
    DeviceSettingsModel settings,
    List<ZkDeviceUserModel> users,
  ) async => const {};
}
