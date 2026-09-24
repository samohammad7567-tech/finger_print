import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../attendance/data/repos/day_closing_repo.dart';
import '../../data/data_source/zk_device_data_source.dart';
import '../../data/models/device_settings_model.dart';
import '../../data/repos/device_repo.dart';
import 'device_state.dart';

/// Owns everything about the terminal link: the stored settings, the manual and
/// automatic syncs, and the employee mapping.
///
/// Registered as a singleton so the auto-sync timer keeps running while the
/// user is on other screens — attendance should keep flowing whether or not
/// anyone is looking at the device page.
class DeviceCubit extends Cubit<DeviceState> {
  final DeviceRepo _repo;
  final AttendanceRepo _attendance;

  /// Writes down the days nobody came in. Run after a sync rather than before
  /// one, so a backlog pulled off the terminal is folded first and only the
  /// days it left genuinely empty are closed.
  final DayClosingRepo _closing;

  Timer? _timer;
  StreamSubscription<ZkPunchModel>? _liveSubscription;

  DeviceCubit(this._repo, this._attendance, this._closing)
    : super(const DeviceState());

  /// Loads settings and the mapping worklist, then arms the auto-sync timer.
  Future<void> load() async {
    final settings = _repo.readSettings();
    emit(state.copyWith(settings: settings));

    await _refreshMappingView();
    _restartTimer(settings);
    await _restartLiveCapture(settings);
  }

  /// Folds each punch as it arrives, so attendance is current the moment
  /// somebody scans rather than at the next poll.
  Future<void> _restartLiveCapture(DeviceSettingsModel settings) async {
    await _liveSubscription?.cancel();
    _liveSubscription = null;

    if (!settings.isConfigured || !settings.liveSync) {
      await _repo.stopLiveCapture();
      emit(state.copyWith(isLive: false));
      return;
    }

    _liveSubscription = _repo.livePunches.listen(_onLivePunch);
    await _repo.startLiveCapture(settings);
    emit(state.copyWith(isLive: true));
  }

  Future<void> _onLivePunch(ZkPunchModel punch) async {
    try {
      final result = await _repo.ingestLivePunch(punch, state.settings);
      final lastSync = await _repo.lastSyncTime();

      emit(
        state.copyWith(
          lastSync: lastSync,
          lastLivePunchAt: punch.timestamp,
          // Only announce punches that actually changed something; the terminal
          // can re-send one it already gave us.
          message: result.punchesNew > 0 ? LangKeys.deviceLivePunch : null,
        ),
      );

      if (result.unmappedUserIds.isNotEmpty) await _refreshMappingView();
      if (result.punchesNew > 0) _clearMessage();
    } catch (_) {
      // A single bad punch must not tear down the listener.
    }
  }

  Future<void> saveSettings(DeviceSettingsModel settings) async {
    await _repo.saveSettings(settings);
    emit(
      state.copyWith(
        settings: settings,
        message: LangKeys.deviceSettingsSaved,
        // The stored details changed, so anything learned from the old ones is
        // no longer known to be true.
        clearConnection: true,
        clearError: true,
      ),
    );
    _clearMessage();
    _restartTimer(settings);
    await _restartLiveCapture(settings);
  }

  Future<void> testConnection() async {
    if (state.isBusy) return;
    emit(state.copyWith(isTesting: true, clearError: true, clearMessage: true));

    try {
      final info = await _repo.testConnection(state.settings);
      emit(
        state.copyWith(
          connection: info,
          isTesting: false,
          message: LangKeys.deviceConnected,
        ),
      );
      _clearMessage();
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isTesting: false,
          error: e.errorKey,
          clearConnection: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isTesting: false,
          error: LangKeys.errorUnknown,
          clearConnection: true,
        ),
      );
    }
  }

  Future<void> syncNow() async {
    if (state.isSyncing) return;
    emit(state.copyWith(isSyncing: true, clearError: true, clearMessage: true));

    try {
      final result = await _repo.sync(state.settings);

      // Punches first, absences second. Anybody the sync accounted for now has
      // a row, so what is left on a finished working day really is an absence.
      // Its own try: a closing failure must not turn a good sync into an error
      // the admin thinks lost their punches.
      try {
        await _closing.closeFinishedDays();
      } catch (_) {}

      final lastSync = await _repo.lastSyncTime();

      emit(
        state.copyWith(
          isSyncing: false,
          lastResult: result,
          lastSync: lastSync,
          message: LangKeys.deviceSyncDone,
        ),
      );

      await _refreshMappingView();
      _clearMessage();
    } on ApiException catch (e) {
      emit(state.copyWith(isSyncing: false, error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(isSyncing: false, error: LangKeys.errorUnknown));
    }
  }

  /// Pulls the enrolment list off the terminal so the mapping UI can show names
  /// beside the bare numeric ids.
  Future<void> loadDeviceUsers() async {
    if (state.isBusy) return;
    emit(
      state.copyWith(
        isLoadingUsers: true,
        clearError: true,
        clearMessage: true,
      ),
    );

    try {
      final users = await _repo.getDeviceUsers(state.settings);
      emit(state.copyWith(deviceUsers: users, isLoadingUsers: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoadingUsers: false, error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(isLoadingUsers: false, error: LangKeys.errorUnknown));
    }
  }

  /// Links a device user id to an employee, then re-folds the punches that
  /// arrived before the link existed so their history is not lost.
  Future<void> mapDeviceUser({
    required String employeeId,
    required String deviceUserId,
  }) async {
    try {
      await _attendance.updateEmployee(employeeId, {
        'device_user_id': deviceUserId,
      });
      await _repo.refoldUnmapped(state.settings);

      await _refreshMappingView();
      emit(state.copyWith(message: LangKeys.deviceMapped, clearError: true));
      _clearMessage();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(error: LangKeys.errorUnknown));
    }
  }

  Future<void> syncDeviceClock() async {
    if (state.isBusy) return;
    emit(state.copyWith(isTesting: true, clearError: true, clearMessage: true));

    try {
      await _repo.syncDeviceClock(state.settings);
      final info = await _repo.testConnection(state.settings);
      emit(
        state.copyWith(
          connection: info,
          isTesting: false,
          message: LangKeys.deviceClockSynced,
        ),
      );
      _clearMessage();
    } on ApiException catch (e) {
      emit(state.copyWith(isTesting: false, error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(isTesting: false, error: LangKeys.errorUnknown));
    }
  }

  /// Wipes or reboots the terminal itself.
  ///
  /// Nothing local is cleared by any of these. The punches already synced, the
  /// attendance rows folded from them and the employee records all stay — the
  /// reset only empties what the device is still holding. That distinction is
  /// the reason the confirm dialog spells it out: "reset the device" is also
  /// how an admin would phrase "start the attendance history over".
  Future<void> resetDevice(ZkResetAction action) async {
    if (state.isBusy) return;
    emit(
      state.copyWith(
        resettingAction: action,
        clearError: true,
        clearMessage: true,
      ),
    );

    try {
      await _repo.resetDevice(state.settings, action);

      // Everything on screen about the terminal described the unit as it was
      // before the wipe. The enrolment list especially: leaving the old one up
      // would invite an admin to map somebody onto an id the device no longer
      // has.
      final clearedUsers =
          action == ZkResetAction.enrolledUsers ||
          action == ZkResetAction.everything;

      emit(
        state.copyWith(
          clearResettingAction: true,
          clearConnection: true,
          deviceUsers: clearedUsers ? const [] : null,
          message: _resetMessage(action),
        ),
      );
      _clearMessage();

      // A reboot takes the live session down with it. Re-arming once the unit
      // is back is what keeps punches flowing without the admin having to
      // reopen this screen; the wait is generous because a terminal that is
      // still booting refuses the connection outright.
      if (action == ZkResetAction.restart) {
        await Future<void>.delayed(const Duration(seconds: 25));
        if (!isClosed) await _restartLiveCapture(state.settings);
      }
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.errorKey, clearResettingAction: true));
    } catch (_) {
      emit(
        state.copyWith(
          error: LangKeys.errorUnknown,
          clearResettingAction: true,
        ),
      );
    }
  }

  static String _resetMessage(ZkResetAction action) => switch (action) {
    ZkResetAction.attendanceLog => LangKeys.deviceResetLogDone,
    ZkResetAction.enrolledUsers => LangKeys.deviceResetUsersDone,
    ZkResetAction.everything => LangKeys.deviceResetAllDone,
    ZkResetAction.restart => LangKeys.deviceRestartSent,
  };

  /// The admin's answer to one held-back import: this terminal user is the
  /// employee already on file.
  ///
  /// The link is what stops the second copy being made. Re-folding then applies
  /// every punch that arrived while the question was open, so the history is
  /// picked up rather than starting from today.
  Future<void> confirmPendingMatch({
    required String deviceUserId,
    required String employeeId,
  }) async {
    if (state.resolvingMatchFor != null) return;
    emit(
      state.copyWith(
        resolvingMatchFor: deviceUserId,
        clearError: true,
        clearMessage: true,
      ),
    );

    try {
      await _repo.confirmPendingMatch(
        deviceUserId: deviceUserId,
        employeeId: employeeId,
      );
      await _refreshMappingView();
      emit(
        state.copyWith(
          message: LangKeys.deviceMatchLinked,
          clearResolvingMatch: true,
        ),
      );
      _clearMessage();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.errorKey, clearResolvingMatch: true));
    } catch (_) {
      emit(
        state.copyWith(error: LangKeys.errorUnknown, clearResolvingMatch: true),
      );
    }
  }

  /// The other answer: a different person who happens to share the name, so
  /// they get a record of their own after all.
  Future<void> rejectPendingMatch(String deviceUserId) async {
    if (state.resolvingMatchFor != null) return;
    emit(
      state.copyWith(
        resolvingMatchFor: deviceUserId,
        clearError: true,
        clearMessage: true,
      ),
    );

    try {
      await _repo.rejectPendingMatch(deviceUserId);
      await _refreshMappingView();
      emit(
        state.copyWith(
          message: LangKeys.deviceMatchCreated,
          clearResolvingMatch: true,
        ),
      );
      _clearMessage();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.errorKey, clearResolvingMatch: true));
    } catch (_) {
      emit(
        state.copyWith(error: LangKeys.errorUnknown, clearResolvingMatch: true),
      );
    }
  }

  Future<void> _refreshMappingView() async {
    try {
      final employees = await _attendance.getAllEmployees();
      final unmapped = await _repo.getUnmappedUserIds();
      final pending = await _repo.getPendingMatches();
      final lastSync = await _repo.lastSyncTime();
      emit(
        state.copyWith(
          employees: employees,
          unmapped: unmapped,
          pendingMatches: pending,
          lastSync: lastSync,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.errorKey));
    }
  }

  /// A one-shot banner: the UI shows it, then it clears itself so returning to
  /// the screen later does not replay a stale success message.
  void _clearMessage() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!isClosed && state.message != null) {
        emit(state.copyWith(clearMessage: true));
      }
    });
  }

  void _restartTimer(DeviceSettingsModel settings) {
    _timer?.cancel();
    _timer = null;

    if (!settings.isConfigured || settings.autoSyncMinutes <= 0) return;

    _timer = Timer.periodic(Duration(minutes: settings.autoSyncMinutes), (_) {
      // A manual sync in flight owns the connection; the terminal accepts one
      // session at a time, so the tick is skipped rather than queued.
      if (!state.isBusy) syncNow();
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _liveSubscription?.cancel();
    _repo.stopLiveCapture();
    return super.close();
  }
}
