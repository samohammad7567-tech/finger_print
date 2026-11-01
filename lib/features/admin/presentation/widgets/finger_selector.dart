import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/utils/enrollment_finger.dart';

/// Picks which of the terminal's ten finger slots the next scan belongs to.
///
/// A filled chip is the current selection; the tick marks a slot the terminal
/// already holds a template in.
class FingerSelector extends StatelessWidget {
  const FingerSelector({
    super.key,
    required this.selected,
    required this.enrolled,
    required this.onSelected,
    this.enabled = true,
  });

  final int selected;
  final Set<int> enrolled;
  final ValueChanged<int> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.spaceSm,
      runSpacing: AppDimens.spaceSm,
      children: [
        for (var finger = 0; finger < EnrollmentFinger.count; finger++)
          _FingerChip(
            label: fingerLabel(finger),
            selected: finger == selected,
            enrolled: enrolled.contains(finger),
            onTap: enabled ? () => onSelected(finger) : null,
          ),
      ],
    );
  }
}

class _FingerChip extends StatelessWidget {
  const _FingerChip({
    required this.label,
    required this.selected,
    required this.enrolled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enrolled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? context.color.primary : context.color.muted;
    final ink = selected
        ? context.color.primaryForeground
        : context.color.foreground;
    final mark = enrolled ? context.color.success : ink.withValues(alpha: 0.35);
    final radius = BorderRadius.circular(AppDimens.radius);

    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: Material(
        color: fill,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: enrolled
                    ? context.color.success
                    : (selected ? context.color.primary : context.color.border),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enrolled ? Icons.check_circle : Icons.fingerprint,
                  size: AppDimens.iconSm,
                  color: mark,
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  label,
                  style: AppTextStyles.micro.copyWith(
                    color: ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The localized name of a finger slot, in the firmware's own order.
String fingerLabel(int finger) => switch (finger) {
  EnrollmentFinger.rightThumb => LangKeys.fingerRightThumb.tr(),
  EnrollmentFinger.rightIndex => LangKeys.fingerRightIndex.tr(),
  EnrollmentFinger.rightMiddle => LangKeys.fingerRightMiddle.tr(),
  EnrollmentFinger.rightRing => LangKeys.fingerRightRing.tr(),
  EnrollmentFinger.rightLittle => LangKeys.fingerRightLittle.tr(),
  EnrollmentFinger.leftThumb => LangKeys.fingerLeftThumb.tr(),
  EnrollmentFinger.leftIndex => LangKeys.fingerLeftIndex.tr(),
  EnrollmentFinger.leftMiddle => LangKeys.fingerLeftMiddle.tr(),
  EnrollmentFinger.leftRing => LangKeys.fingerLeftRing.tr(),
  EnrollmentFinger.leftLittle => LangKeys.fingerLeftLittle.tr(),
  _ => '',
};
