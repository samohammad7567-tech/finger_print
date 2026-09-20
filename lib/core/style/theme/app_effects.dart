import 'package:flutter/material.dart';

/// The app's depth, brand and surface-effect tokens, exposed on every
/// [BuildContext] as `context.effects`.
///
/// Colour answers *what* a surface is; this answers *where it sits*.
///
/// ## Separation is drawn, not cast
///
/// A card here rests flat on the canvas and is separated from it by a hairline
/// border, not by a shadow. That is the whole difference between a records
/// tool and a dashboard: on a screen holding nine panels and a table, nine
/// soft shadows add nine grey haloes to a warm cream page and the density
/// starts to look like clutter. A 1px rule costs nothing and reads at any
/// zoom.
///
/// So [shadowSm] and [shadowMd] are deliberately **empty**. They are kept as
/// tokens rather than deleted because the plane vocabulary is what stops a
/// widget hand-rolling its own [BoxShadow] — a card asks for plane 1 and gets
/// nothing, which is the correct answer.
///
/// Shadow is reserved for the two planes that genuinely float above the page
/// and must be read as detached from it:
///
/// * **Plane 3** ([shadowLg]) — popovers, the notification panel, toasts.
/// * **Plane 4** ([shadowXl]) — dialogs, the only shadow allowed to be
///   obvious, because a modal that does not visibly sit above the page is a
///   modal the operator will try to click behind.
///
/// Light and dark need genuinely different shadows, not the same one at a
/// different alpha: light casts a soft teal shade drawn from the palette's
/// deepest anchor, dark deepens toward black because a tinted shadow on a dark
/// surface only ever looks like fog.
///
/// ## Gradients are flat by choice
///
/// The gradient tokens survive for the same reason the empty shadows do —
/// callers ask for [sidebarGradient] rather than picking a colour — but the
/// rail, the page header and the active destination are all single flat fills
/// in this design. A vertical fall down a 236px rail is a decoration that
/// competes with the one thing the rail has to communicate: which destination
/// is active.
///
@immutable
class MyEffects extends ThemeExtension<MyEffects> {
  const MyEffects({
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.shadowXl,
    required this.brandGradient,
    required this.sidebarGradient,
    required this.headerGradient,
    required this.railHighlight,
    required this.hoverOverlay,
    required this.pressOverlay,
    required this.focusRing,
    required this.topHighlight,
    required this.scrim,
  });

  /// Plane 1 — a resting card or panel. Present, never announced.
  final List<BoxShadow> shadowSm;

  /// Plane 2 — a hovered card, a raised primary button.
  final List<BoxShadow> shadowMd;

  /// Plane 3 — dropdowns, popovers, the notification panel.
  final List<BoxShadow> shadowLg;

  /// Plane 4 — dialogs and the sign-in card. The only shadow allowed to be
  /// obvious, because it is the only surface that owns the whole window.
  final List<BoxShadow> shadowXl;

  /// The brand mark and primary-action wash.
  final LinearGradient brandGradient;

  /// The vertical fall of the navigation rail — top-lit, so a 900px column
  /// does not read as one dead slab of colour.
  final LinearGradient sidebarGradient;

  /// The barely-there wash behind page headers, separating chrome from content
  /// without needing a second border.
  final LinearGradient headerGradient;

  /// The tint painted behind the active navigation item.
  final LinearGradient railHighlight;

  /// State overlays, painted *over* a surface rather than replacing its colour,
  /// so one value works on a card, a row and a chip alike.
  final Color hoverOverlay;
  final Color pressOverlay;

  /// The soft halo outside a focused input — keyboard operators should not
  /// have to hunt for a one-pixel border change.
  final Color focusRing;

  /// A one-pixel line of light along the top edge of a raised surface.
  ///
  /// Real objects catch the light where they turn away from the viewer. This
  /// is that catch, and it is why a toolbar sitting on a page can look milled
  /// rather than drawn.
  final Color topHighlight;

  /// Behind modals.
  final Color scrim;

  @override
  MyEffects copyWith({
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
    List<BoxShadow>? shadowXl,
    LinearGradient? brandGradient,
    LinearGradient? sidebarGradient,
    LinearGradient? headerGradient,
    LinearGradient? railHighlight,
    Color? hoverOverlay,
    Color? pressOverlay,
    Color? focusRing,
    Color? topHighlight,
    Color? scrim,
  }) {
    return MyEffects(
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
      shadowXl: shadowXl ?? this.shadowXl,
      brandGradient: brandGradient ?? this.brandGradient,
      sidebarGradient: sidebarGradient ?? this.sidebarGradient,
      headerGradient: headerGradient ?? this.headerGradient,
      railHighlight: railHighlight ?? this.railHighlight,
      hoverOverlay: hoverOverlay ?? this.hoverOverlay,
      pressOverlay: pressOverlay ?? this.pressOverlay,
      focusRing: focusRing ?? this.focusRing,
      topHighlight: topHighlight ?? this.topHighlight,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  MyEffects lerp(covariant ThemeExtension<MyEffects>? other, double t) {
    if (other is! MyEffects) return this;
    List<BoxShadow> shade(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t)!;
    LinearGradient grad(LinearGradient a, LinearGradient b) =>
        LinearGradient.lerp(a, b, t)!;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return MyEffects(
      shadowSm: shade(shadowSm, other.shadowSm),
      shadowMd: shade(shadowMd, other.shadowMd),
      shadowLg: shade(shadowLg, other.shadowLg),
      shadowXl: shade(shadowXl, other.shadowXl),
      brandGradient: grad(brandGradient, other.brandGradient),
      sidebarGradient: grad(sidebarGradient, other.sidebarGradient),
      headerGradient: grad(headerGradient, other.headerGradient),
      railHighlight: grad(railHighlight, other.railHighlight),
      hoverOverlay: mix(hoverOverlay, other.hoverOverlay),
      pressOverlay: mix(pressOverlay, other.pressOverlay),
      focusRing: mix(focusRing, other.focusRing),
      topHighlight: mix(topHighlight, other.topHighlight),
      scrim: mix(scrim, other.scrim),
    );
  }

  // ── Light ────────────────────────────────────────────────────────────────
  // Shade is cast in the deepest teal anchor, never neutral grey. A grey
  // shadow falling on a cream page is the fastest way to make a warm palette
  // look dirty; a teal one reads as the same light source that lit the rail.
  static const Color _ink = Color(0xFF002623);
  static const Color _brand = Color(0xFF054239);

  static final MyEffects light = MyEffects(
    // Planes 1 and 2 are drawn, not cast. See the class doc.
    shadowSm: const <BoxShadow>[],
    shadowMd: const <BoxShadow>[],
    shadowLg: <BoxShadow>[
      BoxShadow(
        color: _ink.withValues(alpha: 0.10),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: _ink.withValues(alpha: 0.18),
        blurRadius: 30,
        spreadRadius: -6,
        offset: const Offset(0, 10),
      ),
    ],
    shadowXl: <BoxShadow>[
      BoxShadow(
        color: _ink.withValues(alpha: 0.14),
        blurRadius: 16,
        spreadRadius: -4,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: _ink.withValues(alpha: 0.35),
        blurRadius: 50,
        spreadRadius: -10,
        offset: const Offset(0, 18),
      ),
    ],
    // Flat: both stops are the same value. See the class doc.
    brandGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF054239), Color(0xFF054239)],
    ),
    sidebarGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF002623), Color(0xFF002623)],
    ),
    headerGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFFFAF9F4), Color(0xFFFAF9F4)],
    ),
    // The active destination is a solid brand-teal fill carrying a sand rule
    // on its leading edge — the rule is the mark, and the fill is what makes
    // the row it sits on read as selected rather than merely hovered.
    railHighlight: const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[Color(0xFF054239), Color(0xFF054239)],
    ),
    hoverOverlay: _ink.withValues(alpha: 0.045),
    pressOverlay: _ink.withValues(alpha: 0.09),
    focusRing: _brand.withValues(alpha: 0.22),
    topHighlight: const Color(0xFFFFFFFF).withValues(alpha: 0.85),
    scrim: const Color(0xFF001A18).withValues(alpha: 0.55),
  );

  // ── Dark ─────────────────────────────────────────────────────────────────
  static const Color _black = Color(0xFF000000);
  static const Color _brandDark = Color(0xFF5FA294);

  static final MyEffects dark = MyEffects(
    shadowSm: const <BoxShadow>[],
    shadowMd: const <BoxShadow>[],
    shadowLg: <BoxShadow>[
      BoxShadow(
        color: _black.withValues(alpha: 0.30),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: _black.withValues(alpha: 0.42),
        blurRadius: 34,
        spreadRadius: -6,
        offset: const Offset(0, 12),
      ),
    ],
    shadowXl: <BoxShadow>[
      BoxShadow(
        color: _black.withValues(alpha: 0.38),
        blurRadius: 18,
        spreadRadius: -4,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: _black.withValues(alpha: 0.55),
        blurRadius: 56,
        spreadRadius: -10,
        offset: const Offset(0, 20),
      ),
    ],
    brandGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF5FA294), Color(0xFF5FA294)],
    ),
    // The rail does not move between themes — it is `#002623` in both.
    sidebarGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF002623), Color(0xFF002623)],
    ),
    headerGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF04302B), Color(0xFF04302B)],
    ),
    railHighlight: const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[Color(0xFF054239), Color(0xFF054239)],
    ),
    hoverOverlay: const Color(0xFFEDEBE0).withValues(alpha: 0.06),
    pressOverlay: const Color(0xFFEDEBE0).withValues(alpha: 0.10),
    focusRing: _brandDark.withValues(alpha: 0.30),
    topHighlight: const Color(0xFFFFFFFF).withValues(alpha: 0.06),
    scrim: _black.withValues(alpha: 0.66),
  );
}
