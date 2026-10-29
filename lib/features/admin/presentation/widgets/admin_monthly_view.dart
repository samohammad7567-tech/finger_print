import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
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
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.spaceSm,
        AppDimens.pagePadding,
        AppDimens.pagePaddingBottom,
      ),
      itemCount: summaries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
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
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                ),
                child: Center(
                  child: Text(
                    s.employee.fullName.isNotEmpty
                        ? s.employee.fullName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.controlSemiBold.copyWith(
                      color: context.color.primaryForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.employee.fullName,
                      style: AppTextStyles.bodySemiBold.copyWith(
                        color: context.color.foreground,
                      ),
                    ),
                    Text(
                      s.employee.department,
                      style: AppTextStyles.caption.copyWith(
                        color: context.color.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
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
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radius),
        ),
        child: Column(
          children: [
            Text(
              value,
              // Mono: these are the month's figures, read down a column of
              // employees, so they have to align on their digits.
              style: AppTextStyles.mono.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.monoMicro.copyWith(color: color),
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
