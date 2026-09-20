import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/core/utils/cp1256.dart';

void main() {
  group('decode', () {
    test('reads the names this terminal actually stores', () {
      // The exact bytes read off the device for its three enrolled users.
      expect(
        Cp1256.decode(
          Uint8List.fromList([0xC7, 0xC8, 0xE6, 0x20, 0xCE, 0xC7, 0xE1, 0xCF]),
        ),
        'ابو خالد',
      );
      expect(
        Cp1256.decode(
          Uint8List.fromList([0xC7, 0xC8, 0xE6, 0x20, 0xDA, 0xE3, 0xD1, 0xE6]),
        ),
        'ابو عمرو',
      );
    });

    test('stops at the null terminator and trims padding', () {
      final field = Uint8List.fromList([
        0xC7,
        0xC8,
        0xE6,
        0x20,
        0x00,
        0x41,
        0x42,
      ]);
      expect(Cp1256.decodeField(field), 'ابو');
    });

    test('leaves ASCII alone', () {
      expect(
        Cp1256.decode(Uint8List.fromList('Guard 12'.codeUnits)),
        'Guard 12',
      );
    });
  });

  group('encode', () {
    test('round-trips Arabic', () {
      for (final name in [
        'ابو خالد',
        'ابو عمرو',
        'ابو يوسف',
        'اختبار البصمة',
      ]) {
        final bytes = Uint8List.fromList(Cp1256.encode(name));
        expect(Cp1256.decode(bytes), name, reason: 'round trip of "$name"');
      }
    });

    test('one byte per character, unlike UTF-16 code units', () {
      // This is the whole point: the device field is 24 *bytes*, and handing it
      // UTF-16 code units would both overflow and garble it.
      expect(Cp1256.encode('ابو خالد'), hasLength(8));
      expect(Cp1256.encode('Guard'), hasLength(5));
    });

    test('substitutes characters the codepage cannot hold', () {
      // '€' exists in cp1256, an emoji does not.
      expect(Cp1256.encode('\u{1F600}'), [0x3F]);
    });

    test('encodeAsByteString keeps every code unit inside one byte', () {
      final packed = Cp1256.encodeAsByteString('ابو يوسف');
      expect(packed.codeUnits.every((c) => c <= 0xFF), isTrue);
      expect(packed.codeUnits, Cp1256.encode('ابو يوسف'));
    });
  });

  group('repairLatin1', () {
    test('fixes a name that was decoded with the wrong codepage', () {
      // What the protocol package hands back before repair.
      expect(Cp1256.repairLatin1('ÇÈæ ÎÇáÏ'), 'ابو خالد');
    });

    test('leaves correct text untouched', () {
      expect(Cp1256.repairLatin1('ابو خالد'), 'ابو خالد');
      expect(Cp1256.repairLatin1('Guard'), 'Guard');
      expect(Cp1256.repairLatin1(''), '');
    });
  });
}
