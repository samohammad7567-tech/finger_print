import 'package:flutter/material.dart';

/// ColorsDark — the dark palette.
///
/// Dark is not the light scale inverted. Three things change:
///
/// * **Surfaces climb, they do not darken.** `background` drops just below the
///   `#002623` anchor so that anchor can serve as the first raised plane, and
///   every plane above it — subtle, card, popover — gets *lighter*. On a dark
///   canvas elevation is communicated by light, not by shadow.
/// * **Saturated colours lift and their foregrounds invert.** The light scale's
///   `success` at `#2C7355` is unreadable on near-black, so every semantic hue
///   moves to its tint and carries the deep teal as its own foreground.
/// * **The brand lifts rather than switching hue.** It would be easy to hand
///   the action role to the sand `#b9a779` once teal becomes the ground — it
///   is the highest-contrast anchor here. It is not done, because the gold
///   already owns *warning*, and a product whose primary button is the same
///   colour as its caution state teaches operators to ignore both. Teal stays
///   the brand in both themes; it simply gets lighter.
///
/// **The rail does not move.** It is `#002623` here exactly as it is in light,
/// which makes it the one surface that is identical across the two themes.
/// That is deliberate: the rail and the status bar frame the window on two
/// edges, and an operator switching theme mid-shift should find the frame of
/// the application unchanged. In dark it coincides with `backgroundSubtle`,
/// and the border between them carries the separation instead.
///
/// See `ColorsLight` for the anchor table and the reasoning behind the derived
/// values. Do not use these directly in widgets — read them through
/// `context.color` so the active theme decides.
class ColorsDark {
  const ColorsDark._();

  // Surfaces — each step up is a step lighter.
  static const Color background = Color(0xFF001A18);
  static const Color backgroundSubtle = Color(0xFF002623); // anchor
  static const Color card = Color(0xFF04302B);
  static const Color popover = Color(0xFF063A33);

  // Content — the cream anchor becomes the ink, which is the same pairing as
  // the light theme read the other way round.
  static const Color foreground = Color(0xFFEDEBE0); // anchor
  static const Color cardForeground = Color(0xFFEDEBE0);
  static const Color popoverForeground = Color(0xFFEDEBE0);
  static const Color muted = Color(0xFF0A3A34);
  static const Color mutedForeground = Color(0xFFBFCCC7);
  static const Color subtleForeground = Color(0xFF8FA29D);

  // Brand — the mid-teal anchor lifted until it carries the deep teal as text.
  static const Color primary = Color(0xFF5FA294);
  static const Color primaryForeground = Color(0xFF00201C);
  static const Color primaryHover = Color(0xFF7FBBAE);
  static const Color secondary = Color(0xFF0C3F39);
  static const Color secondaryForeground = Color(0xFFEDEBE0);
  static const Color accent = Color(0xFF10473F);
  static const Color accentForeground = Color(0xFFEDEBE0);

  // Semantic — tints of the light scale, each dark enough on its foreground to
  // carry 10px badge text. Success is pushed greener than the brand teal so a
  // status chip is never mistaken for an action.
  static const Color destructive = Color(0xFFD07E88);
  static const Color destructiveForeground = Color(0xFF260F14); // anchor
  static const Color success = Color(0xFF57BE94);
  static const Color successForeground = Color(0xFF002623);
  static const Color warning = Color(0xFFB9A779); // anchor
  static const Color warningForeground = Color(0xFF002623);
  static const Color info = Color(0xFF5FA294);
  static const Color infoForeground = Color(0xFF002623);

  // The light scale's two extra statuses, lifted for the dark ground and
  // holding the same relationship: each is the lighter step of its family, so
  // "early leave" still separates from [warning] and "on leave" from [info].
  static const Color warningSoft = Color(0xFFD8C9A0);
  static const Color infoSoft = Color(0xFF8FC9BD);

  // Lines & focus — the cream anchor at 16% and 8%.
  static const Color border = Color(0x29EDEBE0);
  static const Color borderSoft = Color(0x14EDEBE0);
  static const Color input = Color(0x29EDEBE0);
  static const Color ring = Color(0xFF5FA294);

  // Washes, matched to the lifted brand rather than to the light scale's.
  static const Color tint = Color(0x1F5FA294);
  static const Color tintWarm = Color(0x29B9A779);

  // Sidebar — identical to the light theme. See the class doc.
  static const Color sidebarBackground = Color(0xFF002623); // anchor
  static const Color sidebarForeground = Color(0xFFCFD9D5);
  static const Color sidebarIdleForeground = Color(0xFFA8B8B3);
  static const Color sidebarDim = Color(0xFF7E918C);
  static const Color sidebarGroupLabel = Color(0xFF5C6E6A);
  static const Color sidebarPrimary = Color(0xFFB9A779); // anchor
  static const Color sidebarPrimaryForeground = Color(0xFF002623);
  static const Color sidebarActive = Color(0xFF054239); // anchor
  static const Color sidebarActiveForeground = Color(0xFFEDEBE0); // anchor
  static const Color sidebarHover = Color(0x12EDEBE0);
  static const Color sidebarBorder = Color(0x1FEDEBE0);
  static const Color sidebarRing = Color(0xFFB9A779);

  // Chrome (top bar / toolbar / status bar)
  static const Color topbarBackground = Color(0xFF04302B);
  static const Color topbarForeground = Color(0xFFEDEBE0);
  static const Color topbarBorder = Color(0x29EDEBE0);
  static const Color toolbarBackground = Color(0xFF04302B);
  static const Color toolbarForeground = Color(0xFFEDEBE0);
  static const Color toolbarBorder = Color(0x29EDEBE0);
  static const Color statusbarBackground = Color(0xFF002623); // anchor
  static const Color statusbarForeground = Color(0xFF9FB0AB);
  static const Color statusbarDim = Color(0xFF7E918C);

  // Shadow
  static const Color shadowColor = Color(0xFF000000);
}
