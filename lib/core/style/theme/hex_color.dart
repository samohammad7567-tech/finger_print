import 'package:flutter/material.dart';

/// Parses the `#rrggbb` colours stored on categories and security levels.
///
/// These come from the seed data (and are user-editable on the Categories and
/// Security Levels screens), so they arrive as strings rather than tokens.
extension HexColor on String {
  /// Returns the parsed colour, or [fallback] when the string is malformed.
  Color toColor({Color fallback = const Color(0xFF64748B)}) {
    var hex = trim().replaceFirst('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;

    final value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : Color(value);
  }
}

extension ColorAlpha on Color {
  /// Matches the source app's `color + '14'` / `color + '40'` tints.
  Color get tint => withValues(alpha: 0.08);

  Color get subtleBorder => withValues(alpha: 0.25);
}
