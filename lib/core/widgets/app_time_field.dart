import 'package:flutter/material.dart';
import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
import '../style/theme/context_extension.dart';
import 'app_tinted_pill.dart';

/// One 'HH:mm' time, opened with the platform clock picker.
///
/// A picker rather than a text field wherever a time decides something: the
/// working hours say what counts as late and as overtime, and a corrected
/// punch says what somebody is paid for. A typo in either is expensive.
///
/// [value] may be null where a time can legitimately be missing — a day with
/// no departure scan — in which case [placeholder] is shown and [onCleared],
/// if given, offers a way back to empty.
class AppTimeField extends StatelessWidget {
  const AppTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon = Icons.schedule,
    this.placeholder = '--:--',
    this.onCleared,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final String placeholder;

  /// Offered only when a time is set, and only when clearing it is meaningful.
  final VoidCallback? onCleared;

  @override
  Widget build(BuildContext context) {
    final faded = context.color.subtleForeground;

    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radius),
      onTap: () => _pick(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        child: Row(
          children: [
            Icon(icon, size: AppDimens.iconMd, color: context.color.primary),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            AppTintedPill(
              label: value ?? placeholder,
              color: context.color.primary,
              // Faded while unset, so the placeholder reads as a prompt rather
              // than as a time somebody already chose.
              textColor: context.color.primary.withValues(
                alpha: value == null ? 0.45 : 1,
              ),
              fontSize: 13,
              radius: AppDimens.radius,
              tintAlpha: 0.12,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: AppDimens.spaceXs,
              ),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            if (onCleared != null && value != null)
              IconButton(
                onPressed: onCleared,
                icon: const Icon(
                  Icons.backspace_outlined,
                  size: AppDimens.iconSm,
                ),
                visualDensity: VisualDensity.compact,
                color: faded,
              )
            else
              Icon(Icons.edit, size: AppDimens.iconSm, color: faded),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final parts = (value ?? '').split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 0,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      ),
      // The 24-hour clock: these are shift times, and 5 versus 17 is the sort
      // of mistake that only shows up a payroll run later.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    onChanged(
      '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}',
    );
  }
}
