import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/context_extension.dart';

/// One allowance in minutes, stepped rather than typed.
///
/// Deliberately not a text field. These are two numbers an admin sets once and
/// argues about later, and the values that come up in practice are small and
/// round — five minutes, a quarter of an hour, half of one. Stepping in fives
/// makes those the easy answers and makes "500" impossible, which a keyboard
/// would not.
///
/// Shaped to match [AppTimeField], which sits directly above it in the shift
/// form, so the four values the admin sets read as one group.
class ShiftGraceField extends StatelessWidget {
  const ShiftGraceField({
    super.key,
    required this.label,
    required this.minutes,
    required this.onChanged,
    this.icon = Icons.timelapse,
    this.step = 5,
    this.max = 120,
  });

  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;
  final IconData icon;
  final int step;

  /// An allowance longer than this stops being a grace period and starts being
  /// a different shift, which is what the admin should add instead.
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.color.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _step(
            context,
            icon: Icons.remove,
            onPressed: minutes <= 0 ? null : () => onChanged(minutes - step),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 74),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.color.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              LangKeys.shiftMinutes.tr(args: ['$minutes']),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.color.primary.withValues(
                  alpha: minutes == 0 ? 0.45 : 1,
                ),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _step(
            context,
            icon: Icons.add,
            onPressed: minutes >= max ? null : () => onChanged(minutes + step),
          ),
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
  }) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    visualDensity: VisualDensity.compact,
    color: Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: onPressed == null ? 0.2 : 0.6),
  );
}
