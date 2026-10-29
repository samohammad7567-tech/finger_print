import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';

/// A small tinted label: a figure, an id, a one-word qualifier.
///
/// Distinct from [AppStatusChip], which is bound to [AttendanceStatus] and
/// carries a dot. This is the generic one — "paid", "#14", "08:00", "manager" —
/// and it exists because ten files had written the same tinted box by hand,
/// each landing on a slightly different alpha.
class AppTintedPill extends StatelessWidget {
  const AppTintedPill({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppDimens.spaceSm,
      vertical: 3,
    ),
    this.radius = AppDimens.radius,
    this.tintAlpha = 0.15,
    this.fontWeight = FontWeight.w600,
    this.minWidth,
    this.textColor,
    this.fontFeatures,
  });

  final String label;

  /// Tints the fill and inks the text.
  final Color color;

  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double tintAlpha;
  final FontWeight fontWeight;

  /// Keeps a pill from shrinking as its contents change width — used where a
  /// number ticks up and down beside stepper buttons.
  final double? minWidth;

  /// Overrides the text ink when the label must fade independently of the
  /// fill, e.g. a zero value shown greyed inside a live pill.
  final Color? textColor;

  final List<FontFeature>? fontFeatures;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: minWidth == null
          ? null
          : BoxConstraints(minWidth: minWidth!),
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: tintAlpha),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        textAlign: minWidth == null ? null : TextAlign.center,
        // Built off the scale's smallest face rather than a bare [TextStyle],
        // so a pill inherits the product's family, tracking and line height
        // and only the size is the caller's business.
        style: AppTextStyles.micro.copyWith(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor ?? color,
          fontFeatures: fontFeatures,
        ),
      ),
    );
  }
}
