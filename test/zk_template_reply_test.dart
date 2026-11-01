import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:flutter_zkteco/src/util.dart';

import 'package:attendence/features/device/data/data_source/zk_template_reply.dart';

void main() {
  List<int> packet(int kind, List<int> payload) {
    final bytes = ByteData(8);
    bytes.setUint16(0, kind, Endian.little);
    return [...bytes.buffer.asUint8List(), ...payload];
  }

  Uint8List tcpFrame(List<int> commandPacket) =>
      Util.createTcpTop(commandPacket);

  List<int> sizePayload(int size) {
    final bytes = ByteData(4);
    bytes.setUint32(0, size, Endian.little);
    return bytes.buffer.asUint8List();
  }

  List<Uint8List> split(Uint8List data, int at) => [
    data.sublist(0, at),
    data.sublist(at),
  ];

  group('ZkTemplateReply (TCP)', () {
    test('an empty slot acknowledged with no payload is absent', () {
      final reply = ZkTemplateReply.parse(
        [tcpFrame(packet(Util.CMD_ACK_OK, const []))],
        tcp: true,
      );
      expect(reply, isFalse);
    });

    test('an inline template is present', () {
      final reply = ZkTemplateReply.parse(
        [tcpFrame(packet(Util.CMD_ACK_OK, List.filled(1024, 0x41)))],
        tcp: true,
      );
      expect(reply, isTrue);
    });

    test('a prepared reply is present from its announced size alone', () {
      final reply = ZkTemplateReply.parse(
        [tcpFrame(packet(Util.CMD_PREPARE_DATA, sizePayload(1030)))],
        tcp: true,
      );
      expect(reply, isTrue);
    });

    test('a prepared reply of zero bytes is absent', () {
      final reply = ZkTemplateReply.parse(
        [tcpFrame(packet(Util.CMD_PREPARE_DATA, sizePayload(0)))],
        tcp: true,
      );
      expect(reply, isFalse);
    });

    test('a reply split across socket reads still decodes', () {
      final frame = tcpFrame(packet(Util.CMD_PREPARE_DATA, sizePayload(1030)));
      final chunks = split(frame, 6);
      expect(
        ZkTemplateReply.parse(chunks, tcp: true),
        isTrue,
        reason: 'the first chunk cannot even hold the terminal top',
      );
    });

    test('the template tail is not required to decide presence', () {
      final frame = tcpFrame(packet(Util.CMD_PREPARE_DATA, sizePayload(1030)));
      expect(
        ZkTemplateReply.parse([frame.sublist(0, 20)], tcp: true),
        isTrue,
      );
    });

    test('an empty acknowledgement followed by the template is present', () {
      final chunks = [
        tcpFrame(packet(Util.CMD_ACK_OK, const [])),
        tcpFrame(packet(Util.CMD_PREPARE_DATA, sizePayload(1030))),
      ];
      expect(ZkTemplateReply.parse(chunks, tcp: true), isTrue);
    });

    test('a short data packet followed by a full one is present', () {
      final chunks = [
        tcpFrame(packet(Util.CMD_DATA, const [1, 2, 3])),
        tcpFrame(packet(Util.CMD_DATA, List.filled(1024, 0x41))),
      ];
      expect(ZkTemplateReply.parse(chunks, tcp: true), isTrue);
    });

    test('a lone complete short data packet is an empty slot', () {
      expect(
        ZkTemplateReply.parse(
          [tcpFrame(packet(Util.CMD_DATA, const [1, 2, 3]))],
          tcp: true,
        ),
        isFalse,
      );
    });

    test('a partial data packet is unknown', () {
      final frame = tcpFrame(packet(Util.CMD_DATA, List.filled(1024, 0x41)));
      expect(
        ZkTemplateReply.parse([frame.sublist(0, 20)], tcp: true),
        isNull,
      );
    });

    test('an error reply is an empty slot', () {
      final reply = ZkTemplateReply.parse(
        [tcpFrame(packet(Util.CMD_ACK_ERROR, const []))],
        tcp: true,
      );
      expect(reply, isFalse);
    });

    test('nothing received is unknown', () {
      expect(ZkTemplateReply.parse(const [], tcp: true), isNull);
    });

    test('a truncated top is unknown', () {
      expect(
        ZkTemplateReply.parse([
          Uint8List.fromList(const [1, 2, 3, 4]),
        ], tcp: true),
        isNull,
      );
    });
  });

  group('ZkTemplateReply settled', () {
    test('an error reply ends the exchange', () {
      expect(
        ZkTemplateReply.isSettled(
          [tcpFrame(packet(Util.CMD_ACK_ERROR, const []))],
          tcp: true,
        ),
        isTrue,
      );
    });

    test('an acknowledgement may still be followed by the template', () {
      expect(
        ZkTemplateReply.isSettled(
          [tcpFrame(packet(Util.CMD_ACK_OK, const []))],
          tcp: true,
        ),
        isFalse,
      );
    });

    test('a prepared reply is still arriving', () {
      expect(
        ZkTemplateReply.isSettled(
          [tcpFrame(packet(Util.CMD_PREPARE_DATA, sizePayload(1030)))],
          tcp: true,
        ),
        isFalse,
      );
    });

    test('nothing received is not settled', () {
      expect(ZkTemplateReply.isSettled(const [], tcp: true), isFalse);
    });
  });

  group('ZkTemplateReply (UDP)', () {
    test('an inline template is present', () {
      final reply = ZkTemplateReply.parse(
        [Uint8List.fromList(packet(Util.CMD_DATA, List.filled(1024, 0x41)))],
        tcp: false,
      );
      expect(reply, isTrue);
    });

    test('an empty acknowledgement is absent', () {
      final reply = ZkTemplateReply.parse(
        [Uint8List.fromList(packet(Util.CMD_ACK_OK, const []))],
        tcp: false,
      );
      expect(reply, isFalse);
    });

    test('a prepared reply reports the announced size', () {
      final reply = ZkTemplateReply.parse(
        [Uint8List.fromList(packet(Util.CMD_PREPARE_DATA, sizePayload(512)))],
        tcp: false,
      );
      expect(reply, isTrue);
    });
  });
}
