import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/admin_attendance_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_tinted_pill.dart';

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
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.spaceSm,
        AppDimens.pagePadding,
        AppDimens.pagePaddingBottom,
      ),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceXs),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          Container(
            width: AppDimens.spaceXs,
            height: 48,
            decoration: BoxDecoration(
              color: display.color,
              borderRadius: BorderRadius.circular(AppDimens.radiusXs),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.employee.fullName,
                  style: AppTextStyles.bodySemiBold.copyWith(
                    color: context.color.foreground,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Row(
                  children: [
                    _TimeChip(
                      icon: Icons.login,
                      time: rec?.checkInTime ?? '--:--',
                      color: context.color.success,
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    _TimeChip(
                      icon: Icons.logout,
                      time: rec?.checkOutTime ?? '--:--',
                      color: context.color.primary,
                    ),
                    if (rec?.isEarlyLeave == true ||
                        rec?.status == 'early_leave') ...[
                      const SizedBox(width: AppDimens.spaceXs),
                      Icon(
                        Icons.warning_amber,
                        size: AppDimens.iconSm,
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
              AppTintedPill(
                label: display.labelKey.tr(),
                color: display.color,
                tintAlpha: 0.12,
              ),
              if (perm != null) ...[
                const SizedBox(height: AppDimens.spaceXs),
                AppTintedPill(
                  label: perm.permissionType.tr(),
                  color: context.color.infoSoft,
                  fontSize: 10,
                  radius: AppDimens.radiusSm,
                  tintAlpha: 0.12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
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
        Icon(icon, size: AppDimens.iconXs, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        // Mono, so the in and out times of forty rows form two straight
        // columns instead of drifting with each glyph's width.
        Text(
          time,
          style: AppTextStyles.mono.copyWith(
            color: context.color.mutedForeground,
          ),
        ),
      ],
    );
  }
}
