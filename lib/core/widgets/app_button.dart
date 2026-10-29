import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
import '../style/theme/context_extension.dart';

/// The app's primary action.
///
/// Sized and rounded from the design system rather than from touch: this is a
/// mouse-driven desktop product, so the button is
/// [AppDimens.controlHeightLg] tall and barely rounded, like every other
/// control beside it. It used to be 56px tall with a 16px radius — a phone
/// button, which is why it never sat right at the foot of a dense form.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.color,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  /// Spins inside the button and refuses the press, so a slow save cannot be
  /// fired twice and does not look ignored. The row keeps its height, so the
  /// form does not twitch when the spinner appears.
  final bool isLoading;

  /// Overrides the fill for buttons that carry a semantic other than the
  /// primary action — a destructive confirm, a success path. Flat: the design
  /// system's own brand gradient has two identical stops.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    final Color fill = disabled
        ? context.color.muted
        : (color ?? context.color.primary);
    final Color ink = disabled
        ? context.color.subtleForeground
        : context.color.primaryForeground;

    return Container(
      width: double.infinity,
      height: AppDimens.controlHeightLg,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimens.radius),
      ),
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        elevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        hoverColor: context.effects.hoverOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
        ),
        child: isLoading
            ? SizedBox(
                width: AppDimens.iconSm,
                height: AppDimens.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2, color: ink),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, color: ink, size: AppDimens.iconMd),
                    const SizedBox(width: AppDimens.spaceSm),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.controlSemiBold.copyWith(color: ink),
                  ),
                ],
              ),
      ),
    );
  }
}
