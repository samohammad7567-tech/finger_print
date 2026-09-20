import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../data/models/holiday_model.dart';
import '../../../../core/style/theme/context_extension.dart';

/// One holiday in the list: what it is called, the dates it covers, how many
/// days that comes to, and whether it is paid.
class HolidayTile extends StatelessWidget {
  const HolidayTile({
    super.key,
    required this.holiday,
    required this.onEdit,
    required this.onDelete,
  });

  final HolidayModel holiday;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    // A one-day holiday reads as one date, not as a range to itself.
    final range = holiday.startDate == holiday.endDate
        ? holiday.startDate
        : '${holiday.startDate}  →  ${holiday.endDate}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.event_busy,
              size: 18,
              color: context.color.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$range  ·  '
                  '${LangKeys.holidayDays.tr(args: ['${holiday.dayCount}'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: faded),
                ),
                if (holiday.isPaid) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.color.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      LangKeys.holidayPaid.tr(),
                      style: TextStyle(
                        fontSize: 10,
                        color: context.color.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: LangKeys.holidayEdit.tr(),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: context.color.destructive,
            ),
            tooltip: LangKeys.adminDelete.tr(),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
