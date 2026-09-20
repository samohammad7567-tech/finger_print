import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_zkteco/flutter_zkteco.dart';

import '../models/device_settings_model.dart';
import 'zk_device_gate.dart';

/// Keeps a session open so punches arrive the moment a finger is accepted,
/// instead of waiting for the next poll.
///
/// The terminal allows one session at a time, so this stands itself down
/// whenever [ZkDeviceGate] hands the device to another operation, and brings
/// itself back afterwards.
class ZkLiveCaptureDataSource {
  final ZkDeviceGate _gate;

  ZkLiveCaptureDataSource(this._gate) {
    _gate.onSuspend = _suspend;
    _gate.onResume = _resumeIfWanted;
  }

  final _punches = StreamController<ZkPunchModel>.broadcast();

  /// Punches as they happen.
  Stream<ZkPunchModel> get punches => _punches.stream;

  ZKTeco? _device;
  StreamSubscription<AttendanceLog?>? _subscription;
  Timer? _retry;

  DeviceSettingsModel? _settings;

  /// Whether the caller wants live capture running. Survives suspensions, so
  /// the gate knows to restart afterwards.
  bool _wanted = false;
  bool get isRunning => _subscription != null;

  Future<void> start(DeviceSettingsModel settings) async {
    _settings = settings;
    _wanted = true;
    // The gate may be mid-operation; it will call back when it finishes.
    if (_gate.isBusy) return;
    await _open();
  }

  Future<void> stop() async {
    _wanted = false;
    _retry?.cancel();
    _retry = null;
    await _suspend();
  }

  Future<void> _open() async {
    final settings = _settings;
    if (!_wanted || settings == null || !settings.isConfigured) return;
    if (_subscription != null) return;

    try {
      final device = ZKTeco(
        settings.ip.trim(),
        port: settings.port,
        tcp: settings.useTcp,
        timeout: const Duration(seconds: 20),
        password: settings.commKey.trim().isEmpty
            ? '0'
            : settings.commKey.trim(),
        debug: kDebugMode,
      );

      final connected = await device.connect(ommitPing: settings.skipPing);
      if (!connected) {
        _scheduleRetry();
        return;
      }

      _device = device;
      _subscription = device.onAttendanceRecordReceived.listen(
        _onLog,
        onError: (_) => _restartLater(),
        onDone: _restartLater,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _onLog(AttendanceLog? log) {
    if (log == null || log.timestamp == null) return;

    final userId = (log.id ?? log.uid?.toString() ?? '').trim();
    if (userId.isEmpty) return;

    _punches.add(
      ZkPunchModel(
        deviceUserId: userId,
        timestamp: log.timestamp!,
        state: log.state,
        type: log.type,
      ),
    );
  }

  /// Releases the session so another operation can use the device.
  ///
  /// This tears the socket down rather than asking politely, because the polite
  /// routes both deadlock:
  ///
  ///  * `streamLiveCapture` parks on `streamController.stream.first`, and the
  ///    package never closes that controller — the socket's `onDone` only
  ///    logs — so awaiting `subscription.cancel()` on that generator never
  ///    returns while the terminal is idle; and
  ///  * `cancelLiveCapture()` awaits a reply on the *same* broadcast stream the
  ///    generator is already consuming, so the two race for it.
  ///
  /// Closing the socket ends the session terminal-side, which is what actually
  /// matters, and lets the orphaned generator die on its next write.
  Future<void> _suspend() async {
    _retry?.cancel();
    _retry = null;

    final subscription = _subscription;
    _subscription = null;
    final device = _device;
    _device = null;

    if (device == null) {
      unawaited(subscription?.cancel().catchError((_) {}) ?? Future.value());
      return;
    }

    // Stops the generator's loop the next time it comes round.
    device.liveCapture = false;

    try {
      device.zkSocket?.destroy();
    } catch (_) {}
    try {
      device.zkClient?.close();
    } catch (_) {}

    // Deliberately not awaited — see above.
    unawaited(subscription?.cancel().catchError((_) {}) ?? Future.value());

    // The terminal needs a moment to notice the socket went away before it will
    // accept a new session.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _resumeIfWanted() async {
    if (!_wanted) return;
    await _open();
  }

  void _restartLater() {
    _subscription = null;
    _device = null;
    _scheduleRetry();
  }

  /// The terminal drops idle sessions and reboots; retrying keeps live capture
  /// self-healing rather than needing the screen reopened.
  void _scheduleRetry() {
    if (!_wanted || _retry != null) return;
    _retry = Timer(const Duration(seconds: 20), () {
      _retry = null;
      if (!_gate.isBusy) _open();
    });
  }

  Future<void> dispose() async {
    await stop();
    await _punches.close();
  }
}
