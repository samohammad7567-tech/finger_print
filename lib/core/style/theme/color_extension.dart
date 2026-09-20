import 'package:flutter/material.dart';

import '../colors/colors_dark.dart';
import '../colors/colors_light.dart';

/// The app's semantic colour set, exposed on every [BuildContext] as
/// `context.color`.
///
/// Widgets must never reach for [ColorsLight] / [ColorsDark] directly —
/// read the token here so light and dark stay in sync automatically.
@immutable
class MyColors extends ThemeExtension<MyColors> {
  const MyColors({
    required this.background,
    required this.backgroundSubtle,
    required this.card,
    required this.popover,
    required this.foreground,
    required this.cardForeground,
    required this.popoverForeground,
    required this.muted,
    required this.mutedForeground,
    required this.subtleForeground,
    required this.primary,
    required this.primaryForeground,
    required this.primaryHover,
    required this.secondary,
    required this.secondaryForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.success,
    required this.successForeground,
    required this.warning,
    required this.warningForeground,
    required this.info,
    required this.infoForeground,
    required this.warningSoft,
    required this.infoSoft,
    required this.border,
    required this.borderSoft,
    required this.input,
    required this.ring,
    required this.tint,
    required this.tintWarm,
    required this.sidebarBackground,
    required this.sidebarForeground,
    required this.sidebarIdleForeground,
    required this.sidebarDim,
    required this.sidebarGroupLabel,
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarActive,
    required this.sidebarActiveForeground,
    required this.sidebarHover,
    required this.sidebarBorder,
    required this.sidebarRing,
    required this.sidebarDestructive,
    required this.topbarBackground,
    required this.topbarForeground,
    required this.topbarBorder,
    required this.toolbarBackground,
    required this.toolbarForeground,
    required this.toolbarBorder,
    required this.statusbarBackground,
    required this.statusbarForeground,
    required this.statusbarDim,
    required this.shadowColor,
  });

  // Surfaces
  final Color background;
  final Color backgroundSubtle;
  final Color card;
  final Color popover;

  // Content
  final Color foreground;
  final Color cardForeground;
  final Color popoverForeground;
  final Color muted;
  final Color mutedForeground;
  final Color subtleForeground;

  // Brand
  final Color primary;
  final Color primaryForeground;
  final Color primaryHover;
  final Color secondary;
  final Color secondaryForeground;
  final Color accent;
  final Color accentForeground;

  // Semantic
  final Color destructive;
  final Color destructiveForeground;
  final Color success;
  final Color successForeground;
  final Color warning;
  final Color warningForeground;
  final Color info;
  final Color infoForeground;

  /// Attendance statuses the four semantic hues cannot separate alone.
  /// Each is the lighter step of its own family — see the palette classes.
  final Color warningSoft;
  final Color infoSoft;

  // Lines & focus
  final Color border;
  final Color borderSoft;
  final Color input;
  final Color ring;
  final Color tint;
  final Color tintWarm;

  // Sidebar
  final Color sidebarBackground;
  final Color sidebarForeground;
  final Color sidebarIdleForeground;
  final Color sidebarDim;
  final Color sidebarGroupLabel;
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarActive;
  final Color sidebarActiveForeground;
  final Color sidebarHover;
  final Color sidebarBorder;
  final Color sidebarRing;

  /// The rail's own destructive tone.
  ///
  /// The sidebar ground is the same deep teal in both themes, so the page's
  /// [destructive] — a maroon tuned for a light card — all but disappears on
  /// it. This is the lifted red, and it is the same colour in light and dark
  /// for the same reason the ground is.
  final Color sidebarDestructive;

  // Chrome
  final Color topbarBackground;
  final Color topbarForeground;
  final Color topbarBorder;
  final Color toolbarBackground;
  final Color toolbarForeground;
  final Color toolbarBorder;
  final Color statusbarBackground;
  final Color statusbarForeground;
  final Color statusbarDim;

  final Color shadowColor;

  @override
  MyColors copyWith({
    Color? background,
    Color? backgroundSubtle,
    Color? card,
    Color? popover,
    Color? foreground,
    Color? cardForeground,
    Color? popoverForeground,
    Color? muted,
    Color? mutedForeground,
    Color? subtleForeground,
    Color? primary,
    Color? primaryForeground,
    Color? primaryHover,
    Color? secondary,
    Color? secondaryForeground,
    Color? accent,
    Color? accentForeground,
    Color? destructive,
    Color? destructiveForeground,
    Color? success,
    Color? successForeground,
    Color? warning,
    Color? warningForeground,
    Color? info,
    Color? infoForeground,
    Color? warningSoft,
    Color? infoSoft,
    Color? border,
    Color? borderSoft,
    Color? input,
    Color? ring,
    Color? tint,
    Color? tintWarm,
    Color? sidebarBackground,
    Color? sidebarForeground,
    Color? sidebarIdleForeground,
    Color? sidebarDim,
    Color? sidebarGroupLabel,
    Color? sidebarPrimary,
    Color? sidebarPrimaryForeground,
    Color? sidebarActive,
    Color? sidebarActiveForeground,
    Color? sidebarHover,
    Color? sidebarBorder,
    Color? sidebarRing,
    Color? sidebarDestructive,
    Color? topbarBackground,
    Color? topbarForeground,
    Color? topbarBorder,
    Color? toolbarBackground,
    Color? toolbarForeground,
    Color? toolbarBorder,
    Color? statusbarBackground,
    Color? statusbarForeground,
    Color? statusbarDim,
    Color? shadowColor,
  }) {
    return MyColors(
      background: background ?? this.background,
      backgroundSubtle: backgroundSubtle ?? this.backgroundSubtle,
      card: card ?? this.card,
      popover: popover ?? this.popover,
      foreground: foreground ?? this.foreground,
      cardForeground: cardForeground ?? this.cardForeground,
      popoverForeground: popoverForeground ?? this.popoverForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      subtleForeground: subtleForeground ?? this.subtleForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      primaryHover: primaryHover ?? this.primaryHover,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      destructiveForeground:
          destructiveForeground ?? this.destructiveForeground,
      success: success ?? this.success,
      successForeground: successForeground ?? this.successForeground,
      warning: warning ?? this.warning,
      warningForeground: warningForeground ?? this.warningForeground,
      info: info ?? this.info,
      infoForeground: infoForeground ?? this.infoForeground,
      warningSoft: warningSoft ?? this.warningSoft,
      infoSoft: infoSoft ?? this.infoSoft,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      input: input ?? this.input,
      ring: ring ?? this.ring,
      tint: tint ?? this.tint,
      tintWarm: tintWarm ?? this.tintWarm,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarForeground: sidebarForeground ?? this.sidebarForeground,
      sidebarIdleForeground:
          sidebarIdleForeground ?? this.sidebarIdleForeground,
      sidebarDim: sidebarDim ?? this.sidebarDim,
      sidebarGroupLabel: sidebarGroupLabel ?? this.sidebarGroupLabel,
      sidebarPrimary: sidebarPrimary ?? this.sidebarPrimary,
      sidebarPrimaryForeground:
          sidebarPrimaryForeground ?? this.sidebarPrimaryForeground,
      sidebarActive: sidebarActive ?? this.sidebarActive,
      sidebarActiveForeground:
          sidebarActiveForeground ?? this.sidebarActiveForeground,
      sidebarHover: sidebarHover ?? this.sidebarHover,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      sidebarRing: sidebarRing ?? this.sidebarRing,
      sidebarDestructive: sidebarDestructive ?? this.sidebarDestructive,
      topbarBackground: topbarBackground ?? this.topbarBackground,
      topbarForeground: topbarForeground ?? this.topbarForeground,
      topbarBorder: topbarBorder ?? this.topbarBorder,
      toolbarBackground: toolbarBackground ?? this.toolbarBackground,
      toolbarForeground: toolbarForeground ?? this.toolbarForeground,
      toolbarBorder: toolbarBorder ?? this.toolbarBorder,
      statusbarBackground: statusbarBackground ?? this.statusbarBackground,
      statusbarForeground: statusbarForeground ?? this.statusbarForeground,
      statusbarDim: statusbarDim ?? this.statusbarDim,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  MyColors lerp(covariant ThemeExtension<MyColors>? other, double t) {
    if (other is! MyColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return MyColors(
      background: mix(background, other.background),
      backgroundSubtle: mix(backgroundSubtle, other.backgroundSubtle),
      card: mix(card, other.card),
      popover: mix(popover, other.popover),
      foreground: mix(foreground, other.foreground),
      cardForeground: mix(cardForeground, other.cardForeground),
      popoverForeground: mix(popoverForeground, other.popoverForeground),
      muted: mix(muted, other.muted),
      mutedForeground: mix(mutedForeground, other.mutedForeground),
      subtleForeground: mix(subtleForeground, other.subtleForeground),
      primary: mix(primary, other.primary),
      primaryForeground: mix(primaryForeground, other.primaryForeground),
      primaryHover: mix(primaryHover, other.primaryHover),
      secondary: mix(secondary, other.secondary),
      secondaryForeground: mix(secondaryForeground, other.secondaryForeground),
      accent: mix(accent, other.accent),
      accentForeground: mix(accentForeground, other.accentForeground),
      destructive: mix(destructive, other.destructive),
      destructiveForeground: mix(
        destructiveForeground,
        other.destructiveForeground,
      ),
      success: mix(success, other.success),
      successForeground: mix(successForeground, other.successForeground),
      warning: mix(warning, other.warning),
      warningForeground: mix(warningForeground, other.warningForeground),
      info: mix(info, other.info),
      infoForeground: mix(infoForeground, other.infoForeground),
      warningSoft: mix(warningSoft, other.warningSoft),
      infoSoft: mix(infoSoft, other.infoSoft),
      border: mix(border, other.border),
      borderSoft: mix(borderSoft, other.borderSoft),
      input: mix(input, other.input),
      ring: mix(ring, other.ring),
      tint: mix(tint, other.tint),
      tintWarm: mix(tintWarm, other.tintWarm),
      sidebarBackground: mix(sidebarBackground, other.sidebarBackground),
      sidebarForeground: mix(sidebarForeground, other.sidebarForeground),
      sidebarIdleForeground: mix(
        sidebarIdleForeground,
        other.sidebarIdleForeground,
      ),
      sidebarDim: mix(sidebarDim, other.sidebarDim),
      sidebarGroupLabel: mix(sidebarGroupLabel, other.sidebarGroupLabel),
      sidebarPrimary: mix(sidebarPrimary, other.sidebarPrimary),
      sidebarPrimaryForeground: mix(
        sidebarPrimaryForeground,
        other.sidebarPrimaryForeground,
      ),
      sidebarActive: mix(sidebarActive, other.sidebarActive),
      sidebarActiveForeground: mix(
        sidebarActiveForeground,
        other.sidebarActiveForeground,
      ),
      sidebarHover: mix(sidebarHover, other.sidebarHover),
      sidebarBorder: mix(sidebarBorder, other.sidebarBorder),
      sidebarRing: mix(sidebarRing, other.sidebarRing),
      sidebarDestructive: mix(sidebarDestructive, other.sidebarDestructive),
      topbarBackground: mix(topbarBackground, other.topbarBackground),
      topbarForeground: mix(topbarForeground, other.topbarForeground),
      topbarBorder: mix(topbarBorder, other.topbarBorder),
      toolbarBackground: mix(toolbarBackground, other.toolbarBackground),
      toolbarForeground: mix(toolbarForeground, other.toolbarForeground),
      toolbarBorder: mix(toolbarBorder, other.toolbarBorder),
      statusbarBackground: mix(statusbarBackground, other.statusbarBackground),
      statusbarForeground: mix(statusbarForeground, other.statusbarForeground),
      statusbarDim: mix(statusbarDim, other.statusbarDim),
      shadowColor: mix(shadowColor, other.shadowColor),
    );
  }

  static const MyColors light = MyColors(
    background: ColorsLight.background,
    backgroundSubtle: ColorsLight.backgroundSubtle,
    card: ColorsLight.card,
    popover: ColorsLight.popover,
    foreground: ColorsLight.foreground,
    cardForeground: ColorsLight.cardForeground,
    popoverForeground: ColorsLight.popoverForeground,
    muted: ColorsLight.muted,
    mutedForeground: ColorsLight.mutedForeground,
    subtleForeground: ColorsLight.subtleForeground,
    primary: ColorsLight.primary,
    primaryForeground: ColorsLight.primaryForeground,
    primaryHover: ColorsLight.primaryHover,
    secondary: ColorsLight.secondary,
    secondaryForeground: ColorsLight.secondaryForeground,
    accent: ColorsLight.accent,
    accentForeground: ColorsLight.accentForeground,
    destructive: ColorsLight.destructive,
    destructiveForeground: ColorsLight.destructiveForeground,
    success: ColorsLight.success,
    successForeground: ColorsLight.successForeground,
    warning: ColorsLight.warning,
    warningForeground: ColorsLight.warningForeground,
    info: ColorsLight.info,
    infoForeground: ColorsLight.infoForeground,
    warningSoft: ColorsLight.warningSoft,
    infoSoft: ColorsLight.infoSoft,
    border: ColorsLight.border,
    borderSoft: ColorsLight.borderSoft,
    input: ColorsLight.input,
    ring: ColorsLight.ring,
    tint: ColorsLight.tint,
    tintWarm: ColorsLight.tintWarm,
    sidebarBackground: ColorsLight.sidebarBackground,
    sidebarForeground: ColorsLight.sidebarForeground,
    sidebarIdleForeground: ColorsLight.sidebarIdleForeground,
    sidebarDim: ColorsLight.sidebarDim,
    sidebarGroupLabel: ColorsLight.sidebarGroupLabel,
    sidebarPrimary: ColorsLight.sidebarPrimary,
    sidebarPrimaryForeground: ColorsLight.sidebarPrimaryForeground,
    sidebarActive: ColorsLight.sidebarActive,
    sidebarActiveForeground: ColorsLight.sidebarActiveForeground,
    sidebarHover: ColorsLight.sidebarHover,
    sidebarBorder: ColorsLight.sidebarBorder,
    sidebarRing: ColorsLight.sidebarRing,
    sidebarDestructive: ColorsDark.destructive,
    topbarBackground: ColorsLight.topbarBackground,
    topbarForeground: ColorsLight.topbarForeground,
    topbarBorder: ColorsLight.topbarBorder,
    toolbarBackground: ColorsLight.toolbarBackground,
    toolbarForeground: ColorsLight.toolbarForeground,
    toolbarBorder: ColorsLight.toolbarBorder,
    statusbarBackground: ColorsLight.statusbarBackground,
    statusbarForeground: ColorsLight.statusbarForeground,
    statusbarDim: ColorsLight.statusbarDim,
    shadowColor: ColorsLight.shadowColor,
  );

  static const MyColors dark = MyColors(
    background: ColorsDark.background,
    backgroundSubtle: ColorsDark.backgroundSubtle,
    card: ColorsDark.card,
    popover: ColorsDark.popover,
    foreground: ColorsDark.foreground,
    cardForeground: ColorsDark.cardForeground,
    popoverForeground: ColorsDark.popoverForeground,
    muted: ColorsDark.muted,
    mutedForeground: ColorsDark.mutedForeground,
    subtleForeground: ColorsDark.subtleForeground,
    primary: ColorsDark.primary,
    primaryForeground: ColorsDark.primaryForeground,
    primaryHover: ColorsDark.primaryHover,
    secondary: ColorsDark.secondary,
    secondaryForeground: ColorsDark.secondaryForeground,
    accent: ColorsDark.accent,
    accentForeground: ColorsDark.accentForeground,
    destructive: ColorsDark.destructive,
    destructiveForeground: ColorsDark.destructiveForeground,
    success: ColorsDark.success,
    successForeground: ColorsDark.successForeground,
    warning: ColorsDark.warning,
    warningForeground: ColorsDark.warningForeground,
    info: ColorsDark.info,
    infoForeground: ColorsDark.infoForeground,
    warningSoft: ColorsDark.warningSoft,
    infoSoft: ColorsDark.infoSoft,
    border: ColorsDark.border,
    borderSoft: ColorsDark.borderSoft,
    input: ColorsDark.input,
    ring: ColorsDark.ring,
    tint: ColorsDark.tint,
    tintWarm: ColorsDark.tintWarm,
    sidebarBackground: ColorsDark.sidebarBackground,
    sidebarForeground: ColorsDark.sidebarForeground,
    sidebarIdleForeground: ColorsDark.sidebarIdleForeground,
    sidebarDim: ColorsDark.sidebarDim,
    sidebarGroupLabel: ColorsDark.sidebarGroupLabel,
    sidebarPrimary: ColorsDark.sidebarPrimary,
    sidebarPrimaryForeground: ColorsDark.sidebarPrimaryForeground,
    sidebarActive: ColorsDark.sidebarActive,
    sidebarActiveForeground: ColorsDark.sidebarActiveForeground,
    sidebarHover: ColorsDark.sidebarHover,
    sidebarBorder: ColorsDark.sidebarBorder,
    sidebarRing: ColorsDark.sidebarRing,
    sidebarDestructive: ColorsDark.destructive,
    topbarBackground: ColorsDark.topbarBackground,
    topbarForeground: ColorsDark.topbarForeground,
    topbarBorder: ColorsDark.topbarBorder,
    toolbarBackground: ColorsDark.toolbarBackground,
    toolbarForeground: ColorsDark.toolbarForeground,
    toolbarBorder: ColorsDark.toolbarBorder,
    statusbarBackground: ColorsDark.statusbarBackground,
    statusbarForeground: ColorsDark.statusbarForeground,
    statusbarDim: ColorsDark.statusbarDim,
    shadowColor: ColorsDark.shadowColor,
  );
}
