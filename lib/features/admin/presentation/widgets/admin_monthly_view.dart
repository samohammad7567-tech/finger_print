import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/admin_attendance_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class AdminMonthlyView extends StatelessWidget {
  const AdminMonthlyView({super.key, required this.state});

  final AdminAttendanceState state;

  @override
  Widget build(BuildContext context) {
    final summaries = state.filteredSummaries;
    if (summaries.isEmpty) {
      return Center(child: Text(LangKeys.noRecords.tr()));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: summaries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _MonthlySummaryCard(summary: summaries[index]),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({required this.summary});

  final EmployeeMonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.color.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    s.employee.fullName.isNotEmpty
                        ? s.employee.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: context.color.primaryForeground,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.employee.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      s.employee.department,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatBadge(
                label: LangKeys.presentDays.tr(),
                value: '${s.presentDays}',
                color: context.color.success,
              ),
              const SizedBox(width: 6),
              _StatBadge(
                label: LangKeys.lateTimes.tr(),
                value: '${s.lateTimes}',
                color: context.color.warning,
              ),
              const SizedBox(width: 6),
              _StatBadge(
                label: LangKeys.earlyLeave.tr(),
                value: '${s.earlyLeaveTimes}',
                color: context.color.warningSoft,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _StatBadge(
                label: LangKeys.absent.tr(),
                value: '${s.absentDays}',
                color: context.color.destructive,
              ),
              const SizedBox(width: 6),
              _StatBadge(
                label: LangKeys.permissionsDays.tr(),
                value: '${s.permissionDays}',
                color: context.color.infoSoft,
              ),
              const SizedBox(width: 6),
              _StatBadge(
                label: LangKeys.totalLateHours.tr(),
                value: s.lateHoursFormatted,
                color: context.color.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _StatBadge(
                label: LangKeys.reportOvertime.tr(),
                value: s.overtimeFormatted,
                color: context.color.success,
              ),
              // The last row holds one badge; the empty halves keep it the
              // same width as the badges above it.
              const SizedBox(width: 6),
              const Spacer(),
              const SizedBox(width: 6),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: color),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
