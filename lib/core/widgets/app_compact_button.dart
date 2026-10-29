import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
import '../style/theme/context_extension.dart';

/// A short, filled action that sits in a toolbar row rather than across a form.
///
/// Distinct from [AppPrimaryButton], which is full width and
/// [AppDimens.controlHeightLg] tall for the foot of a form. This is the "Add",
/// "Import", "Fetch" button that lives beside a heading: intrinsic width,
/// [AppDimens.controlHeight], and it wraps rather than overflows when the
/// window narrows.
///
/// Two screens had grown their own copy of this out of a [GestureDetector] and
/// a [Container], each with its own radius and its own disabled colour.
class AppCompactButton extends StatelessWidget {
  const AppCompactButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
  });

  final String label;

  /// Null disables the button, which then takes the muted fill.
  final VoidCallback? onPressed;

  final IconData? icon;

  /// Spins in place of the icon and refuses the press.
  final bool isLoading;

  /// Overrides the fill for an action whose semantic is not the primary one.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final fill = disabled
        ? context.color.muted
        : (color ?? context.color.primary);
    final ink = disabled
        ? context.color.subtleForeground
        : context.color.primaryForeground;

    return SizedBox(
      height: AppDimens.controlHeight,
      child: FilledButton(
        onPressed: disabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          disabledBackgroundColor: context.color.muted,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radius),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isLoading)
              SizedBox(
                width: AppDimens.iconSm,
                height: AppDimens.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2, color: ink),
              )
            else if (icon != null)
              Icon(icon, size: AppDimens.iconMd, color: ink),
            if (isLoading || icon != null)
              const SizedBox(width: AppDimens.spaceXs),
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
