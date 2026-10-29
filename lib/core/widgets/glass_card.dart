import 'package:flutter/material.dart';
import '../style/theme/app_dimens.dart';
import '../style/theme/context_extension.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  /// Fills the card with a semantic colour instead of the default surface —
  /// used for the selected state of a tab or toggle. Flat by design.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? context.color.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: color == null ? context.color.border : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppDimens.cardPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
