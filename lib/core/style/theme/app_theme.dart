import 'package:flutter/material.dart';

import '../colors/colors_dark.dart';
import '../colors/colors_light.dart';
import 'app_dimens.dart';
import 'app_effects.dart';
import 'app_text_styles.dart';
import 'color_extension.dart';

/// Builds the light and dark [ThemeData] from the OmniVault design tokens.
///
/// `MyColors` is attached as a theme extension so widgets can read semantic
/// tokens through `context.color`; the Material [ColorScheme] is filled in as
/// well so built-in widgets (dialogs, menus, scrollbars) inherit the palette.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(
    brightness: Brightness.light,
    colors: MyColors.light,
    effects: MyEffects.light,
    scheme: const ColorScheme.light(
      primary: ColorsLight.primary,
      onPrimary: ColorsLight.primaryForeground,
      secondary: ColorsLight.secondary,
      onSecondary: ColorsLight.secondaryForeground,
      error: ColorsLight.destructive,
      onError: ColorsLight.destructiveForeground,
      surface: ColorsLight.card,
      onSurface: ColorsLight.foreground,
      outline: ColorsLight.border,
    ),
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    colors: MyColors.dark,
    effects: MyEffects.dark,
    scheme: const ColorScheme.dark(
      primary: ColorsDark.primary,
      onPrimary: ColorsDark.primaryForeground,
      secondary: ColorsDark.secondary,
      onSecondary: ColorsDark.secondaryForeground,
      error: ColorsDark.destructive,
      onError: ColorsDark.destructiveForeground,
      surface: ColorsDark.card,
      onSurface: ColorsDark.foreground,
      outline: ColorsDark.border,
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required MyColors colors,
    required MyEffects effects,
    required ColorScheme scheme,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radius),
      borderSide: BorderSide(color: colors.input),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,

      // Set at the theme root so a Material widget that was never given an
      // explicit style still lands in the product's own face rather than in
      // whatever Flutter's default resolves to on this machine.
      // Taken from the resolved body style rather than named directly: the
      // faces come from `google_fonts`, which registers them under its own
      // variant-qualified family names, so the literal "IBM Plex Sans" would
      // match nothing and fall through to a system font.
      fontFamily: AppTextStyles.body.fontFamily,
      fontFamilyFallback: AppTextStyles.body.fontFamilyFallback,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.border,
      shadowColor: colors.shadowColor,
      extensions: <ThemeExtension<dynamic>>[colors, effects],

      // `context.textStyle` resolves to displaySmall — the app's body style.
      textTheme: TextTheme(
        displaySmall: AppTextStyles.body.copyWith(color: colors.foreground),
        displayMedium: AppTextStyles.display.copyWith(color: colors.foreground),
        titleMedium: AppTextStyles.cardTitle.copyWith(color: colors.foreground),
        headlineSmall: AppTextStyles.heading.copyWith(color: colors.foreground),
        bodyMedium: AppTextStyles.body.copyWith(color: colors.foreground),
        labelSmall: AppTextStyles.caption.copyWith(
          color: colors.mutedForeground,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colors.border,
        space: 1,
        thickness: 1,
      ),

      iconTheme: IconThemeData(
        color: colors.mutedForeground,
        size: AppDimens.iconMd,
      ),

      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(color: colors.border),
        ),
      ),

      // Dialogs sit on plane 4 and are the only surface allowed a shadow this
      // large. Material's own elevation is switched off in favour of the
      // hand-tuned stack in [MyEffects], which a barrier this dark needs to
      // stay readable in both themes.
      dialogTheme: DialogThemeData(
        backgroundColor: colors.popover,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: effects.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          side: BorderSide(color: colors.border),
        ),
        titleTextStyle: AppTextStyles.cardTitle.copyWith(
          color: colors.popoverForeground,
        ),
        contentTextStyle: AppTextStyles.body.copyWith(
          color: colors.popoverForeground,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: colors.popover,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(color: colors.border),
        ),
        textStyle: AppTextStyles.body.copyWith(color: colors.popoverForeground),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.popover),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              side: BorderSide(color: colors.border),
            ),
          ),
        ),
      ),

      // A tooltip is a hint, not a statement: it inverts against the page so
      // it separates instantly, but stays small and quiet.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.foreground,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          boxShadow: effects.shadowLg,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        textStyle: AppTextStyles.caption.copyWith(color: colors.background),
        waitDuration: const Duration(milliseconds: 450),
        preferBelow: false,
      ),

      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        // An input is a *recess*, not a raised control: it takes the plane
        // below whatever it sits on. That reads correctly on both grounds the
        // app puts fields on — the recessed tone sinks into a card, and sinks
        // into the page canvas on sign-in — and it means a form never needs to
        // know which surface it landed on.
        fillColor: colors.backgroundSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        border: border,
        enabledBorder: border,
        hoverColor: Colors.transparent,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.ring, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.destructive),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.destructive, width: 1.5),
        ),
        hintStyle: AppTextStyles.body.copyWith(color: colors.subtleForeground),
        errorStyle: AppTextStyles.meta.copyWith(color: colors.destructive),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(colors.primaryForeground),
        side: BorderSide(color: colors.input),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        visualDensity: VisualDensity.compact,
      ),

      // The thumb thickens and darkens under the pointer instead of always
      // shouting — a document manager is mostly long scrolling lists, and a
      // permanently heavy scrollbar frames every one of them.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return colors.mutedForeground.withValues(alpha: 0.60);
          }
          if (states.contains(WidgetState.hovered)) {
            return colors.mutedForeground.withValues(alpha: 0.45);
          }
          return colors.mutedForeground.withValues(alpha: 0.26);
        }),
        thickness: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? 10 : 7,
        ),
        radius: const Radius.circular(AppDimens.radiusFull),
        crossAxisMargin: 2,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.muted,
        circularTrackColor: colors.muted,
        linearMinHeight: 5,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryForeground;
          }
          return colors.card;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.input;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.input;
        }),
      ),

      // No ripple. A ripple is a touch idiom — on a mouse-driven product it
      // arrives after the click has already been answered by hover and press,
      // so all it adds is a smear across dense rows.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: effects.hoverOverlay,
      focusColor: effects.focusRing,
      visualDensity: VisualDensity.compact,
    );
  }
}
