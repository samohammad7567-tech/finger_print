import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';

/// A tinted strip of prose that qualifies what is around it — a warning about
/// what an action also does, a reassurance about what it does not.
///
/// Ten places had grown their own version of this box. The variations that
/// mattered are kept as parameters: a leading icon, a border, and a second
/// line of detail under the first.
class AppNoteBanner extends StatelessWidget {
  const AppNoteBanner({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.title,
    this.iconSize = AppDimens.iconMd,
    this.fontSize = 11.5,
    this.fontWeight,
    this.padding = const EdgeInsets.all(AppDimens.spaceMd),
    this.radius = AppDimens.radius,
    this.tintAlpha = 0.1,
    this.borderAlpha,
    this.textAlign,
    this.textColor,
    this.trailing,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.onTap,
  });

  /// The body line. Inked in [textColor] when given, otherwise in [color].
  final String text;

  /// The semantic colour of the note — warning, success, info, destructive.
  final Color color;

  /// Shown before the text. Omitted banners read as a plain tinted note.
  final IconData? icon;

  /// A bolder line above [text], for notes that need a heading of their own.
  final String? title;

  final double iconSize;
  final double fontSize;

  /// Weight of the body line. Left normal unless the note carries the whole
  /// message on one line and has to hold its own against the list behind it.
  final FontWeight? fontWeight;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double tintAlpha;

  /// Draws an outline at this alpha of [color]. Null leaves the banner
  /// borderless.
  final double? borderAlpha;

  final TextAlign? textAlign;

  /// Overrides the prose ink where the note is tinted by semantic but the
  /// text should stay in the default foreground.
  final Color? textColor;

  /// How the icon and any [trailing] line up against the prose. Top-aligned
  /// by default, because most notes run to two or three lines.
  final CrossAxisAlignment crossAxisAlignment;

  /// Sits after the text, right-aligned — the "Review ›" affordance on a
  /// banner that is also a way in to the thing it warns about.
  final Widget? trailing;

  /// Makes the whole banner tappable — used where the note is also the way in
  /// to the thing it is warning about.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = borderAlpha;

    Widget content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: tintAlpha),
        borderRadius: BorderRadius.circular(radius),
        border: border == null
            ? null
            : Border.all(color: color.withValues(alpha: border)),
      ),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: AppDimens.spaceSm),
          ],
          Expanded(child: _body()),
          if (trailing != null) ...[
            const SizedBox(width: AppDimens.spaceSm),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }

  Widget _body() {
    final line = Text(
      text,
      textAlign: textAlign,
      style: AppTextStyles.meta.copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: textColor ?? color,
      ),
    );

    if (title == null) return line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title!,
          style: AppTextStyles.captionMedium.copyWith(
            fontSize: fontSize + 1.5,
            fontWeight: FontWeight.w600,
            color: textColor ?? color,
          ),
        ),
        const SizedBox(height: 2),
        line,
      ],
    );
  }
}
