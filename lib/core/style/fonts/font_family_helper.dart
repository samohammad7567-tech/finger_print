/// The four families the product is set in.
///
/// All four are bundled in `assets/fonts` rather than taken from Windows.
/// The design is authored in IBM Plex, and a Segoe UI substitution changes the
/// texture of every dense table in the app — the point of a bundled face is
/// that the build looks the same on every machine it is deployed to.
///
/// The split of work between them:
///
/// * **IBM Plex Sans** carries the interface. It is a grotesque with open
///   apertures and unusually distinct figures, which is what a table of file
///   sizes and counts needs.
/// * **IBM Plex Sans Arabic** is its Arabic companion, drawn to the same
///   proportions, so a screen keeps its rhythm when the locale flips. Flutter
///   falls back to it automatically for Arabic glyphs.
/// * **IBM Plex Mono** sets hashes, checksums, IDs, paths and timestamps —
///   every value an operator has to compare character by character.
/// * **Spectral** is the serif, and it is used sparingly: the brand mark, the
///   sign-in headline, page titles and card titles. It is what makes the
///   product read as a records institution rather than a dashboard, and it
///   stops earning that the moment it is used for body text.
class FontFamilyHelper {
  const FontFamilyHelper._();

  /// Primary UI font — Latin.
  static const String plexSans = 'IBM Plex Sans';

  /// Arabic companion to [plexSans], resolved through [uiFallback].
  static const String plexSansArabic = 'IBM Plex Sans Arabic';

  /// Monospace font for hashes, checksums, IDs, paths and timestamps.
  static const String plexMono = 'IBM Plex Mono';

  /// The serif. Brand mark, display, page and card titles — nothing else.
  static const String spectral = 'Spectral';

  /// Fallbacks used when a glyph is missing from the primary family.
  ///
  /// The Arabic face leads: Plex Sans has no Arabic coverage, so an Arabic
  /// string falls straight through to it and never reaches a system font.
  static const List<String> uiFallback = <String>[
    plexSansArabic,
    'Segoe UI',
    'Tahoma',
  ];

  static const List<String> monoFallback = <String>[
    'Cascadia Code',
    'Consolas',
    'Courier New',
  ];

  /// Spectral covers no Arabic, so display text in Arabic resolves to the
  /// Arabic sans rather than to whatever serif the OS happens to hold.
  static const List<String> displayFallback = <String>[
    plexSansArabic,
    'Segoe UI',
  ];
}
