import 'package:flutter/material.dart';

/// ColorsLight — the light palette.
///
/// ## The anchors
///
/// Ten colours define the product. Everything else in this file is derived
/// from them, and nothing is invented outside their hue families:
///
/// | Anchor    | Role it earns                                     |
/// |-----------|---------------------------------------------------|
/// | `#002623` | Deepest teal — the rail, the status bar            |
/// | `#054239` | Brand teal — primary actions, focus, links         |
/// | `#428177` | Mid teal — the decorative/tint teal                |
/// | `#988561` | Gold — the warning family                          |
/// | `#b9a779` | Sand — the active mark on dark ground              |
/// | `#edebe0` | Cream — the canvas, and text on dark fills         |
/// | `#3d3a3b` | Warm grey — secondary ink, neutral dividers        |
/// | `#260f14` | Maroon-black — text on light destructive fills     |
/// | `#4a151e` | Deep burgundy — pressed destructive                |
/// | `#6b1f2a` | Burgundy — the destructive family                  |
///
/// ## Body ink is warm, not teal
///
/// The canvas is cream, and the ink that sits on it is `#241E1F` — a warm
/// near-black, not the deep teal anchor. Teal ink on a cream page tints the
/// whole screen toward the brand and leaves nothing for `primary` to say; a
/// warm black lets the teal mean "action" wherever it appears. The teal
/// anchors keep the chrome — rail, status bar, brand mark — where they are
/// read as surfaces rather than as text.
///
/// ## Three rules that hold the scale together
///
/// * **The canvas is warm.** Cream ground against warm-black text is the whole
///   identity of the product — an archive, not a dashboard.
/// * **One action colour.** `primary` is the only teal fill in the chrome, so
///   when it appears it always means "this is the action".
/// * **Semantics separate by hue, not by lightness.** Teal, green, gold and
///   burgundy are four different families, which is what lets a status be read
///   at 10px without reading its label.
///
/// ## Lines are alpha, not opaque
///
/// [border] and [borderSoft] are the ink at low alpha rather than baked
/// mixtures of ink and card. A rule drawn on the cream canvas, on the near
/// white card and on the recessed toolbar is then the same *relationship* on
/// all three, instead of three values that only match on one of them.
///
/// Do not use these directly in widgets — read them through `context.color` so
/// the active theme decides. See `MyColors` in `../theme/color_extension.dart`.
class ColorsLight {
  const ColorsLight._();

  // Surfaces — the cream canvas recedes, the card comes forward by getting
  // *lighter*. Cards tinted the same as the page have no depth to give away.
  static const Color background = Color(0xFFEDEBE0); // anchor
  static const Color backgroundSubtle = Color(0xFFE3E0D0);
  static const Color card = Color(0xFFFAF9F4);
  static const Color popover = Color(0xFFFDFCF8);

  // Content — three ranks of ink, and nothing between them. Body, supporting,
  // and the metadata rank that labels and timestamps live in.
  static const Color foreground = Color(0xFF241E1F);
  static const Color cardForeground = Color(0xFF241E1F);
  static const Color popoverForeground = Color(0xFF241E1F);
  static const Color muted = Color(0xFFE7E3D4);
  static const Color mutedForeground = Color(0xFF3D3A3B); // anchor
  static const Color subtleForeground = Color(0xFF6E6668);

  // Brand
  static const Color primary = Color(0xFF054239); // anchor
  static const Color primaryForeground = Color(0xFFFAF9F4);
  static const Color primaryHover = Color(0xFF002623); // anchor
  static const Color secondary = Color(0xFFDEE7E3);
  static const Color secondaryForeground = Color(0xFF054239);
  static const Color accent = Color(0xFFD1DFDB);
  static const Color accentForeground = Color(0xFF054239);

  // Semantic
  static const Color destructive = Color(0xFF6B1F2A); // anchor
  static const Color destructiveForeground = Color(0xFFFAF9F4);
  static const Color success = Color(0xFF2C7355);
  static const Color successForeground = Color(0xFFFAF9F4);
  static const Color warning = Color(0xFF75643C);
  static const Color warningForeground = Color(0xFFFAF9F4);
  static const Color info = Color(0xFF054239);
  static const Color infoForeground = Color(0xFFFAF9F4);

  // Attendance statuses that the four semantic hues cannot separate on their
  // own. A month grid puts six of them in one row, so "late" and "early leave"
  // must not resolve to the same gold, and "on leave" must not resolve to the
  // same teal as a primary figure. Both take the lighter step of their own
  // family — the gold anchor above [warning], the mid teal above [primary] —
  // so the pair always reads as one family separated by weight.
  static const Color warningSoft = Color(0xFF988561); // anchor
  static const Color infoSoft = Color(0xFF428177); // anchor

  // Lines & focus — the warm-grey anchor at 20% and 10%.
  static const Color border = Color(0x333D3A3B);
  static const Color borderSoft = Color(0x1A3D3A3B);
  static const Color input = Color(0x333D3A3B);
  static const Color ring = Color(0xFF054239);

  // Washes. [tint] backs a selected row or an active filter; [tintWarm] backs
  // an avatar or a gold-family fill. Both are alpha, so they read the same on
  // the card and on the canvas.
  static const Color tint = Color(0x12054239);
  static const Color tintWarm = Color(0x29988561);

  // Sidebar — deep teal in both themes, so the window is framed by the same
  // colour whichever theme is on. Four ranks of ink live on it: the active
  // label, the idle label, the collapse control, and the group headings.
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
  static const Color topbarBackground = Color(0xFFFAF9F4);
  static const Color topbarForeground = Color(0xFF241E1F);
  static const Color topbarBorder = Color(0x333D3A3B);
  static const Color toolbarBackground = Color(0xFFFAF9F4);
  static const Color toolbarForeground = Color(0xFF241E1F);
  static const Color toolbarBorder = Color(0x333D3A3B);
  static const Color statusbarBackground = Color(0xFF002623); // anchor
  static const Color statusbarForeground = Color(0xFF9FB0AB);
  static const Color statusbarDim = Color(0xFF7E918C);

  // Shadow
  static const Color shadowColor = Color(0xFF002623);
}
