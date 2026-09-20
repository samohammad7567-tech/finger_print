import 'package:flutter/foundation.dart';
import 'package:flutter_zkteco/flutter_zkteco.dart';
// The package exposes no public API for reading a raw table, and its own
// readers all go through the buffered path this class exists to work around.
// ignore: implementation_imports
import 'package:flutter_zkteco/src/finger_bridge.dart';
// ignore: implementation_imports
import 'package:flutter_zkteco/src/util.dart';

/// Reads a whole table off the terminal — the enrolment list, the punch log —
/// and returns it in the one shape the parsers expect: a little-endian `uint32`
/// byte count followed by that many bytes of records.
///
/// Two protocols do this.
///
///  * **Unbuffered.** The original exchange: ask for the table and take what
///    comes back. Every firmware implements it. Used first, and for everything.
///  * **Buffered.** `CMD_PREPARE_BUFFER` has the terminal assemble the table
///    and hand it over in sized chunks. Better for a table too large for one
///    reply — but only if the unit implements it, and this one does not.
///
/// Firmware 6.60 (serial BRMC204660186) answers `CMD_PREPARE_BUFFER` with an
/// error the package reports as "RWB Not supported". Because the package routes
/// *both* the enrolment list and the punch log through it, one unsupported
/// command took out the whole sync: the terminal connected, reported its serial
/// and its clock quite happily, then failed every read as `error_device_read`
/// with nothing to say about why.
///
/// The order matters more than it looks. Asking for the buffered read first and
/// falling back on failure seems tidier and is not: a refused
/// [FingerBridge.readWithBuffer] leaves a socket listening on a closed
/// controller, and the packets it swallows belong to whatever command runs
/// next. That made every read after the first refusal flaky in a way no single
/// read could explain — the same sync returning 96 punches, then garbage, then
/// none. So the path that works is the one that runs, and the buffered read is
/// reached only when the terminal says a table has rows and the plain read
/// comes back empty.
class ZkTableReader {
  ZkTableReader._();

  /// How long to wait for a continuation that may never come. [Util.recData]
  /// retries on an exponential backoff and gives up only after its own retry
  /// count, which against a terminal that has finished talking is half a minute
  /// of waiting for silence.
  static const _tailTimeout = Duration(seconds: 6);

  /// [expectedRecords] is the terminal's own count for this table. It decides
  /// whether an empty read means "nothing to fetch" — the normal state of a
  /// terminal nobody has enrolled on — or a read that failed and is worth
  /// trying the other way.
  static Future<Uint8List> read(
    ZKTeco device,
    int command, {
    int fct = 0,
    int expectedRecords = 0,
  }) async {
    final direct = await _unbuffered(device, command);
    if (direct.length > 4 || expectedRecords <= 0) return direct;

    try {
      final buffered = await FingerBridge.readWithBuffer(
        device,
        command,
        fct: fct,
      );
      return buffered.data;
    } catch (_) {
      return direct;
    }
  }

  static Future<Uint8List> _unbuffered(ZKTeco device, int command) async {
    final Map<String, dynamic> response;
    try {
      response = await device.command(command);
    } catch (_) {
      return Uint8List(0);
    }
    if (response['status'] != true) return Uint8List(0);

    final raw = Uint8List.fromList(device.data);
    if (raw.length < 4) {
      await _release(device);
      return Uint8List(0);
    }

    final declared = ByteData.sublistView(
      raw,
      0,
      4,
    ).getUint32(0, Endian.little);
    if (declared <= 0) {
      await _release(device);
      return Uint8List(0);
    }

    // The reply opens with the byte count, then — on TCP, where the whole
    // exchange arrives in one read — the terminal's own framing around the
    // data: its magic number, a length and a packet header. Rather than walk
    // that framing, take the records from the end. The terminal said how many
    // bytes they are and they are the last thing in the buffer, so the trailing
    // `declared` bytes are them whatever sits in front.
    //
    // Those bytes already open with their own count, which is the same shape
    // the buffered read returns, so they are handed straight back. Wrapping
    // them in a second count was the first version of this and it left every
    // parser four bytes into the first record: 96 punches came back as scans by
    // user 3840 in the year 2000.
    if (raw.length >= declared + 4) {
      await _release(device);
      return raw.sublist(raw.length - declared);
    }

    // Genuinely split across replies.
    Uint8List? tail;
    try {
      tail = await Util.recData(device, first: false).timeout(_tailTimeout);
    } catch (_) {
      tail = null;
    }
    await _release(device);

    final body = Uint8List.fromList([...raw.sublist(4), ...?tail]);
    if (body.isEmpty) return Uint8List(0);

    final size = body.length < declared ? body.length : declared;
    return _sized(size, body.sublist(body.length - size));
  }

  /// Tells the terminal the table can be let go.
  ///
  /// Skipping it is what made consecutive reads unreliable: the unit keeps the
  /// prepared table open, and the next command's reply arrives behind the
  /// remains of the last one — so `readSizes` came back reporting zero users on
  /// a device that had just listed them.
  static Future<void> _release(ZKTeco device) async {
    try {
      await device.command(Util.CMD_FREE_DATA);
    } catch (_) {
      // The session ends with the read either way; a refused release is not
      // worth failing a table that already arrived.
    }
  }

  /// Re-attaches the count the parsers read back off the front.
  static Uint8List _sized(int size, Uint8List body) {
    final out = Uint8List(4 + body.length);
    ByteData.sublistView(out, 0, 4).setUint32(0, size, Endian.little);
    out.setRange(4, out.length, body);
    return out;
  }
}
