import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/features/device/data/data_source/zk_punch_parser.dart';

/// The terminal counts seconds from the start of 2000 in its own packed form.
/// Built here rather than imported so a change to the package's decoder shows
/// up as a failure instead of cancelling itself out on both sides.
int encodeTime(DateTime t) {
  return ((t.year % 100) * 12 * 31 + ((t.month - 1) * 31) + t.day - 1) * 86400 +
      (t.hour * 3600 + t.minute * 60 + t.second);
}

/// One 40-byte record: uid, the user id as text, status, time, punch mode.
Uint8List record40({
  required int uid,
  required String userId,
  required DateTime at,
  int status = 1,
  int punch = 0,
}) {
  final out = Uint8List(40);
  final bd = ByteData.sublistView(out);
  bd.setUint16(0, uid, Endian.little);
  final id = userId.codeUnits;
  out.setRange(2, 2 + id.length, id);
  bd.setUint8(26, status);
  bd.setUint32(27, encodeTime(at), Endian.little);
  bd.setUint8(31, punch);
  return out;
}

/// A reply as the terminal frames it: the byte count, then the records.
Uint8List reply(List<Uint8List> records, {List<int> framing = const []}) {
  final body = <int>[for (final r in records) ...r];
  final out = <int>[];
  final size = Uint8List(4);
  ByteData.sublistView(size).setUint32(0, body.length, Endian.little);
  out.addAll(size);
  out.addAll(framing);
  out.addAll(body);
  return Uint8List.fromList(out);
}

void main() {
  final when = DateTime(2026, 8, 3, 9, 0, 40);

  test('reads the 40-byte layout the terminal writes', () {
    final buffer = reply([
      record40(uid: 1, userId: '1', at: when),
      record40(uid: 2, userId: '2', at: when.add(const Duration(hours: 1))),
    ]);

    final punches = ZkPunchParser.parse(buffer, recordCount: 2);

    expect(punches, hasLength(2));
    expect(punches.first.deviceUserId, '1');
    expect(punches.first.timestamp, when);
    expect(punches.last.deviceUserId, '2');
  });

  test('finds the records behind the framing the reply sometimes carries', () {
    // The same records, this time with the terminal's magic number, a length
    // and a packet header sitting in front of them. Counting forward from the
    // start would land mid-record; counting back from the end does not.
    final buffer = reply(
      [record40(uid: 3, userId: '3', at: when)],
      framing: [0xF8, 0xFF, 0, 0, 0x50, 0x50, 0x82, 0x7D, 12, 15, 0, 0],
    );

    final punches = ZkPunchParser.parse(buffer, recordCount: 1);

    expect(punches.single.deviceUserId, '3');
    expect(punches.single.timestamp, when);
  });

  test('refuses a buffer that decoded into rubbish', () {
    // What a misaligned read actually produced against the real terminal:
    // records read four bytes out, which puts every timestamp back in 2000.
    final good = reply([
      for (var i = 0; i < 8; i++)
        record40(
          uid: i,
          userId: '$i',
          at: when.add(Duration(minutes: i)),
        ),
    ]);
    final skewed = Uint8List.fromList(good.sublist(2));

    // Nothing survives, rather than eight punches nobody can account for. Once
    // written they would be indistinguishable from real scans.
    expect(ZkPunchParser.parse(skewed, recordCount: 8), isEmpty);
  });

  test('drops the empty slots a part-filled buffer ends with', () {
    final buffer = reply([
      record40(uid: 1, userId: '1', at: when),
      Uint8List(40), // never written to
    ]);

    // One real punch is half of two, and the guard is "fewer than half", so
    // this is kept — an empty slot is not evidence the read went wrong.
    final punches = ZkPunchParser.parse(buffer, recordCount: 2);
    expect(punches, hasLength(1));
    expect(punches.single.deviceUserId, '1');
  });

  test('an empty or impossible buffer yields nothing rather than throwing', () {
    expect(ZkPunchParser.parse(Uint8List(0), recordCount: 5), isEmpty);
    expect(ZkPunchParser.parse(Uint8List(4), recordCount: 5), isEmpty);
    expect(
      ZkPunchParser.parse(
        reply([record40(uid: 1, userId: '1', at: when)]),
        recordCount: 0,
      ),
      isEmpty,
    );
  });
}
