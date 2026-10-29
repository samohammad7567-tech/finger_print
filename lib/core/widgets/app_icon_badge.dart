import 'package:flutter/material.dart';

import '../style/theme/context_extension.dart';

/// A square, rounded container holding a single icon.
///
/// The app marks almost everything this way — a dialog's warning, a stat
/// card's subject, a settings row, a nav item — and the only things that ever
/// changed between the copies were the box size and whether the colour was
/// the fill or the icon. Both are parameters here, so a size stays a number
/// in one place instead of a `Container` rebuilt from scratch.
class AppIconBadge extends StatelessWidget {
  /// Solid fill in [color], icon drawn in the foreground ink.
  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    required this.radius,
    this.iconSize,
    this.iconColor,
  }) : tintAlpha = null,
       borderAlpha = null;

  /// Fill tinted from [color] with the icon itself in [color] — the softer
  /// variant used on list rows and empty states.
  const AppIconBadge.tinted({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    required this.radius,
    this.iconSize,
    this.tintAlpha = 0.15,
    this.borderAlpha,
  }) : iconColor = null;

  final IconData icon;

  /// The badge's semantic colour: the fill in the default constructor, the
  /// icon and its tint in [AppIconBadge.tinted].
  final Color color;

  final double size;

  /// Corner rounding. Explicit rather than derived from [size]: the app's
  /// badges do not follow one ratio — a 48px tile is rounded to 16, a 40px one
  /// to 12 — and a computed default would quietly restyle half of them.
  final double radius;

  /// Icon glyph size. Defaults to half the box.
  final double? iconSize;

  /// Overrides the ink on the solid variant — rarely needed.
  final Color? iconColor;

  /// Non-null on the tinted variant: how much of [color] the fill carries.
  final double? tintAlpha;

  /// Outlines the tinted variant at this alpha of [color].
  final double? borderAlpha;

  @override
  Widget build(BuildContext context) {
    final tint = tintAlpha;
    final border = borderAlpha;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint == null ? color : color.withValues(alpha: tint),
        borderRadius: BorderRadius.circular(radius),
        border: border == null
            ? null
            : Border.all(color: color.withValues(alpha: border)),
      ),
      child: Icon(
        icon,
        size: iconSize ?? size / 2,
        color: tint != null
            ? color
            : (iconColor ?? context.color.primaryForeground),
      ),
    );
  }
}
