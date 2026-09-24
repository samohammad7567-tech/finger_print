import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_zkteco/flutter_zkteco.dart';
// ignore: implementation_imports
import 'package:flutter_zkteco/src/util.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/cp1256.dart';
import '../models/device_settings_model.dart';
import '../models/zk_push_models.dart';
import 'zk_device_gate.dart';
import 'zk_table_reader.dart';
import 'zk_user_parser.dart';

/// Enrolling a fingerprint on the terminal, and writing employees back to it.
///
/// The terminal owns the sensor, so the app cannot capture a finger itself. It
/// can only put the device into enrolment mode and then confirm afterwards that
/// a template landed. The person still presses their finger on the terminal —
/// usually three times — while the app waits.
class ZkEnrollmentDataSource {
  /// Serialises access — the terminal accepts one session at a time, and
  /// live capture holds one open.
  final ZkDeviceGate _gate;

  ZkEnrollmentDataSource(this._gate);

  /// Puts the device into "enrol this finger" mode. The package has no constant
  /// for it and never sends it.
  static const _cmdStartEnroll = 61;

  /// Index finger. Terminals store ten slots per person, 0..9.
  static const defaultFinger = 0;

  /// Below this a reply is the terminal's own framing, not a template. Real
  /// ones run to hundreds of bytes.
  static const _minTemplateBytes = 8;

  /// The name field in a user record. Windows-1256 is one byte per character,
  /// Arabic included, so this is 24 characters either way — and anything past
  /// it is dropped by the write, not by the terminal's screen.
  static const _nameBytes = 24;

  /// Refusals in a row that end a bulk push. Low on purpose: past two or three
  /// the terminal is gone, not fussy.
  static const _maxConsecutiveFailures = 3;

  /// Creates or updates the person on the terminal and returns the identifiers
  /// it will file their punches under.
  ///
  /// [deviceUserId] is reused when the employee already has one, so editing
  /// somebody never orphans their existing punches.
  ///
  /// The enrolment list is read in its own session, before the write. It has to
  /// succeed: the free slot and the free id are both derived from it, so a read
  /// that came back empty because it failed — rather than because the terminal
  /// is empty — would hand out uid 1 and overwrite whoever already holds it.
  Future<ZkEnrolledUser> upsertUser(
    DeviceSettingsModel settings, {
    required String name,
    String? deviceUserId,
  }) async {
    final existing = await _enrolledUsers(settings);

    var uid = 0;
    var userId = (deviceUserId ?? '').trim();

    if (userId.isNotEmpty) {
      final match = existing.where((u) => u.deviceUserId == userId);
      uid = match.isEmpty ? _nextUid(existing) : (match.first.uid ?? 0);
    } else {
      userId = _nextUserId(existing);
      uid = _nextUid(existing);
    }
    if (uid == 0) uid = _nextUid(existing);

    return _withDevice(settings, (device) async {
      await _writeUser(device, uid: uid, userId: userId, name: name);
      return ZkEnrolledUser(uid: uid, deviceUserId: userId, name: name);
    });
  }

  // -------------------------------------------------------- app -> terminal

  /// Works out what writing the whole staff list to the terminal would do,
  /// without writing anything.
  ///
  /// Nothing here clears the device, and that is the point. `CMD_SET_USER` is
  /// an upsert keyed on the enrolment slot: an existing person is replaced in
  /// place, a new one is appended, and an empty table was never a precondition.
  /// Clearing first would be the only way to lose the fingerprint templates —
  /// which this app does not hold and cannot put back, so every employee would
  /// have to enrol their finger again to punch.
  Future<ZkPushPlan> planUserPush(
    DeviceSettingsModel settings,
    List<ZkPushTarget> targets,
  ) async {
    final enrolment = await _enrolment(settings);
    final existing = enrolment.users;

    final byUserId = {
      for (final user in existing) user.deviceUserId.trim(): user,
    };

    // Seeded from both sides. An employee can hold an id the terminal has
    // since lost — deleted on the device, or a unit that was wiped — and
    // handing that id to somebody else would merge two people's punches.
    final takenIds = <String>{
      for (final user in existing) user.deviceUserId.trim(),
      for (final target in targets) (target.deviceUserId ?? '').trim(),
    }..remove('');

    var nextUid = _nextUid(existing);
    var nextId = int.tryParse(_nextUserId(existing)) ?? 1;

    final entries = <ZkPushEntry>[];
    final claimed = <String>{};

    for (final target in targets) {
      final name = target.fullName.trim();
      var userId = (target.deviceUserId ?? '').trim();

      // A blank name would go to the device as an empty field and show as a
      // nameless row. Their enrolment is still theirs, so it is claimed rather
      // than reported as a stranger's.
      if (name.isEmpty) {
        if (userId.isNotEmpty) claimed.add(userId);
        continue;
      }

      final assignsId = userId.isEmpty;
      if (assignsId) {
        while (takenIds.contains('$nextId')) {
          nextId++;
        }
        userId = '$nextId';
        takenIds.add(userId);
      }

      final match = byUserId[userId];
      final uid = match?.uid ?? 0;

      entries.add(
        ZkPushEntry(
          target: target,
          // Reusing the slot is what keeps an enrolled finger working: the
          // templates hang off the uid, not the user id.
          uid: uid == 0 ? nextUid++ : uid,
          deviceUserId: userId,
          isNew: match == null,
          assignsId: assignsId,
          nameTruncated: Cp1256.encode(name).length > _nameBytes,
        ),
      );
      claimed.add(userId);
    }

    return ZkPushPlan(
      entries: entries,
      extras: [
        for (final user in existing)
          if (!claimed.contains(user.deviceUserId.trim())) user,
      ],
      freeSlots: enrolment.freeSlots,
      onDevice: existing.length,
    );
  }

  /// Writes every planned row in **one** session.
  ///
  /// One session for the whole batch rather than a call to [upsertUser] each.
  /// This unit wants 600ms of quiet between sessions and desyncs when it does
  /// not get it, so a staff list of a hundred would be two hundred connections
  /// and well over a minute of waiting — with the enrolment table re-read
  /// every time.
  ///
  /// A refused row is recorded and the run carries on: one name the firmware
  /// dislikes must not cost the other ninety-nine.
  Future<ZkPushReport> pushUsers(
    DeviceSettingsModel settings,
    ZkPushPlan plan, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (plan.entries.isEmpty) return const ZkPushReport();

    return _withDevice(settings, (device) async {
      final written = <ZkPushEntry>[];
      final failed = <({ZkPushEntry entry, String errorKey})>[];
      final total = plan.entries.length;
      var consecutiveFailures = 0;

      for (var i = 0; i < total; i++) {
        final entry = plan.entries[i];

        try {
          await _writeUser(
            device,
            uid: entry.uid,
            userId: entry.deviceUserId,
            name: entry.target.fullName.trim(),
          );
          written.add(entry);
          consecutiveFailures = 0;
        } on ApiException catch (e) {
          failed.add((entry: entry, errorKey: e.errorKey));
          consecutiveFailures++;
        } catch (_) {
          failed.add((entry: entry, errorKey: LangKeys.errorDeviceWriteFailed));
          consecutiveFailures++;
        }

        onProgress?.call(i + 1, total);

        // This many refusals in a row is not the names: the terminal has gone
        // away or filled up. Carrying on would be ninety more timeouts and a
        // report blaming every employee in the list.
        if (consecutiveFailures >= _maxConsecutiveFailures) {
          for (final untried in plan.entries.skip(i + 1)) {
            failed.add((
              entry: untried,
              errorKey: LangKeys.errorDevicePushStopped,
            ));
          }
          return ZkPushReport(
            written: written,
            failed: failed,
            abortedEarly: true,
          );
        }
      }

      return ZkPushReport(written: written, failed: failed);
    });
  }

  /// The enrolment list and the terminal's free-slot count, read together and
  /// retried in a fresh session when the table comes back unusable — the same
  /// bargain [_enrolledUsers] makes, with the memory figures kept.
  Future<({List<ZkDeviceUserModel> users, int? freeSlots})> _enrolment(
    DeviceSettingsModel settings, {
    int attempts = 3,
  }) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      final read = await _withDevice(settings, (device) async {
        final sizes = await _optional(() => Util.readSizes(device));
        final users = await _readUsersOfCount(device, sizes?.users ?? -1);
        return (users: users, freeSlots: sizes?.usersAv);
      });

      if (read.users != null) {
        return (users: read.users!, freeSlots: read.freeSlots);
      }
      if (attempt < attempts) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw const ApiException(LangKeys.errorDeviceRead);
  }

  /// Puts the terminal into capture mode and **keeps the session open**.
  ///
  /// This is why enrolment needs its own session type rather than a one-shot
  /// call. Closing the connection sends CMD_EXIT, and the terminal abandons a
  /// pending capture the moment its session ends — so an earlier version that
  /// sent the command and disconnected reported success while the device never
  /// prompted for a finger at all.
  ///
  /// The returned session holds the device until [finishEnrollment] or
  /// [abortEnrollment] is called. It also self-aborts, so a form left open does
  /// not keep the terminal captive.
  Future<ZkEnrollmentSession> beginEnrollment(
    DeviceSettingsModel settings, {
    required int uid,
    required String deviceUserId,
    int finger = defaultFinger,
  }) async {
    if (!settings.isConfigured) {
      throw const ApiException(LangKeys.errorDeviceNotConfigured);
    }

    final lease = await _gate.acquire();
    ZKTeco? device;

    try {
      device = await _connect(settings);

      // A capture left running from an abandoned attempt would make the device
      // reject this one.
      await device.command(Util.CMD_CANCELCAPTURE);

      final payload = Uint8List(26);
      final id = Cp1256.encode(deviceUserId);
      // <24s b b> — user id, finger index, then a flag the firmware wants set.
      for (var i = 0; i < id.length && i < 24; i++) {
        payload[i] = id[i];
      }
      payload[24] = finger;
      payload[25] = 1;

      final response = await device.command(
        _cmdStartEnroll,
        commandString: payload,
      );

      if (response['status'] != true) {
        throw ApiException(
          LangKeys.errorEnrollStartFailed,
          detail: 'device replied ${response['code']}',
        );
      }

      return ZkEnrollmentSession._(
        device: device,
        lease: lease,
        uid: uid,
        finger: finger,
      );
    } catch (e) {
      // Nothing is holding the session if we failed part-way through.
      if (device != null) {
        try {
          await device.disconnect();
        } catch (_) {}
      }
      lease.release();
      if (e is ApiException) rethrow;
      throw ApiException(LangKeys.errorEnrollStartFailed, detail: e.toString());
    }
  }

  /// Checks whether a template landed, then closes the session.
  Future<bool> finishEnrollment(ZkEnrollmentSession session) async {
    try {
      // The admin may press Done while the terminal is still asking for the
      // second or third press. Standing the capture down first means the read
      // below is answered rather than queued behind it; a template that was
      // already stored is not lost by cancelling.
      try {
        await session.device.command(Util.CMD_CANCELCAPTURE);
      } catch (_) {
        // The device times the capture out on its own.
      }

      return await _hasTemplate(
        session.device,
        uid: session.uid,
        finger: session.finger,
      );
    } catch (_) {
      return false;
    } finally {
      await session.close();
    }
  }

  /// Cancels a capture nobody completed and frees the terminal.
  Future<void> abortEnrollment(ZkEnrollmentSession session) async {
    try {
      await session.device.command(Util.CMD_CANCELCAPTURE);
    } catch (_) {
      // The device times the capture out on its own.
    } finally {
      await session.close();
    }
  }

  /// Whether a template now exists for that finger — the check that tells us
  /// the person actually completed the enrolment on the device.
  Future<bool> hasFingerprint(
    DeviceSettingsModel settings, {
    required int uid,
    int finger = defaultFinger,
  }) async {
    return _withDevice(settings, (device) async {
      return _hasTemplate(device, uid: uid, finger: finger);
    });
  }

  /// Whether the terminal holds a template in that slot.
  ///
  /// Not the package's `Fingerprint.getFinger`, for the same reason the table
  /// reads are hand-rolled. That method sends the request and then calls
  /// `Util.recData(first: false)` to collect the reply — but on TCP the whole
  /// exchange has already arrived in `device.data` by the time the command
  /// returns, so `recData` sits waiting for a continuation the terminal will
  /// never send, backing off 0.5s, 1s, 2s, 4s through its retry count before
  /// giving up and returning nothing. That is close to half a minute of frozen
  /// UI ending in "no fingerprint stored yet" for a finger the device had
  /// perfectly well stored.
  Future<bool> _hasTemplate(
    ZKTeco device, {
    required int uid,
    required int finger,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await device.command(
        Util.CMD_USER_TEMP_RRQ,
        commandString: Uint8List.fromList([
          uid & 0xFF,
          (uid >> 8) & 0xFF,
          finger,
        ]),
      );
    } catch (_) {
      return false;
    }

    // An empty slot is refused outright rather than answered with an empty
    // template, so a rejected read is the normal "nothing enrolled" answer.
    if (response['status'] != true) return false;

    final raw = Uint8List.fromList(device.data);
    final replyKind = device.header.isEmpty ? 0 : device.header[0];

    // Announced up front when the terminal frames the reply, and simply the
    // payload when it sends the template inline.
    final int size;
    if (replyKind == Util.CMD_PREPARE_DATA && raw.length >= 4) {
      size = ByteData.sublistView(raw, 0, 4).getUint32(0, Endian.little);
    } else {
      size = raw.length;
    }

    await _releaseData(device);
    return size >= _minTemplateBytes;
  }

  /// Tells the terminal the prepared reply can be let go.
  ///
  /// Skipping it is what made consecutive reads unreliable: the unit keeps the
  /// table open and the next command's reply arrives behind the remains of the
  /// last.
  static Future<void> _releaseData(ZKTeco device) async {
    try {
      await device.command(Util.CMD_FREE_DATA);
    } catch (_) {
      // The session ends either way; a refused release is not worth failing an
      // answer that already arrived.
    }
  }

  /// Removes a person from the terminal, fingerprint templates and all.
  ///
  /// Returns false when the terminal has nobody under that id — already gone is
  /// a success from the caller's point of view, not an error.
  ///
  /// The delete has to go by `uid`, which is the enrolment slot, while the app
  /// only stores `deviceUserId`. On this firmware the two differ, so the id is
  /// resolved against the live enrolment list rather than assumed.
  Future<bool> deleteUser(
    DeviceSettingsModel settings, {
    required String deviceUserId,
  }) async {
    final existing = await _enrolledUsers(settings);
    final match = existing.where((u) => u.deviceUserId == deviceUserId.trim());
    if (match.isEmpty) return false;

    final uid = match.first.uid ?? 0;
    if (uid == 0) return false;

    return _withDevice(settings, (device) async {
      final response = await device.removeUser(uid);
      if (response == false) {
        throw const ApiException(LangKeys.errorDeviceDeleteFailed);
      }
      return true;
    });
  }

  /// Stops a capture the operator walked away from, so the terminal returns to
  /// its normal screen instead of waiting for a finger forever.
  Future<void> cancelEnrollment(DeviceSettingsModel settings) async {
    return _withDevice(settings, (device) async {
      await device.command(Util.CMD_CANCELCAPTURE);
    });
  }

  /// Everyone the terminal has enrolled, or null when the read did not make
  /// sense and is worth trying again in a fresh session.
  ///
  /// This goes through [ZkTableReader] rather than the package's own buffered
  /// read, and that is the whole of it: `FingerBridge.readWithBuffer` opens
  /// with `CMD_PREPARE_BUFFER`, which firmware 6.60 does not implement, and the
  /// package turns the refusal into "RWB Not supported". Thrown out of a plain
  /// read it became [LangKeys.errorDeviceRead] — the terminal connects, then
  /// every enrolment fails with "connected, but reading from the terminal
  /// failed" and nothing to say about why. The sync path was moved off it long
  /// ago; enrolment was the one caller left behind.
  Future<List<ZkDeviceUserModel>?> _readUsers(ZKTeco device) async {
    // The terminal's own count. An empty enrolment table is the ordinary state
    // of a new unit, and asking for it anyway turns that into a failed read.
    final sizes = await _optional(() => Util.readSizes(device));
    return _readUsersOfCount(device, sizes?.users ?? -1);
  }

  /// The table itself, given the count the terminal already reported.
  ///
  /// Split out so a caller that wants the memory figures as well — the push
  /// wants the free-slot count — does not have to ask for them in a second
  /// session.
  Future<List<ZkDeviceUserModel>?> _readUsersOfCount(
    ZKTeco device,
    int count,
  ) async {
    if (count == 0) return const <ZkDeviceUserModel>[];
    if (count < 0) return null;

    final buffer = await ZkTableReader.read(
      device,
      Util.CMD_USER_TEMP_RRQ,
      fct: Util.FCT_USER,
      expectedRecords: count,
    );

    final users = ZkUserParser.parse(buffer, recordCount: count);
    // The terminal just said it holds people; nothing decoded means the buffer
    // did not arrive intact, not that the device is empty.
    return users.isEmpty ? null : users;
  }

  /// The enrolment list, retried in a fresh session when it comes back
  /// unusable.
  ///
  /// This unit desyncs between back-to-back sessions and answers one command
  /// with the tail of the last. There is nothing to repair once that has
  /// happened — dropping the session and starting again is the cure.
  Future<List<ZkDeviceUserModel>> _enrolledUsers(
    DeviceSettingsModel settings, {
    int attempts = 3,
  }) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      final users = await _withDevice(settings, _readUsers);
      if (users != null) return users;

      // Give the terminal longer each time to finish letting the last session
      // go before the next one asks it for anything.
      if (attempt < attempts) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw const ApiException(LangKeys.errorDeviceRead);
  }

  /// Runs a device query that is allowed to fail, yielding null instead.
  static Future<T?> _optional<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  /// Writes one 72-byte user record.
  ///
  /// Built by hand rather than through the package's `setUser` for two reasons.
  /// It encodes the name with `String.codeUnits`, which turns Arabic into
  /// nonsense — the device wants Windows-1256. And it crashes on the default
  /// `cardNo: 0`: that becomes the odd-length hex string "0", which its
  /// `reverseHex` then indexes at -1.
  ///
  /// The layout matches the package's own writer, and the offsets are the ones
  /// verified against this firmware in [ZkUserParser].
  Future<void> _writeUser(
    ZKTeco device, {
    required int uid,
    required String userId,
    required String name,
  }) async {
    final record = Uint8List(72);

    record[0] = uid & 0xFF;
    record[1] = (uid >> 8) & 0xFF;
    record[2] = Util.LEVEL_USER;
    // 3..10 password, 35..38 card number — left as zeros.

    _put(record, 11, Cp1256.encode(name), 24);
    // Group id; the firmware expects this to be 1, not 0.
    record[39] = 1;
    _put(record, 48, Cp1256.encode(userId), 9);

    final response = await device.command(
      Util.CMD_SET_USER,
      commandString: record,
    );

    if (response['status'] != true) {
      throw ApiException(
        LangKeys.errorDeviceWriteFailed,
        detail: 'device replied ${response['code']}',
      );
    }
  }

  /// Copies [bytes] into [target] at [offset], truncated to [width]. The rest
  /// of the field stays zero, which is how the firmware marks it unused.
  static void _put(Uint8List target, int offset, List<int> bytes, int width) {
    for (var i = 0; i < bytes.length && i < width; i++) {
      target[offset + i] = bytes[i];
    }
  }

  /// Terminals reject uid 0, and reusing one would overwrite whoever holds it.
  static int _nextUid(List<ZkDeviceUserModel> users) {
    var max = 0;
    for (final user in users) {
      final uid = user.uid ?? 0;
      if (uid > max) max = uid;
    }
    return max + 1;
  }

  /// The next free numeric user id. Ids are limited to 9 characters by the
  /// protocol, so this stays numeric rather than inventing a scheme.
  static String _nextUserId(List<ZkDeviceUserModel> users) {
    var max = 0;
    for (final user in users) {
      final value = int.tryParse(user.deviceUserId) ?? 0;
      if (value > max) max = value;
    }
    return '${max + 1}';
  }

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
    final device = await _connect(settings);

    try {
      return await action(device);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(LangKeys.errorDeviceRead, detail: e.toString());
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}

      // The terminal needs a moment between sessions, and enrolment now opens
      // three in a row: the enrolment list, the user write, then the capture.
      // Without the pause the next one connects to a unit still winding this
      // one down and gets the tail of this session's reply. The delay is inside
      // the gate lease on purpose, so the queue does not move on before it.
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  /// Opens a session. The caller owns closing it.
  Future<ZKTeco> _connect(DeviceSettingsModel settings) async {
    final device = ZKTeco(
      settings.ip.trim(),
      port: settings.port,
      tcp: settings.useTcp,
      timeout: const Duration(seconds: 15),
      // Never null — see ZkDeviceDataSource for why "0" is the right blank.
      password: settings.commKey.trim().isEmpty ? '0' : settings.commKey.trim(),
      debug: kDebugMode,
    );

    bool connected = false;
    try {
      connected = await device.connect(ommitPing: settings.skipPing);
    } catch (e) {
      throw ApiException(LangKeys.errorDeviceUnreachable, detail: e.toString());
    }
    if (!connected) throw const ApiException(LangKeys.errorDeviceUnreachable);

    return device;
  }
}

/// A capture in progress, holding the terminal open until it is closed.
class ZkEnrollmentSession {
  ZkEnrollmentSession._({
    required this.device,
    required ZkGateLease lease,
    required this.uid,
    required this.finger,
    // ignore: prefer_initializing_formals
  }) : _lease = lease {
    // A form left open must not keep the terminal captive; the device would
    // stop accepting punches for everyone else.
    _watchdog = Timer(const Duration(minutes: 3), () {
      close();
    });
  }

  final ZKTeco device;
  final ZkGateLease _lease;
  final int uid;
  final int finger;

  Timer? _watchdog;
  bool _closed = false;

  bool get isClosed => _closed;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _watchdog?.cancel();
    _watchdog = null;

    try {
      await device.disconnect();
    } catch (_) {}
    _lease.release();
  }
}

/// Who the terminal now knows this person as.
class ZkEnrolledUser {
  /// The device's internal enrolment slot — what fingerprint templates hang off.
  final int uid;

  /// The id attendance records carry, and what an employee is mapped by.
  final String deviceUserId;

  final String name;

  const ZkEnrolledUser({
    required this.uid,
    required this.deviceUserId,
    required this.name,
  });
}
