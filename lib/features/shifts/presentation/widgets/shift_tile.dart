import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/work_schedule.dart';
import '../../data/models/shift_model.dart';
import '../../../../core/style/theme/context_extension.dart';

/// One shift in the list: its hours, the two lines it forgives, how many
/// people are on it, and the two things an admin can do to it.
class ShiftTile extends StatelessWidget {
  const ShiftTile({
    super.key,
    required this.shift,
    required this.companyDefault,
    required this.onEdit,
    required this.onDelete,
  });

  final ShiftModel shift;

  /// Supplies the overtime window this shift inherits, so the tile can show
  /// the whole day the shift actually means rather than half of it.
  final WorkSchedule companyDefault;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    final schedule = shift.scheduleFrom(companyDefault);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.access_time,
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
                  shift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shift.hours}  ·  '
                  '${LangKeys.shiftInUse.tr(args: ['${shift.inUse}'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: faded),
                ),
                const SizedBox(height: 4),
                // The allowances as the times they actually come to. Minutes
                // are what the admin sets, but a clock time is what anybody
                // arguing about a day needs to see.
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(
                      context,
                      LangKeys.shiftOnTimeUntil.tr(
                        args: [_clock(schedule.latestOnTimeArrivalMinutes)],
                      ),
                      context.color.warningSoft,
                    ),
                    _chip(
                      context,
                      LangKeys.shiftLeaveFrom.tr(
                        args: [
                          _clock(
                            schedule.workEndMinutes -
                                shift.earlyOutGraceMinutes,
                          ),
                        ],
                      ),
                      context.color.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: LangKeys.shiftEdit.tr(),
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

  static Widget _chip(BuildContext context, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static String _clock(int minutes) {
    final safe = minutes < 0 ? 0 : minutes;
    final hours = (safe ~/ 60).toString().padLeft(2, '0');
    final rest = (safe % 60).toString().padLeft(2, '0');
    return '$hours:$rest';
  }
}
