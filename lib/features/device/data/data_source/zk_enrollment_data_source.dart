import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_zkteco/flutter_zkteco.dart';
// ignore: implementation_imports
import 'package:flutter_zkteco/src/util.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/cp1256.dart';
import '../../../../core/utils/enrollment_finger.dart';
import '../models/device_settings_model.dart';
import '../models/zk_push_models.dart';
import 'zk_device_gate.dart';
import 'zk_table_reader.dart';
import 'zk_template_reply.dart';
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

  /// Right thumb. Terminals store ten slots per person, 0..9.
  static const defaultFinger = EnrollmentFinger.rightThumb;

  /// The name field in a user record. Windows-1256 is one byte per character,
  /// Arabic included, so this is 24 characters either way — and anything past
  /// it is dropped by the write, not by the terminal's screen.
  static const _nameBytes = 24;

  /// Refusals in a row that end a bulk push. Low on purpose: past two or three
  /// the terminal is gone, not fussy.
  static const _maxConsecutiveFailures = 3;

  /// How many fresh sessions an unusable table read is worth. The unit answers
  /// one command with the tail of the previous session now and then; a new
  /// session is the only cure.
  static const _readAttempts = 3;

  /// How long one command may wait for the terminal's reply.
  ///
  /// The package's `command` waits on the socket stream without a deadline, so
  /// a terminal that has half-closed or swallowed a reply leaves the caller —
  /// and the form behind it — waiting indefinitely. Every call here goes through
  /// [_command], and running out is treated as a failure worth retrying in a
  /// fresh session rather than a reason to hang.
  static const _replyTimeout = Duration(seconds: 10);

  /// How long the socket has to stay quiet before a template reply is taken to
  /// be finished. The template tail follows its `CMD_PREPARE_DATA` announcement
  /// almost immediately on a local network; anything longer is another command's
  /// reply, which must not be swallowed here.
  static const _templateQuiet = Duration(milliseconds: 300);

  /// Ceiling on that quiet wait, so a chatty or broken unit cannot hold an
  /// enrolment scan open indefinitely.
  static const _templateSettleTimeout = Duration(seconds: 5);

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
    final identity = _identityFor(existing, deviceUserId);
    final user = ZkEnrolledUser(
      uid: identity.uid,
      deviceUserId: identity.userId,
      name: name,
    );

    return _withDevice(settings, (device) async {
      await _writeUser(
        device,
        uid: user.uid,
        userId: user.deviceUserId,
        name: name,
      );
      return user;
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
    int attempts = _readAttempts,
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
      await _startCaptureInSession(
        device,
        userId: deviceUserId,
        finger: finger,
      );

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

  /// Resolves the person's slot, writes them and starts the capture — all in
  /// **one** session.
  ///
  /// [upsertUser] followed by [beginEnrollment] opened three sessions for this:
  /// the table read, the write, then the capture. Each one paid a connect and a
  /// 600ms quiet period, so the terminal did not start asking for a finger until
  /// well over two seconds after the button was pressed. Worse, the second and
  /// third connections often landed while the unit was still winding the last
  /// one down, and the reply to the start command came back as the tail of the
  /// previous session — the intermittent "refused to start enrolment" failure.
  ///
  /// Doing it in one session removes both the wait and that desync window. The
  /// table read is still allowed to fail: a desynced read cannot be trusted for
  /// the free slot or id, so the session is dropped and the whole thing retried
  /// fresh, exactly as [_enrolledUsers] does.
  ///
  /// If the write lands but the capture does not start, the person already
  /// exists on the terminal. [ZkEnrollmentStartException] carries their
  /// identifiers so the form keeps the mapping and a retry reuses the slot
  /// instead of leaving an orphan behind and creating a second person.
  Future<({ZkEnrolledUser user, ZkEnrollmentSession session})>
  beginEnrollmentFor(
    DeviceSettingsModel settings, {
    required String name,
    String? deviceUserId,
    int finger = defaultFinger,
  }) async {
    if (!settings.isConfigured) {
      throw const ApiException(LangKeys.errorDeviceNotConfigured);
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ApiException(LangKeys.errorEnrollNeedsName);
    }

    final lease = await _gate.acquire();
    ZKTeco? device;

    try {
      for (var attempt = 1; attempt <= _readAttempts; attempt++) {
        final connected = await _connect(settings);
        device = connected;

        try {
          await _tryCancelCapture(connected);
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 400));

        final sizes = await _optional(() => Util.readSizes(connected));
        final existing = await _readUsersOfCount(connected, sizes?.users ?? -1);

        // The free slot and the free id are both derived from this list, so a
        // read that did not decode cannot be used — it would hand out uid 1 and
        // overwrite whoever holds it.
        if (existing == null) {
          try {
            await connected.disconnect();
          } catch (_) {}
          device = null;

          if (attempt == _readAttempts) {
            throw const ApiException(LangKeys.errorDeviceRead);
          }
          // Give the terminal longer each time to let the failed session go.
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          continue;
        }

        final identity = _identityFor(existing, deviceUserId);
        final user = ZkEnrolledUser(
          uid: identity.uid,
          deviceUserId: identity.userId,
          name: trimmed,
        );

        await _writeUser(
          connected,
          uid: user.uid,
          userId: user.deviceUserId,
          name: trimmed,
        );

        try {
          await _startCaptureInSession(
            connected,
            userId: user.deviceUserId,
            finger: finger,
          );
        } on ApiException catch (e) {
          throw ZkEnrollmentStartException(user: user, errorKey: e.errorKey);
        }

        return (
          user: user,
          session: ZkEnrollmentSession._(
            device: connected,
            lease: lease,
            uid: user.uid,
            finger: finger,
          ),
        );
      }

      // The loop only exits through a return or a throw above.
      throw const ApiException(LangKeys.errorDeviceRead);
    } catch (e) {
      if (device != null) {
        try {
          await device.disconnect();
        } catch (_) {}
      }
      lease.release();
      if (e is ZkEnrollmentStartException) rethrow;
      if (e is ApiException) rethrow;
      throw ApiException(LangKeys.errorEnrollStartFailed, detail: e.toString());
    }
  }

  /// Clears any capture left pending, then asks the terminal to start one.
  Future<void> _startCaptureInSession(
    ZKTeco device, {
    required String userId,
    required int finger,
  }) async {
    try {
      await _startCapture(device, userId: userId, finger: finger);
      return;
    } catch (_) {}
    try {
      await _tryCancelCapture(device);
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      await _startCapture(device, userId: userId, finger: finger);
      return;
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _startCapture(device, userId: userId, finger: finger);
  }

  /// Sends the capture command and insists on an acknowledgement.
  Future<void> _startCapture(
    ZKTeco device, {
    required String userId,
    required int finger,
  }) async {
    final payload = Uint8List(26);
    final id = Cp1256.encode(userId);
    // <24s b b> — user id, finger index, then a flag the firmware wants set.
    for (var i = 0; i < id.length && i < 24; i++) {
      payload[i] = id[i];
    }
    payload[24] = finger;
    payload[25] = 1;

    final response = await device
        .command(_cmdStartEnroll, commandString: payload)
        .timeout(const Duration(seconds: 10));

    if (response['status'] != true) {
      throw ApiException(
        LangKeys.errorEnrollStartFailed,
        detail: 'device replied ${response['code']}',
      );
    }
  }

  /// Stands down a capture nobody is waiting for. A refused cancel is ordinary
  /// when no capture was running, so it never blocks what comes next.
  static Future<void> _tryCancelCapture(ZKTeco device) async {
    try {
      await device.command(Util.CMD_CANCELCAPTURE).timeout(const Duration(seconds: 2));
    } catch (_) {
      try {
        await _command(device, Util.CMD_CANCELCAPTURE);
      } catch (_) {}
    }
  }

  /// Checks whether a template landed, then closes the session.
  Future<bool> finishEnrollment(ZkEnrollmentSession session) async {
    try {
      // The admin may press Done while the terminal is still asking for the
      // second or third press. Standing the capture down first means the read
      // below is answered rather than queued behind it; a template that was
      // already stored is not lost by cancelling.
      await _tryCancelCapture(session.device);

      // The last press can take a moment to settle. Asking three times over a
      // second costs nothing compared with sending the person back to the
      // scanner for a finger the terminal already stored.
      for (var attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        final stored = await _hasTemplate(
          session.device,
          uid: session.uid,
          finger: session.finger,
        );
        if (stored) return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      await session.close();
    }
  }

  /// Cancels a capture nobody completed and frees the terminal.
  Future<void> abortEnrollment(ZkEnrollmentSession session) async {
    try {
      await _tryCancelCapture(session.device);
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

  /// Resolves the person's enrolment slot and every finger they have stored.
  ///
  /// The form opens with only the `deviceUserId` the app saved, while templates
  /// hang off the terminal's internal `uid`, so the table is read to bridge the
  /// two. Null means the terminal has nobody under that id — the employee was
  /// deleted on the device, or the mapping is stale.
  Future<({int uid, Set<int> fingers})?> fingerprints(
    DeviceSettingsModel settings, {
    required String deviceUserId,
  }) async {
    final id = deviceUserId.trim();
    if (id.isEmpty) return null;

    final existing = await _enrolledUsers(settings);
    final match = existing.where((u) => u.deviceUserId == id);
    if (match.isEmpty) return null;

    final uid = match.first.uid ?? 0;
    if (uid == 0) return null;

    final fingers = await enrolledFingers(settings, uid: uid);
    return (uid: uid, fingers: fingers);
  }

  /// Every finger slot the terminal holds a template in for [uid].
  ///
  /// All ten are asked inside one session: a session per finger would pay the
  /// terminal's connect and 600 ms quiet period ten times over. A refused slot
  /// is the ordinary "nothing enrolled" answer and never fails the scan. A
  /// terminal that stops answering ends it instead of spending ten timeouts in
  /// a row — what was read so far is still useful.
  Future<Set<int>> enrolledFingers(
    DeviceSettingsModel settings, {
    required int uid,
  }) async {
    return _withDevice(settings, (device) async {
      final fingers = <int>{};
      for (var finger = 0; finger < EnrollmentFinger.count; finger++) {
        final present = await _templatePresence(
          device,
          uid: uid,
          finger: finger,
        );
        if (present == null) break;
        if (present) fingers.add(finger);
      }
      return fingers;
    });
  }

  /// Every enrolled finger for every person in [users], in one session.
  ///
  /// The sync already has the enrolment table in hand, so this does not read it
  /// again — [ZkDeviceUserModel.uid] is the slot templates hang off. Users
  /// without a usable uid are skipped. A person is only reported once every one
  /// of their ten slots has been read, because a half-scanned set would clear
  /// fingers the terminal still holds. People the scan could not finish are
  /// left out of the result; [saveEnrolledFingers] treats absence as "unknown",
  /// so their stored count is not touched. Two people failing in a row means the
  /// session is gone and the scan ends rather than spending a timeout per slot
  /// on everybody who is left.
  Future<Map<String, Set<int>>> enrolledFingersForUsers(
    DeviceSettingsModel settings,
    List<ZkDeviceUserModel> users,
  ) async {
    final targets = <String, int>{};
    for (final user in users) {
      final uid = user.uid;
      if (uid == null || uid <= 0) continue;
      targets[user.deviceUserId] = uid;
    }
    if (targets.isEmpty) return const {};

    return _withDevice(settings, (device) async {
      final result = <String, Set<int>>{};
      var consecutiveFailures = 0;

      for (final target in targets.entries) {
        final fingers = <int>{};
        var complete = true;

        for (var finger = 0; finger < EnrollmentFinger.count; finger++) {
          final present = await _templatePresence(
            device,
            uid: target.value,
            finger: finger,
          );
          if (present == null) {
            complete = false;
            break;
          }
          if (present) fingers.add(finger);
        }

        if (!complete) {
          consecutiveFailures++;
          if (consecutiveFailures >= 2) break;
          continue;
        }

        consecutiveFailures = 0;
        result[target.key] = fingers;
      }
      return result;
    });
  }

  /// Whether the terminal holds a template in that slot.
  ///
  /// Not the package's `Fingerprint.getFinger`: it sends the request through
  /// `command`, which keeps only the first socket event, and then calls
  /// `Util.recData(first: false)` for the rest. When the template tail has
  /// already arrived — or was dropped between subscriptions — that waits for a
  /// continuation the terminal will never send, backing off 0.5s, 1s, 2s, 4s
  /// through its retry count before giving up. The result was a frozen form
  /// ending in "no fingerprint stored yet" for a finger the device had
  /// perfectly well stored. See [_templatePresence] for the read used instead.
  Future<bool> _hasTemplate(
    ZKTeco device, {
    required int uid,
    required int finger,
  }) async {
    return await _templatePresence(device, uid: uid, finger: finger) ?? false;
  }

  /// As [_hasTemplate], but distinguishes "nothing in this slot" (false) from
  /// "the terminal stopped answering" (null), so a scan of all ten fingers can
  /// stop on a dead session instead of repeating the timeout ten times.
  ///
  /// The reply is read through a collector that subscribes *before* the request
  /// goes out. The package's `command` takes only the first socket event, and
  /// the template tail can be several events; subscribing first is what stops
  /// those events from being dropped and every later slot from reading the
  /// leftovers of the previous one. See [ZkTemplateReply].
  Future<bool?> _templatePresence(
    ZKTeco device, {
    required int uid,
    required int finger,
  }) async {
    // A reply that arrived but could not be decoded is worth asking for once
    // more; a session that said nothing at all is not.
    for (var attempt = 0; attempt < 2; attempt++) {
      final collector = _ReplyCollector(device)..start();

      var answered = true;
      try {
        await _command(
          device,
          Util.CMD_USER_TEMP_RRQ,
          commandString: Uint8List.fromList([
            uid & 0xFF,
            (uid >> 8) & 0xFF,
            finger,
          ]),
        );
      } catch (_) {
        // The command may time out while the reply is still arriving, and the
        // first chunk may be too short for the package to frame. The collector
        // has whatever the socket delivered, so decide from that.
        answered = false;
      }

      await collector.settle(
        waitForReply: answered || collector.chunks.isNotEmpty,
        settled: () => ZkTemplateReply.isSettled(
          collector.chunks,
          tcp: device.tcp,
        ),
      );
      final present = ZkTemplateReply.parse(collector.chunks, tcp: device.tcp);

      // Freeing a prepared reply is what keeps the next request's answer from
      // arriving behind the remains of this one. Only send it when the terminal
      // actually answered; on a dead session it would just spend another
      // timeout.
      if (collector.chunks.isNotEmpty) {
        await _releaseData(device);
      }

      if (present != null) return present;
      if (collector.chunks.isEmpty) return null;
    }

    return null;
  }

  /// Tells the terminal the prepared reply can be let go.
  ///
  /// Skipping it is what made consecutive reads unreliable: the unit keeps the
  /// table open and the next command's reply arrives behind the remains of the
  /// last.
  static Future<void> _releaseData(ZKTeco device) async {
    try {
      await _command(device, Util.CMD_FREE_DATA);
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
      await _command(device, Util.CMD_CANCELCAPTURE);
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
    int attempts = _readAttempts,
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

    final response = await _command(
      device,
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

  /// Works out which slot and user id this person belongs in, reusing their
  /// existing mapping when they already have one.
  static ({int uid, String userId}) _identityFor(
    List<ZkDeviceUserModel> existing,
    String? deviceUserId,
  ) {
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

    return (uid: uid, userId: userId);
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
        // A command that timed out leaves the package's own stream listener
        // waiting for a reply, and it can swallow the exit acknowledgement.
        // Bounded so a session that went quiet cannot hold the gate forever.
        await device.disconnect().timeout(_replyTimeout);
      } catch (_) {}

      // The terminal needs a moment between sessions, and enrolment opens two
      // in a row: the enrolment list, then the write and capture. Without the
      // pause the next one connects to a unit still winding this one down and
      // gets the tail of this session's reply. The delay is inside the gate
      // lease on purpose, so the queue does not move on before it.
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

  /// Sends one command with a deadline, because the package's own `command`
  /// waits on the socket stream forever when a reply never arrives.
  static Future<Map<String, dynamic>> _command(
    ZKTeco device,
    int command, {
    List<int> commandString = const [],
  }) async {
    try {
      return await device
          .command(command, commandString: commandString)
          .timeout(_replyTimeout);
    } on TimeoutException {
      throw const ApiException(
        LangKeys.errorDeviceTimeout,
        detail: 'the terminal did not answer in time',
      );
    }
  }
}

/// Collects everything the socket delivers while one request is in flight.
///
/// The package's `command` subscribes to the broadcast stream *after* sending
/// and cancels as soon as the first event lands. A template reply is normally
/// several events, so the rest were being dropped — and then read as the answer
/// to the next finger, which made every slot after the first look empty.
///
/// Subscribing before the request goes out means nothing is missed, and waiting
/// for the socket to fall quiet at the end means nothing is left behind to
/// desync the next request.
class _ReplyCollector {
  _ReplyCollector(this._device);

  final ZKTeco _device;
  final chunks = <Uint8List>[];

  StreamSubscription<Uint8List>? _subscription;
  DateTime _lastChunkAt = DateTime.now();

  void start() {
    _lastChunkAt = DateTime.now();
    _subscription = _device.streamController.stream.listen((chunk) {
      if (chunk.isEmpty) return;
      chunks.add(chunk);
      _lastChunkAt = DateTime.now();
    });
  }

  /// Returns once no chunk has arrived for
  /// [ZkEnrollmentDataSource._templateQuiet], or the whole wait runs past
  /// [ZkEnrollmentDataSource._templateSettleTimeout]. With [waitForReply]
  /// false — the request failed and nothing has arrived — there is nothing to
  /// wait for and the cancellation is immediate. [settled] lets a reply that is
  /// already finished end the wait at once.
  Future<void> settle({
    bool waitForReply = true,
    bool Function()? settled,
  }) async {
    if (!waitForReply && chunks.isEmpty) {
      await _subscription?.cancel();
      _subscription = null;
      return;
    }
    final deadline = DateTime.now().add(
      ZkEnrollmentDataSource._templateSettleTimeout,
    );
    while (DateTime.now().isBefore(deadline)) {
      if (settled?.call() ?? false) break;
      final idle = DateTime.now().difference(_lastChunkAt);
      if (idle >= ZkEnrollmentDataSource._templateQuiet) break;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    await _subscription?.cancel();
    _subscription = null;
  }
}

/// The person was written to the terminal, but the capture did not start.
///
/// [user] is the slot the terminal now holds them in. Keeping it is what lets
/// the form retry the capture without creating a second person, and what lets
/// the employee be saved with a working device mapping even when the scan is
/// abandoned.
class ZkEnrollmentStartException implements Exception {
  final ZkEnrolledUser user;
  final String errorKey;

  const ZkEnrollmentStartException({
    required this.user,
    required this.errorKey,
  });

  @override
  String toString() =>
      'ZkEnrollmentStartException($errorKey, user: ${user.deviceUserId})';
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
