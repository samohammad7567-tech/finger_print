import 'package:flutter/material.dart';

import '../../data/models/holiday_model.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_tinted_pill.dart';

/// One end of a holiday's range, opened with the platform date picker.
///
/// Shaped to match [AppTimeField], which the shift form uses for the same job
/// with times, so the two forms read as one family.
class HolidayDateRow extends StatelessWidget {
  const HolidayDateRow({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.color.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            AppTintedPill(
              label: HolidayModel.isoDate(value),
              color: context.color.primary,
              fontSize: 14,
              radius: 10,
              tintAlpha: 0.12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
