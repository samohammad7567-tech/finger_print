import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../device/data/data_source/zk_enrollment_data_source.dart';
import '../../../device/data/data_source/device_settings_local_data_source.dart';

enum EnrollmentStage {
  /// Nothing started, or an employee with no fingerprint yet.
  idle,

  /// Creating the person on the terminal before the sensor can be used.
  preparing,

  /// The terminal is prompting for a finger. The person presses it there.
  waitingForFinger,

  /// Reading back whether a template actually landed.
  verifying,

  /// Confirmed — the terminal holds a template for this finger.
  enrolled,
}

class EnrollmentState {
  final EnrollmentStage stage;

  /// Set as soon as the person exists on the terminal, so the employee can be
  /// saved with the right mapping even if the finger capture is abandoned.
  final ZkEnrolledUser? user;

  final String? error;

  const EnrollmentState({
    this.stage = EnrollmentStage.idle,
    this.user,
    this.error,
  });

  bool get isBusy =>
      stage == EnrollmentStage.preparing || stage == EnrollmentStage.verifying;

  bool get isWaiting => stage == EnrollmentStage.waitingForFinger;
  bool get isEnrolled => stage == EnrollmentStage.enrolled;

  /// What gets written to `employees.device_user_id` on save.
  String? get deviceUserId => user?.deviceUserId;

  EnrollmentState copyWith({
    EnrollmentStage? stage,
    ZkEnrolledUser? user,
    String? error,
    bool clearError = false,
  }) => EnrollmentState(
    stage: stage ?? this.stage,
    user: user ?? this.user,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives fingerprint enrolment for one employee form.
///
/// The terminal owns the sensor, so this cannot capture a finger itself. It
/// creates the person on the device, asks it to start capturing, and then — once
/// the admin says the person has finished — confirms a template exists.
class EnrollmentCubit extends Cubit<EnrollmentState> {
  final ZkEnrollmentDataSource _enrollment;
  final DeviceSettingsLocalDataSource _settings;

  EnrollmentCubit(this._enrollment, this._settings)
    : super(const EnrollmentState());

  /// Held open from [start] until [confirm] or [cancel].
  ///
  /// The terminal abandons a capture as soon as its session closes, so the
  /// connection has to survive between the two steps rather than being opened
  /// per call.
  ZkEnrollmentSession? _session;

  /// Seeds the state for an employee that is already mapped, so the form can
  /// show "enrolled" without another trip to the device.
  void seed({String? deviceUserId, required String name}) {
    final id = (deviceUserId ?? '').trim();
    if (id.isEmpty) return;
    emit(
      EnrollmentState(
        stage: EnrollmentStage.idle,
        user: ZkEnrolledUser(uid: 0, deviceUserId: id, name: name),
      ),
    );
  }

  /// Step one: put the person on the terminal, then start the sensor.
  Future<void> start({required String name}) async {
    if (state.isBusy) return;

    if (name.trim().isEmpty) {
      emit(state.copyWith(error: LangKeys.errorEnrollNeedsName));
      return;
    }

    emit(state.copyWith(stage: EnrollmentStage.preparing, clearError: true));

    try {
      final settings = _settings.read();

      // A finger can only be attached to a user the device already knows.
      final user = await _enrollment.upsertUser(
        settings,
        name: name.trim(),
        deviceUserId: state.deviceUserId,
      );

      // Any earlier attempt still holding the device has to go first.
      await _releaseSession();

      _session = await _enrollment.beginEnrollment(
        settings,
        uid: user.uid,
        deviceUserId: user.deviceUserId,
      );

      emit(state.copyWith(stage: EnrollmentStage.waitingForFinger, user: user));
    } on ApiException catch (e) {
      emit(state.copyWith(stage: EnrollmentStage.idle, error: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(
          stage: EnrollmentStage.idle,
          error: LangKeys.errorUnknown,
        ),
      );
    }
  }

  /// Step two: the admin says the person is done — check the terminal agrees.
  Future<void> confirm() async {
    final user = state.user;
    final session = _session;
    if (user == null || state.isBusy) return;

    emit(state.copyWith(stage: EnrollmentStage.verifying, clearError: true));

    try {
      // Verified on the session that ran the capture where possible; a fresh
      // one otherwise, for a session the watchdog already closed.
      final ok = session != null && !session.isClosed
          ? await _enrollment.finishEnrollment(session)
          : await _enrollment.hasFingerprint(_settings.read(), uid: user.uid);
      _session = null;

      if (ok) {
        emit(state.copyWith(stage: EnrollmentStage.enrolled, clearError: true));
        return;
      }

      // Nothing captured — put the terminal back into capture mode so the
      // person can simply try again.
      emit(
        state.copyWith(
          stage: EnrollmentStage.idle,
          error: LangKeys.errorEnrollNoTemplate,
        ),
      );
    } on ApiException catch (e) {
      _session = null;
      emit(state.copyWith(stage: EnrollmentStage.idle, error: e.errorKey));
    } catch (_) {
      _session = null;
      emit(
        state.copyWith(
          stage: EnrollmentStage.idle,
          error: LangKeys.errorUnknown,
        ),
      );
    }
  }

  /// Leaves the terminal waiting for a finger if this is not called, so the
  /// form calls it when the sheet closes mid-enrolment.
  Future<void> cancel() async {
    await _releaseSession();
    if (!state.isWaiting) return;
    emit(state.copyWith(stage: EnrollmentStage.idle, clearError: true));
  }

  Future<void> _releaseSession() async {
    final session = _session;
    _session = null;
    if (session == null || session.isClosed) return;
    try {
      await _enrollment.abortEnrollment(session);
    } catch (_) {
      // The device times the capture out on its own; nothing to report.
    }
  }

  @override
  Future<void> close() async {
    await _releaseSession();
    return super.close();
  }

  /// Pushes the final name to the terminal when the employee is saved, so a
  /// rename in the app reaches the device too.
  Future<void> pushName(String name) async {
    final user = state.user;
    if (user == null || name.trim().isEmpty) return;
    try {
      await _enrollment.upsertUser(
        _settings.read(),
        name: name.trim(),
        deviceUserId: user.deviceUserId,
      );
    } catch (_) {
      // The local record is the one that matters; a failed name push is not
      // worth blocking the save over.
    }
  }
}
