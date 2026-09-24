import '../data_source/device_settings_local_data_source.dart';
import '../data_source/device_sync_data_source.dart';
import '../data_source/zk_device_data_source.dart';
import '../data_source/zk_enrollment_data_source.dart';
import '../data_source/zk_live_capture_data_source.dart';
import '../models/device_settings_model.dart';
import '../models/pending_employee_match.dart';
import '../models/zk_push_models.dart';

/// Thin delegation over the three device data sources: the terminal itself,
/// the fold into attendance rows, and the stored connection settings.
class DeviceRepo {
  final ZkDeviceDataSource _device;
  final DeviceSyncDataSource _sync;
  final DeviceSettingsLocalDataSource _settings;
  final ZkEnrollmentDataSource _enrollment;
  final ZkLiveCaptureDataSource _live;

  DeviceRepo(
    this._device,
    this._sync,
    this._settings,
    this._enrollment,
    this._live,
  );

  /// Punches as the terminal reports them, the moment a finger is accepted.
  Stream<ZkPunchModel> get livePunches => _live.punches;

  bool get isLiveRunning => _live.isRunning;

  Future<void> startLiveCapture(DeviceSettingsModel settings) =>
      _live.start(settings);

  Future<void> stopLiveCapture() => _live.stop();

  /// Folds a single live punch straight into attendance, without re-reading
  /// the terminal's whole buffer.
  Future<DeviceSyncResult> ingestLivePunch(
    ZkPunchModel punch,
    DeviceSettingsModel settings,
  ) => _sync.ingest([punch], debounceSeconds: settings.debounceSeconds);

  DeviceSettingsModel readSettings() => _settings.read();

  Future<void> saveSettings(DeviceSettingsModel settings) =>
      _settings.write(settings);

  Future<ZkConnectionInfo> testConnection(DeviceSettingsModel settings) =>
      _device.testConnection(settings);

  Future<List<ZkDeviceUserModel>> getDeviceUsers(
    DeviceSettingsModel settings,
  ) => _device.getDeviceUsers(settings);

  Future<void> syncDeviceClock(DeviceSettingsModel settings) =>
      _device.syncDeviceClock(settings);

  /// Wipes or reboots the terminal.
  ///
  /// Local records are deliberately untouched — see
  /// [ZkDeviceDataSource.resetDevice] for what each action does and why the
  /// user wipe cannot promise to spare the log.
  Future<void> resetDevice(
    DeviceSettingsModel settings,
    ZkResetAction action,
  ) => _device.resetDevice(settings, action);

  /// A full sync: pull the enrolment list, create any employee the terminal
  /// knows about and the app plainly does not, then pull and fold the punches.
  ///
  /// Employees are imported *before* the punches are folded so a newly enrolled
  /// person's scans land on their record in the same run, instead of sitting
  /// unmapped until someone opens the mapping screen.
  ///
  /// Terminal users who look like somebody already on file are neither created
  /// nor linked by this run — they are held for review. Their punches still
  /// arrive and are kept unmapped, and answering the question re-folds them, so
  /// the wait costs nothing but the delay.
  Future<DeviceSyncResult> sync(DeviceSettingsModel settings) async {
    var imported = 0;
    var pending = 0;
    if (settings.importEmployees) {
      final users = await _device.getDeviceUsers(settings);
      final outcome = await _sync.importEmployees(users);
      imported = outcome.created;
      pending = outcome.pending;
    }

    final punches = await _device.getPunches(settings);
    final result = await _sync.ingest(
      punches,
      debounceSeconds: settings.debounceSeconds,
      employeesImported: imported,
    );

    return DeviceSyncResult(
      punchesRead: result.punchesRead,
      punchesNew: result.punchesNew,
      recordsWritten: result.recordsWritten,
      unmappedUserIds: result.unmappedUserIds,
      employeesImported: result.employeesImported,
      employeesPendingReview: pending,
    );
  }

  /// Pulls the enrolment list and creates everybody on it who is plainly new,
  /// without touching the punch log.
  ///
  /// The employee screen's own button, for an admin who wants the staff list
  /// filled in now rather than at the next sync. Same rules as [sync]: anybody
  /// who looks like somebody already on file is held for review instead of
  /// being created twice.
  Future<
    ({
      int created,
      int pending,
      List<ZkDeviceUserModel> dismissed,
      int readFromDevice,
    })
  >
  fetchEmployees(DeviceSettingsModel settings) async {
    final users = await _device.getDeviceUsers(settings);
    final outcome = await _sync.importEmployees(users);

    // Anyone created here may have been punching for weeks while nobody was on
    // file to own it. The punches were parked, not dropped, so this is where
    // that history lands.
    if (outcome.created > 0) {
      await _sync.refoldUnmapped(debounceSeconds: settings.debounceSeconds);
    }

    // The raw count is reported alongside the rest so "nothing happened" can be
    // told apart from "the terminal gave us nothing".
    return (
      created: outcome.created,
      pending: outcome.pending,
      dismissed: outcome.dismissed,
      readFromDevice: users.length,
    );
  }

  /// What sending the staff list to the terminal would do, worked out against
  /// a fresh read of its enrolment table and written nowhere.
  ///
  /// Deliberately separate from [pushUsers] so the admin approves a plan with
  /// real counts in it rather than a button that says "send".
  Future<ZkPushPlan> planUserPush(
    DeviceSettingsModel settings,
    List<ZkPushTarget> targets,
  ) => _enrollment.planUserPush(settings, targets);

  /// Writes the approved plan to the terminal in one session.
  ///
  /// Nothing is cleared first. Existing people are replaced in their own
  /// enrolment slot, so their fingerprints survive; people the terminal holds
  /// and the app does not are left alone rather than deleted.
  Future<ZkPushReport> pushUsers(
    DeviceSettingsModel settings,
    ZkPushPlan plan, {
    void Function(int done, int total)? onProgress,
  }) => _enrollment.pushUsers(settings, plan, onProgress: onProgress);

  /// Everyone an admin deleted, whose enrolment the terminal may still hold.
  Future<List<({String deviceUserId, bool removedFromDevice, DateTime at})>>
  getDismissedDeviceUsers() => _sync.getDismissedDeviceUsers();

  /// Lifts those deletions so the next fetch brings them back.
  Future<int> restoreDeviceUsers(List<String> deviceUserIds) =>
      _sync.restoreDeviceUsers(deviceUserIds);

  /// Terminal users waiting on an admin to say whether they are somebody
  /// already on file. Reads only the local database, so the review is
  /// available with the terminal unplugged.
  Future<List<PendingEmployeeMatch>> getPendingMatches() =>
      _sync.getPendingMatches();

  Future<int> pendingMatchCount() => _sync.pendingMatchCount();

  /// Same person: link the terminal id onto the existing employee, then replay
  /// the punches that arrived while the question was open.
  Future<void> confirmPendingMatch({
    required String deviceUserId,
    required String employeeId,
  }) async {
    await _sync.confirmPendingMatch(
      deviceUserId: deviceUserId,
      employeeId: employeeId,
    );
    await _sync.refoldUnmapped(
      debounceSeconds: _settings.read().debounceSeconds,
    );
  }

  /// Different person: create them, then replay their punches onto the new
  /// record.
  Future<void> rejectPendingMatch(String deviceUserId) async {
    await _sync.rejectPendingMatch(deviceUserId);
    await _sync.refoldUnmapped(
      debounceSeconds: _settings.read().debounceSeconds,
    );
  }

  /// Removes a person from the terminal and records the deletion so the next
  /// sync does not import them back.
  ///
  /// Returns whether the terminal confirmed the removal. A false result is not
  /// a failure — the employee is still deleted locally and will not reappear —
  /// it means the fingerprint is still enrolled on the device.
  Future<bool> deleteDeviceUser(String deviceUserId) async {
    final settings = _settings.read();
    var removed = false;

    if (settings.isConfigured) {
      try {
        removed = await _enrollment.deleteUser(
          settings,
          deviceUserId: deviceUserId,
        );
      } catch (_) {
        // Terminal unreachable or busy. The tombstone below still stops the
        // employee coming back, so the local delete is never silently undone.
        removed = false;
      }
    }

    await _sync.dismissDeviceUser(deviceUserId, removedFromDevice: removed);
    return removed;
  }

  Future<List<String>> getStrandedDeviceUsers() =>
      _sync.getStrandedDeviceUsers();

  Future<int> refoldUnmapped(DeviceSettingsModel settings) =>
      _sync.refoldUnmapped(debounceSeconds: settings.debounceSeconds);

  /// Re-reads the stored punches for a date range and rebuilds the attendance
  /// rows they produce, so a report shows what the current rules make of them.
  Future<int> refoldRange(String startDate, String endDate) =>
      _sync.refoldRange(
        startDate,
        endDate,
        debounceSeconds: _settings.read().debounceSeconds,
      );

  Future<List<({String deviceUserId, int punchCount, DateTime lastSeen})>>
  getUnmappedUserIds() => _sync.getUnmappedUserIds();

  Future<DateTime?> lastSyncTime() => _sync.lastSyncTime();
}
