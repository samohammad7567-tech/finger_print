import 'dart:typed_data';

import '../../../../core/utils/cp1256.dart';
import '../models/device_settings_model.dart';

/// Reads the terminal's enrolment table out of the raw user buffer.
///
/// The protocol package cannot be used for this. Its own `setUser` writer lays
/// a 72-byte record out as:
///
///   0..1 uid | 2 privilege | 3..10 password | 11..34 name | 35..38 card
///   39..47 group+timezone | 48..56 **userid** | 57..71 padding
///
/// but its reader takes `userid` from bytes 68..72, which is inside the
/// padding — so every user comes back with an empty id. On the terminal here
/// that mattered a great deal: `uid` and `userid` are not the same number and
/// are not even in the same order, so falling back to `uid` would have filed
/// each person's attendance under someone else.
///
///   uid 2 -> userid 3 (ابو خالد) | uid 3 -> userid 2 | uid 4 -> userid 1
///
/// The attendance records identify people by **userid**, so that is the value
/// that has to reach [EmployeeModel.deviceUserId].
class ZkUserParser {
  ZkUserParser._();

  static const _recordSize72 = 72;
  static const _recordSize28 = 28;

  /// Parses the payload returned for CMD_USER_TEMP_RRQ, including its 4-byte
  /// size header.
  /// [recordCount] is the terminal's own count of enrolled users, when it is
  /// known. With it the records can be found exactly; without it their width is
  /// inferred from the buffer, which is what the tests do.
  static List<ZkDeviceUserModel> parse(
    Uint8List buffer, {
    int recordCount = 0,
  }) {
    if (buffer.length <= 4) return const [];

    final Uint8List payload;
    final int size;

    if (recordCount > 0) {
      // Anchored to the end of the buffer rather than counted from the front.
      // What precedes the records is not constant — depending on how the reply
      // is chunked they arrive bare or behind the terminal's own framing — so a
      // fixed offset lands mid-record about half the time. The punch log was
      // decoding as scans by user 3840 in the year 2000 for exactly this
      // reason; the records are always last, so the end is the landmark that
      // holds.
      final width = [_recordSize72, _recordSize28].firstWhere(
        (candidate) => buffer.length >= recordCount * candidate,
        orElse: () => 0,
      );
      if (width == 0) return const [];
      size = width;
      payload = buffer.sublist(buffer.length - recordCount * width);
    } else {
      final body = buffer.sublist(4);
      // Both record layouts are in the wild; pick whichever divides evenly.
      final width = body.length % _recordSize72 == 0
          ? _recordSize72
          : (body.length % _recordSize28 == 0 ? _recordSize28 : 0);
      if (width == 0) return const [];
      size = width;
      payload = body;
    }

    final users = <ZkDeviceUserModel>[];
    for (var offset = 0; offset + size <= payload.length; offset += size) {
      final record = payload.sublist(offset, offset + size);
      final user = size == _recordSize72 ? _parse72(record) : _parse28(record);
      if (user != null) users.add(user);
    }
    return users;
  }

  static ZkDeviceUserModel? _parse72(Uint8List r) {
    final uid = ByteData.sublistView(r).getUint16(0, Endian.little);
    final name = Cp1256.decodeField(r.sublist(11, 35));
    final userId = Cp1256.decodeField(r.sublist(48, 57));
    return _build(uid: uid, userId: userId, name: name);
  }

  static ZkDeviceUserModel? _parse28(Uint8List r) {
    final bd = ByteData.sublistView(r);
    final uid = bd.getUint16(0, Endian.little);
    final name = Cp1256.decodeField(r.sublist(8, 16));
    // The short layout stores the id as a little-endian integer, not text.
    final userId = bd.getUint32(24, Endian.little).toString();
    return _build(uid: uid, userId: userId, name: name);
  }

  static ZkDeviceUserModel? _build({
    required int uid,
    required String userId,
    required String name,
  }) {
    // An id of "0" means the slot is empty, not a user called zero.
    final id = userId.trim();
    final resolved = (id.isEmpty || id == '0') ? uid.toString() : id;
    if (resolved.isEmpty) return null;

    return ZkDeviceUserModel(
      deviceUserId: resolved,
      name: name.trim(),
      uid: uid,
    );
  }
}
