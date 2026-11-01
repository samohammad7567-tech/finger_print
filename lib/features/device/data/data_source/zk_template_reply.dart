import 'dart:typed_data';

// The package exposes no public constant for the protocol's frame types.
// ignore: implementation_imports
import 'package:flutter_zkteco/src/util.dart';

/// Decides whether a `CMD_USER_TEMP_RRQ` reply actually carries a template.
///
/// The package's `command` waits for the *first* socket event and then cancels
/// its stream subscription. On TCP a template reply is usually several packets
/// — a `CMD_PREPARE_DATA` announcing the size, then the template itself — and
/// the packets that arrive between one `command` call and the next are handed
/// to a broadcast stream with no listener, so they are dropped. The next
/// request then reads the tail of the previous reply as its own header, comes
/// back "rejected", and that slot is reported empty. Three enrolled fingers
/// came back as one because of exactly that.
///
/// This parser works on every chunk collected from the moment the request went
/// out, so it does not matter how the reply was split or how many frames it
/// spans. Only the presence of the template is needed, never its bytes, so the
/// announced size is enough.
class ZkTemplateReply {
  ZkTemplateReply._();

  /// Below this a payload is the terminal's own framing, not a template. Real
  /// ones run to hundreds of bytes.
  static const minTemplateBytes = 8;

  /// [chunks] are the raw socket reads captured while the request was in
  /// flight. [tcp] selects the framing: TCP prefixes each packet with the
  /// terminal's 8-byte top, UDP delivers the packet as-is.
  ///
  /// True means a template is there, false means the slot is empty, and null
  /// means the chunks do not contain a decodable reply and the caller must not
  /// conclude anything about the slot.
  static bool? parse(List<Uint8List> chunks, {required bool tcp}) {
    final frames = _frames(chunks, tcp: tcp);
    if (frames.isEmpty) return null;

    var sawAbsent = false;
    for (final frame in frames) {
      final present = _presence(frame);
      if (present == true) return true;
      if (present == false) sawAbsent = true;
    }
    return sawAbsent ? false : null;
  }

  /// True when the collected frames already form a reply that nothing can
  /// follow: an acknowledged error. A terminal says "no template" and stops,
  /// so an empty slot costs no quiet wait. Templates, announced or inline, are
  /// followed by more packets and are never settled early.
  static bool isSettled(List<Uint8List> chunks, {required bool tcp}) {
    final frames = _frames(chunks, tcp: tcp);
    if (frames.isEmpty) return false;

    final last = frames.last;
    return last.complete && last.kind == Util.CMD_ACK_ERROR;
  }

  /// Any packet saying "present" settles it; an empty acknowledgement or an
  /// error is only decisive when no packet says otherwise.
  static bool? _presence(_Frame frame) {
    if (frame.kind == Util.CMD_ACK_ERROR) return false;

    if (frame.kind == Util.CMD_PREPARE_DATA) {
      if (frame.payload.length < 4) return null;
      final size = ByteData.sublistView(
        frame.payload,
        0,
        4,
      ).getUint32(0, Endian.little);
      return size >= minTemplateBytes;
    }

    if (frame.kind == Util.CMD_DATA) {
      if (frame.payload.length >= minTemplateBytes) return true;
      // A complete short data packet is the terminal saying "nothing here". A
      // partial one is just a packet that has not finished arriving.
      return frame.complete ? false : null;
    }

    if (frame.kind == Util.CMD_ACK_OK) {
      return frame.payload.length >= minTemplateBytes;
    }

    return null;
  }

  /// Splits [chunks] into protocol packets, removing the TCP top when present.
  ///
  /// The final frame may be partial; it is still returned because a prepared
  /// reply's announced size is readable before its tail has arrived.
  static List<_Frame> _frames(List<Uint8List> chunks, {required bool tcp}) {
    if (chunks.isEmpty) return const [];

    if (!tcp) {
      return [
        for (final chunk in chunks)
          if (chunk.length >= 8)
            _Frame(
              kind: ByteData.sublistView(
                chunk,
                0,
                2,
              ).getUint16(0, Endian.little),
              payload: Uint8List.sublistView(chunk, 8),
              complete: true,
            ),
      ];
    }

    final builder = BytesBuilder(copy: true);
    for (final chunk in chunks) {
      builder.add(chunk);
    }
    final buffer = builder.toBytes();

    final frames = <_Frame>[];
    var offset = 0;
    while (offset + 8 <= buffer.length) {
      final length = ByteData.sublistView(
        buffer,
        offset + 4,
        offset + 8,
      ).getUint32(0, Endian.little);
      if (length < 8) break;

      final start = offset + 8;
      final end = offset + 8 + length;
      final complete = end <= buffer.length;
      final available = complete ? end : buffer.length;
      if (available - start < 8) break;

      final packet = Uint8List.sublistView(buffer, start, available);
      frames.add(
        _Frame(
          kind: ByteData.sublistView(
            packet,
            0,
            2,
          ).getUint16(0, Endian.little),
          payload: Uint8List.sublistView(packet, 8),
          complete: complete,
        ),
      );

      if (!complete) break;
      offset = end;
    }
    return frames;
  }
}

class _Frame {
  const _Frame({
    required this.kind,
    required this.payload,
    required this.complete,
  });

  final int kind;
  final Uint8List payload;
  final bool complete;
}
