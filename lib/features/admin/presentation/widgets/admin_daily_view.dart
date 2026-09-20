import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/admin_attendance_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class AdminDailyView extends StatelessWidget {
  const AdminDailyView({super.key, required this.state});

  final AdminAttendanceState state;

  @override
  Widget build(BuildContext context) {
    final rows = state.dailyRows;
    if (rows.isEmpty) {
      return Center(child: Text(LangKeys.noRecordsToday.tr()));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _DailyRowCard(row: rows[index]),
    );
  }
}

class _DailyRowCard extends StatelessWidget {
  const _DailyRowCard({required this.row});

  final EmployeeDayRow row;

  @override
  Widget build(BuildContext context) {
    final rec = row.record;
    final perm = row.permission;
    final status = parseStatus(rec?.status);
    final display = getStatusDisplay(status, context.color);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: display.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.employee.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _TimeChip(
                      icon: Icons.login,
                      time: rec?.checkInTime ?? '--:--',
                      color: context.color.success,
                    ),
                    const SizedBox(width: 8),
                    _TimeChip(
                      icon: Icons.logout,
                      time: rec?.checkOutTime ?? '--:--',
                      color: context.color.primary,
                    ),
                    if (rec?.isEarlyLeave == true ||
                        rec?.status == 'early_leave') ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: context.color.warningSoft,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: display.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  display.labelKey.tr(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: display.color,
                  ),
                ),
              ),
              if (perm != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.color.infoSoft.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    perm.permissionType.tr(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: context.color.infoSoft,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.icon,
    required this.time,
    required this.color,
  });

  final IconData icon;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        Text(
          time,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
