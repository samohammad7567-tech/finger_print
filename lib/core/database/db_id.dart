import 'dart:math';

/// Primary keys for locally created rows.
///
/// The API used to hand back server-generated GUIDs; with no server the client
/// mints them. Format matches a UUID v4 so existing ids stay comparable and
/// nothing downstream has to care where a row came from.
class DbId {
  DbId._();

  static final Random _random = Random.secure();

  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Version 4, variant 1 — the bits that make this a well-formed random UUID.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
