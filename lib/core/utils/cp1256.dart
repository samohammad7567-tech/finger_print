import 'dart:typed_data';

/// Windows-1256 (Arabic) decoding for strings that come off the terminal.
///
/// ZKTeco devices store names in the legacy Arabic codepage, not UTF-8. Read
/// as Latin-1 — which is what the protocol package does — "ابو خالد" arrives as
/// "ÇÈæ ÎÇáÏ". This maps those bytes back to real Arabic.
class Cp1256 {
  Cp1256._();

  /// Code points for bytes 0x80–0xFF. Bytes below 0x80 are ASCII already.
  static const _high =
      '€پ‚ƒ„…†‡ˆ‰ٹ‹Œچژڈ'
      'گ‘’“”•–—ک™ڑ›œ‌‍ں'
      ' ،¢£¤¥¦§¨©ھ«¬­®¯'
      '°±²³´µ¶·¸¹؛»¼½¾؟'
      'ہءآأؤإئابةتثجحخد'
      'ذرزسشصض×طظعغـفقك'
      'àلâمنهوçèéêëىيîï'
      'ًٌٍَôُِ÷ّùْûü‎‏ے';

  /// Decodes a null-terminated, space-padded field from a device record.
  static String decodeField(Uint8List bytes) {
    final end = bytes.indexOf(0);
    return decode(end == -1 ? bytes : bytes.sublist(0, end)).trim();
  }

  static String decode(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(
        byte < 0x80 ? String.fromCharCode(byte) : _high[byte - 0x80],
      );
    }
    return buffer.toString();
  }

  /// Encodes text back into Windows-1256 bytes for writing to the terminal.
  /// Characters the codepage cannot represent become '?', which is what the
  /// device's own keypad does with them.
  static List<int> encode(String value) {
    final bytes = <int>[];
    for (final rune in value.runes) {
      if (rune < 0x80) {
        bytes.add(rune);
        continue;
      }
      final index = _high.indexOf(String.fromCharCode(rune));
      bytes.add(index == -1 ? 0x3F : index + 0x80);
    }
    return bytes;
  }

  /// Windows-1256 bytes carried in a Dart string, one byte per code unit.
  ///
  /// `flutter_zkteco`'s `setUser` builds its packet from `String.codeUnits`, so
  /// an Arabic name handed to it directly would go out as UTF-16 and arrive as
  /// nonsense. Pre-encoding here makes those code units the exact bytes the
  /// device expects.
  static String encodeAsByteString(String value) =>
      String.fromCharCodes(encode(value));

  /// Repairs a string that was already decoded as Latin-1 when it was really
  /// Windows-1256. Characters outside Latin-1 are left alone, so calling this
  /// on text that is already correct is harmless.
  static String repairLatin1(String value) {
    if (value.isEmpty) return value;
    if (!value.codeUnits.any((c) => c >= 0x80 && c <= 0xFF)) return value;
    if (value.codeUnits.any((c) => c > 0xFF)) return value;
    return decode(Uint8List.fromList(value.codeUnits)).trim();
  }
}
