import 'package:flutter/foundation.dart';
import 'package:flutter_zkteco/flutter_zkteco.dart';
// The package exposes no public API for the raw user buffer, and its own
// parser reads the user id from the wrong offset — see [ZkUserParser].
// ignore: implementation_imports
import 'package:flutter_zkteco/src/util.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../models/device_settings_model.dart';
import 'zk_device_gate.dart';
import 'zk_punch_parser.dart';
import 'zk_table_reader.dart';
import 'zk_user_parser.dart';

/// The only thing in the app that opens a socket to the ZKTeco terminal.
///
/// Everything above this class works in [ZkPunchModel] and [ZkDeviceUserModel],
/// never in the package's own types, so replacing the transport — a hand-rolled
/// protocol client, a different package — touches this file only.
///
/// The terminal is deliberately *not* disabled around a read. Doing so is the
/// conventional way to get a consistent snapshot, but it locks the keypad while
/// the read runs, and a crash mid-sync would leave a gate terminal refusing
/// staff. A punch that lands mid-read simply arrives on the next sync, which is
/// safe because the punch table dedupes.
class ZkDeviceDataSource {
  /// Serialises access — the terminal accepts one session at a time, and
  /// live capture holds one open.
  final ZkDeviceGate _gate;

  ZkDeviceDataSource(this._gate);

  Future<ZkConnectionInfo> testConnection(DeviceSettingsModel settings) async {
    return _withDevice(settings, (device) async {
      // Each field is read independently. Not every model implements every
      // query — on firmware 6.60 `getDeviceName` returns a shape the package
      // mis-parses and throws on — and one unsupported field must not fail a
      // connection that is otherwise working.
      return ZkConnectionInfo(
        deviceName: _text(await _optional(() => device.getDeviceName())),
        serialNumber: _text(await _optional(() => device.serialNumber())),
        firmware: _text(await _optional(() => device.version())),
        deviceTime: await _optional(() => device.getTime()),
      );
    });
  }

  /// Runs a device query that is allowed to fail, yielding null instead.
  static Future<T?> _optional<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  /// Everyone enrolled on the terminal.
  ///
  /// The raw buffer is parsed by [ZkUserParser] rather than by the package's
  /// own `getUsers`, which reads the user id from the wrong offset and returns
  /// it empty. See that class for why using `uid` instead is not a safe
  /// substitute.
  Future<List<ZkDeviceUserModel>> getDeviceUsers(
    DeviceSettingsModel settings,
  ) async {
    return _readWithRetry(settings, (device) async {
      // The terminal's own count, read first. An empty enrolment table is the
      // ordinary state of a unit nobody has enrolled on yet, and asking for it
      // anyway turns that into what looks like a failed read.
      final sizes = await _optional(() => Util.readSizes(device));
      final count = sizes?.users ?? -1;
      if (count == 0) return const <ZkDeviceUserModel>[];
      if (count < 0) return null;

      final buffer = await ZkTableReader.read(
        device,
        Util.CMD_USER_TEMP_RRQ,
        fct: Util.FCT_USER,
        expectedRecords: count,
      );

      final users = ZkUserParser.parse(buffer, recordCount: count);
      return users.isEmpty ? null : users;
    });
  }

  /// Every punch currently in the terminal's buffer.
  ///
  /// The device has no "since" filter — it returns its whole log on each call —
  /// so the caller is responsible for discarding what it has already stored.
  Future<List<ZkPunchModel>> getPunches(DeviceSettingsModel settings) async {
    return _readWithRetry(settings, (device) async {
      // The record count decides the record width, so it is read before the
      // log rather than guessed from the buffer afterwards.
      final sizes = await _optional(() => Util.readSizes(device));
      final count = sizes?.records ?? 0;
      if (count <= 0) return const <ZkPunchModel>[];

      final buffer = await ZkTableReader.read(
        device,
        Util.CMD_ATT_LOG_RRQ,
        fct: Util.FCT_ATTLOG,
        expectedRecords: count,
      );

      final punches = ZkPunchParser.parse(buffer, recordCount: count);
      // The parser returns nothing when the buffer did not decode, which on
      // a terminal that just said it holds records is a failed read rather
      // than an empty log.
      return punches.isEmpty ? null : punches;
    });
  }

  /// Runs a read that can come back unusable, and gives it a second chance in a
  /// fresh session.
  ///
  /// This unit desyncs between consecutive sessions — the enrolment list and
  /// the punch log are two of them, back to back, in every sync — and the reply
  /// to one command turns up carrying the tail of the last. There is nothing to
  /// fix in that exchange once it has gone wrong; the cure is to drop the
  /// session and start again, which works. [action] returns null to say the
  /// read did not make sense.
  Future<List<T>> _readWithRetry<T>(
    DeviceSettingsModel settings,
    Future<List<T>?> Function(ZKTeco device) action, {
    int attempts = 3,
  }) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      final result = await _withDevice(settings, action);
      if (result != null) return result;

      // Give the terminal longer each time to finish letting the last session
      // go before the next one asks it for anything.
      if (attempt < attempts) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw const ApiException(LangKeys.errorDeviceRead);
  }

  /// Sets the terminal's clock from this PC.
  ///
  /// Worth having: punch timestamps come from the device, so a terminal whose
  /// clock has drifted silently files attendance under the wrong time, and in
  /// the worst case the wrong day.
  Future<void> syncDeviceClock(DeviceSettingsModel settings) async {
    return _withDevice(settings, (device) async {
      await device.setTime(DateTime.now());
    });
  }

  /// Opens a session, runs [action], and always closes the session afterwards.
  ///
  /// Most ZKTeco terminals allow a single SDK connection at a time, so leaking
  /// one would lock every later sync out until the device timed the session out.
  Future<T> _withDevice<T>(
    DeviceSettingsModel settings,
    Future<T> Function(ZKTeco device) action,
  ) async {
    if (!settings.isConfigured) {
      throw const ApiException(LangKeys.errorDeviceNotConfigured);
    }

    return _gate.run(() => _connectAndRun(settings, action));
  }

  Future<T> _connectAndRun<T>(
    DeviceSettingsModel settings,
    Future<T> Function(ZKTeco device) action,
  ) async {
    final device = ZKTeco(
      settings.ip.trim(),
      port: settings.port,
      tcp: settings.useTcp,
      timeout: const Duration(seconds: 15),
      // Never null. A terminal that wants a comm key answers CMD_CONNECT with
      // ACK_UNAUTH, and the package then dereferences this without a null
      // check — so passing null turns "needs a key" into an opaque crash that
      // surfaces as a plain connection failure. "0" is ZKTeco's own value for
      // "no key", so it is the correct thing to send when the field is blank.
      password: _effectiveCommKey(settings.commKey),
      debug: kDebugMode,
    );

    bool connected = false;
    try {
      connected = await device.connect(ommitPing: settings.skipPing);
    } catch (e) {
      // The package raises for an unreachable host or a rejected comm key; both
      // become the one key the settings screen knows how to explain.
      throw ApiException(LangKeys.errorDeviceUnreachable, detail: e.toString());
    }

    if (!connected) {
      throw const ApiException(LangKeys.errorDeviceUnreachable);
    }

    try {
      return await action(device);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(LangKeys.errorDeviceRead, detail: e.toString());
    } finally {
      try {
        await device.disconnect();
      } catch (_) {
        // A failed disconnect must not mask the result of the read; the device
        // times the session out on its own.
      }

      // The terminal needs a moment between sessions. A sync opens two in a
      // row — the enrolment list, then the punch log — and without this pause
      // the second one connects to a unit still winding the first one down: it
      // authenticates, then answers the next command with the tail of the last
      // session'''s reply. That is what made an otherwise correct read return 96
      // punches, then garbage, then none, with nothing in the code to explain
      // the difference.
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  /// A blank comm key means "no key", which the protocol spells as "0".
  static String _effectiveCommKey(String commKey) {
    final trimmed = commKey.trim();
    return trimmed.isEmpty ? '0' : trimmed;
  }

  static String? _text(Object? value) {
    if (value == null || value is bool) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

/// What the terminal reports about itself, shown on the device screen so an
/// admin can confirm they are pointed at the right unit.
class ZkConnectionInfo {
  final String? deviceName;
  final String? serialNumber;
  final String? firmware;
  final DateTime? deviceTime;

  const ZkConnectionInfo({
    this.deviceName,
    this.serialNumber,
    this.firmware,
    this.deviceTime,
  });

  /// How far the terminal's clock is from this PC's. Anything beyond a couple
  /// of minutes will misfile punches, so the UI surfaces it.
  Duration? get clockDrift {
    final time = deviceTime;
    return time == null ? null : DateTime.now().difference(time).abs();
  }
}
