import 'package:flutter/material.dart';

import 'app_effects.dart';
import 'color_extension.dart';

/// The accessors the rest of the app reads the design system through.
///
/// Every file in `lib/core/style` tells widgets to reach for `context.color`
/// rather than [ColorsLight] / [ColorsDark] directly — this is the extension
/// that makes that true. Reading a token through the theme is what lets one
/// widget serve both brightnesses: the active [ThemeData] decides which
/// palette answers, so a screen never asks which theme it is in.
extension ThemeContextX on BuildContext {
  /// The semantic colour set for the active theme.
  ///
  /// Falls back to the light palette rather than throwing when the extension
  /// is absent — a widget pumped in a bare [MaterialApp] in a test should
  /// render, not crash.
  MyColors get color => Theme.of(this).extension<MyColors>() ?? MyColors.light;

  /// Shadows, gradients and overlays for the active theme.
  MyEffects get effects =>
      Theme.of(this).extension<MyEffects>() ?? MyEffects.light;

  /// The app's default body style — 13px IBM Plex Sans, already tinted with
  /// [MyColors.foreground]. `AppTheme` parks it on `displaySmall`.
  TextStyle get textStyle =>
      Theme.of(this).textTheme.displaySmall ?? const TextStyle();

  /// True when the dark palette is active.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
