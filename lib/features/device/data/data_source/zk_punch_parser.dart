import 'dart:typed_data';

// ignore: implementation_imports
import 'package:flutter_zkteco/src/util.dart';

import '../models/device_settings_model.dart';

/// Reads the punch log out of the terminal's raw buffer.
///
/// The package's own attendance reader cannot be used, for the same reason its
/// user reader cannot: before parsing a single record it calls `getUsers()` to
/// turn each record's `uid` into a user id, and on firmware that rejects the
/// buffered read that call throws — so the punch log fails for a reason that
/// has nothing to do with punches.
///
/// It is also unnecessary. Every record layout but the shortest carries the
/// user id itself, and that id — not `uid` — is what the attendance records are
/// filed under. See [ZkUserParser] for why the two must never be confused.
class ZkPunchParser {
  ZkPunchParser._();

  /// Parses [buffer], a little-endian `uint32` byte count followed by the
  /// records themselves.
  ///
  /// [recordCount] comes from the terminal's own capacity report and is what
  /// fixes the record width: the widths in the wild (8, 16, 40) do not divide
  /// a buffer unambiguously, so guessing from the length alone picks the wrong
  /// one and yields a log full of dates in the year 2000.
  static List<ZkPunchModel> parse(
    Uint8List buffer, {
    required int recordCount,
  }) {
    if (buffer.length <= 4 || recordCount <= 0) return const [];

    final declared = ByteData.sublistView(
      buffer,
      0,
      4,
    ).getUint32(0, Endian.little);

    // Integer division on purpose: the terminal pads its byte count out past
    // where the records actually end.
    var size = (declared > 0 ? declared : buffer.length) ~/ recordCount;
    if (![8, 16, 40].contains(size)) {
      // The count was not usable — fall back to the width that divides the
      // buffer exactly, widest first, since 40 is what this firmware family
      // writes.
      size = [40, 16, 8].firstWhere(
        (candidate) => buffer.length >= recordCount * candidate,
        orElse: () => 0,
      );
      if (size == 0) return const [];
    }

    final need = recordCount * size;
    if (buffer.length < need) return const [];

    // Taken from the end, and deliberately not from a fixed offset. What sits
    // in front of the records is not constant: depending on how the reply is
    // chunked the buffer arrives either as a bare run of records or with the
    // terminal's framing — a byte count, a magic number, a packet header —
    // ahead of them. Counting forward from the front therefore lands mid-record
    // about half the time, which is what made the same 96 punches decode as
    // real names and dates on one run and as user 3840 in the year 2000 on the
    // next. The records are always last, and their total width is known
    // exactly, so the end is the one landmark that holds.
    final body = buffer.sublist(buffer.length - need);

    final punches = <ZkPunchModel>[];
    for (var offset = 0; offset + size <= body.length; offset += size) {
      final record = Uint8List.sublistView(body, offset, offset + size);
      final punch = switch (size) {
        40 => _parse40(record),
        16 => _parse16(record),
        _ => _parse8(record),
      };
      if (punch != null) punches.add(punch);
    }

    // A read that mostly failed to make sense is treated as no read at all.
    //
    // This terminal desyncs between back-to-back sessions often enough to
    // matter: the reply to one command arrives carrying the tail of the last
    // one, the record count comes back wrong, and the buffer decodes into
    // plausible-looking rubbish — twenty punches by users 0 and 26, dated in
    // the year 2000. Those must never reach the punch log. Once written they
    // are indistinguishable from real scans, they fold into attendance days
    // nobody can account for, and the raw log is deliberately never rewritten,
    // so there is no undoing them. Refusing the read costs one sync; the caller
    // simply tries again.
    if (punches.length < recordCount / 2) return const [];
    return punches;
  }

  /// The window a real scan can fall in.
  ///
  /// The terminal counts from 2000, so a misaligned decode lands there almost
  /// every time — that is the tell. The upper bound catches the same fault
  /// pointing the other way, and allows for a device clock running ahead.
  static bool _isPlausible(DateTime at) {
    final now = DateTime.now();
    return at.isAfter(DateTime(2015)) &&
        at.isBefore(now.add(const Duration(days: 2)));
  }

  /// uid | user id as text | status | time | punch mode | padding
  static ZkPunchModel? _parse40(Uint8List r) {
    final bd = ByteData.sublistView(r);
    final userId = Util.extractString(r.sublist(2, 26));
    return _build(
      userId: userId,
      uid: bd.getUint16(0, Endian.little),
      state: bd.getUint8(26),
      seconds: bd.getUint32(27, Endian.little),
      type: bd.getUint8(31),
    );
  }

  static ZkPunchModel? _parse16(Uint8List r) {
    final bd = ByteData.sublistView(r);
    return _build(
      userId: bd.getUint32(0, Endian.little).toString(),
      uid: null,
      state: bd.getUint8(8),
      seconds: bd.getUint32(4, Endian.little),
      type: bd.getUint8(9),
    );
  }

  /// The short layout has no room for the user id and carries `uid` instead —
  /// the one case where falling back to it is not a choice.
  static ZkPunchModel? _parse8(Uint8List r) {
    final bd = ByteData.sublistView(r);
    final uid = bd.getUint16(0, Endian.little);
    return _build(
      userId: uid.toString(),
      uid: uid,
      state: bd.getUint8(2),
      seconds: bd.getUint32(3, Endian.little),
      type: bd.getUint8(7),
    );
  }

  static ZkPunchModel? _build({
    required String userId,
    required int? uid,
    required int state,
    required int seconds,
    required int type,
  }) {
    // A zero time is an empty slot, not a scan at midnight on the epoch the
    // terminal counts from.
    if (seconds <= 0) return null;

    final at = Util.decodeTime(seconds);
    if (!_isPlausible(at)) return null;

    final id = userId.trim();
    final resolved = (id.isEmpty || id == '0') ? (uid?.toString() ?? '') : id;
    if (resolved.isEmpty) return null;

    return ZkPunchModel(
      deviceUserId: resolved,
      timestamp: at,
      state: state,
      type: type,
    );
  }
}
