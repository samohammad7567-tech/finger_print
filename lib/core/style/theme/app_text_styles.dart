import 'package:flutter/material.dart';

import '../fonts/font_family_helper.dart';
import '../fonts/font_weight_helper.dart';

/// The app's type scale.
///
/// Sizes are absolute (this is a desktop app) and colour is deliberately left
/// off — callers tint with `context.color.*` so one style serves both themes.
///
/// ## Three families, three jobs
///
/// * **IBM Plex Sans** sets the interface: everything from a 10px badge to a
///   13px table row.
/// * **Spectral** sets the serif ranks — [display], [title], [heading],
///   [subheading], [statValue] and [brand]. It appears only where the product
///   introduces itself or names a page, which is what keeps it meaning
///   something. A serif spent on body copy is a serif nobody notices.
/// * **IBM Plex Mono** sets values an operator compares character by
///   character: hashes, IDs, paths, sizes, timestamps.
///
/// All four faces — the three above plus the Arabic companion the fallback
/// chains point at — are bundled under `assets/fonts` and declared in
/// `pubspec.yaml`, so the styles below name them directly. They used to be
/// fetched at runtime through `google_fonts`, which meant the app was only
/// typeset correctly on a machine with internet: everywhere else it waited on
/// a request that could never succeed and then rendered in Segoe UI. A
/// declared weight also means Flutter uses the drawn face rather than
/// synthesising a bold from the regular, which is what the dense tables here
/// are built on.
///
/// ## Two rules that run through the scale
///
/// * **Tracking is optical.** Small type needs air between letters to stay
///   legible and large type needs it removed to stop looking loose, so
///   letter-spacing runs from `+1.2` on a 10px small-caps rail label down to
///   `-0.3` at 30px.
/// * **Numbers are tabular.** Everything that can hold a figure — counts,
///   sizes, dates, hashes — locks digits to one width via
///   [FontFeature.tabularFigures]. Without it a table of file sizes shivers
///   sideways as it refreshes, which is the difference between software that
///   looks engineered and software that looks assembled.
class AppTextStyles {
  const AppTextStyles._();

  static const String _family = FontFamilyHelper.plexSans;
  static const List<String> _fallback = FontFamilyHelper.uiFallback;
  static const String _serif = FontFamilyHelper.spectral;
  static const List<String> _serifFallback = FontFamilyHelper.displayFallback;
  static const String _mono = FontFamilyHelper.plexMono;
  static const List<String> _monoFallback = FontFamilyHelper.monoFallback;

  /// Digits of equal width — applied to every style that reports a number.
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  // ---------------------------------------------------------------------------
  // Small caps — the three tracked, uppercased ranks
  // ---------------------------------------------------------------------------

  /// 10px — badge and status-chip labels. Set as-is, not uppercased.
  static const TextStyle micro = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 10,
    fontWeight: FontWeightHelper.semiBold,
    letterSpacing: 0.5,
    height: 1.3,
    fontFeatures: _tabular,
  );

  /// 10px, heavily tracked — rail group headings and section headings.
  /// Callers uppercase the string.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 10,
    fontWeight: FontWeightHelper.semiBold,
    letterSpacing: 1.2,
    height: 1.3,
  );

  /// 10.5px — data-table column headers, uppercased by the caller.
  ///
  /// Half a pixel below the body rank and tracked wider than it, so the header
  /// band reads as a different *kind* of text rather than as a bolder row.
  static const TextStyle columnHeader = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 10.5,
    fontWeight: FontWeightHelper.semiBold,
    letterSpacing: 0.95,
    height: 1.3,
  );

  /// 11px — the label above a dashboard figure.
  static const TextStyle statLabel = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    fontWeight: FontWeightHelper.semiBold,
    letterSpacing: 0.88,
    height: 1.3,
  );

  /// 11.5px — form field labels, uppercased by the caller.
  static const TextStyle label = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11.5,
    fontWeight: FontWeightHelper.semiBold,
    letterSpacing: 0.8,
    height: 1.3,
  );

  // ---------------------------------------------------------------------------
  // Running text
  // ---------------------------------------------------------------------------

  /// 11.5px — the metadata rank: timestamps, counts, notes under a figure.
  static const TextStyle meta = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11.5,
    fontWeight: FontWeightHelper.regular,
    letterSpacing: 0.1,
    height: 1.4,
    fontFeatures: _tabular,
  );

  /// 12px — secondary/muted copy.
  static const TextStyle caption = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeightHelper.regular,
    letterSpacing: 0.1,
    height: 1.45,
    fontFeatures: _tabular,
  );

  static const TextStyle captionMedium = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeightHelper.medium,
    letterSpacing: 0.1,
    height: 1.45,
    fontFeatures: _tabular,
  );

  /// 12.5px — the control rank: buttons, rail destinations, tabs, filter
  /// chips. Half a pixel under body, which is enough for a screen of controls
  /// to sit quietly beneath the content they act on.
  static const TextStyle control = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 12.5,
    fontWeight: FontWeightHelper.regular,
    letterSpacing: 0.05,
    height: 1.35,
    fontFeatures: _tabular,
  );

  static const TextStyle controlSemiBold = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 12.5,
    fontWeight: FontWeightHelper.semiBold,
    letterSpacing: 0.05,
    height: 1.35,
    fontFeatures: _tabular,
  );

  /// 13px — the default size across the app, and every table row.
  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeightHelper.regular,
    letterSpacing: 0,
    height: 1.5,
    fontFeatures: _tabular,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeightHelper.medium,
    letterSpacing: 0,
    height: 1.5,
    fontFeatures: _tabular,
  );

  static const TextStyle bodySemiBold = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeightHelper.semiBold,
    letterSpacing: 0,
    height: 1.5,
    fontFeatures: _tabular,
  );

  /// 13px semibold — the header strip of a card or panel.
  ///
  /// Sans, not serif: a card header names a region of a page, and setting
  /// every panel on a dense screen in the display face would leave the serif
  /// meaning nothing when it reaches the page title.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeightHelper.semiBold,
    letterSpacing: 0,
    height: 1.4,
    fontFeatures: _tabular,
  );

  // ---------------------------------------------------------------------------
  // The serif ranks
  // ---------------------------------------------------------------------------

  /// Spectral 15px — the product name in the top bar and on the sign-in panel.
  static const TextStyle brand = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 15,
    fontWeight: FontWeightHelper.medium,
    letterSpacing: 0.3,
    height: 1.2,
  );

  /// Spectral 19px — the title of a standalone panel.
  static const TextStyle subheading = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 19,
    fontWeight: FontWeightHelper.medium,
    letterSpacing: 0,
    height: 1.25,
  );

  /// Spectral 20px — the page title in the page header.
  static const TextStyle heading = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 20,
    fontWeight: FontWeightHelper.medium,
    letterSpacing: -0.1,
    height: 1.2,
  );

  /// Spectral 23px — a screen that owns the window: sign-in, an empty vault,
  /// a permission wall.
  static const TextStyle title = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 23,
    fontWeight: FontWeightHelper.medium,
    letterSpacing: -0.2,
    height: 1.25,
  );

  /// Spectral 27px — a dashboard figure. The number leads; its label sits
  /// above it in [statLabel] and its note below in [meta].
  static const TextStyle statValue = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 27,
    fontWeight: FontWeightHelper.medium,
    letterSpacing: -0.3,
    height: 1.15,
    fontFeatures: _tabular,
  );

  /// Spectral 30px — the sign-in headline, and nothing else.
  static const TextStyle display = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 30,
    fontWeight: FontWeightHelper.medium,
    letterSpacing: -0.3,
    height: 1.25,
  );

  // ---------------------------------------------------------------------------
  // Monospace
  // ---------------------------------------------------------------------------

  /// 12px — hashes, checksums, IDs, paths, sizes.
  static const TextStyle mono = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _monoFallback,
    fontSize: 12,
    fontWeight: FontWeightHelper.regular,
    letterSpacing: 0,
    height: 1.45,
    fontFeatures: _tabular,
  );

  /// 11.5px — the mono metadata rank: timestamps in a row, the status bar.
  static const TextStyle monoMeta = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _monoFallback,
    fontSize: 11.5,
    fontWeight: FontWeightHelper.regular,
    letterSpacing: 0,
    height: 1.4,
    fontFeatures: _tabular,
  );

  /// 10px — the smallest mono rank: a file-extension tag, a keyboard hint.
  static const TextStyle monoMicro = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _monoFallback,
    fontSize: 10,
    fontWeight: FontWeightHelper.regular,
    letterSpacing: 0,
    height: 1.3,
    fontFeatures: _tabular,
  );
}
