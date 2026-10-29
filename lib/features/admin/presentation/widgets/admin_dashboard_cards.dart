import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_icon_badge.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/admin_dashboard_cubit.dart';

/// Today's attendance rate as a bar and a figure.
///
/// Hidden entirely when nobody is on file: a rate out of zero people is not
/// 0%, it is undefined, and showing 0% reads as a disaster rather than an
/// empty install.
class AdminAttendanceRateCard extends StatelessWidget {
  const AdminAttendanceRateCard({super.key, required this.state});

  final AdminDashboardState state;

  @override
  Widget build(BuildContext context) {
    if (state.totalEmployees == 0) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            LangKeys.adminAttendanceRateToday.tr(),
            style: AppTextStyles.statLabel.copyWith(
              color: context.color.mutedForeground,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusXs),
                  child: LinearProgressIndicator(
                    value: state.attendanceRate / 100,
                    minHeight: 8,
                    backgroundColor: context.color.muted,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.color.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Text(
                '${state.attendanceRate}%',
                style: AppTextStyles.subheading.copyWith(
                  color: context.color.foreground,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The way through to the day/month attendance tables.
class AdminAttendanceLinkCard extends StatelessWidget {
  const AdminAttendanceLinkCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/admin/attendance'),
      child: Row(
        children: <Widget>[
          AppIconBadge(
            icon: Icons.list_alt,
            color: context.color.primary,
            size: 32,
            radius: AppDimens.radius,
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  LangKeys.adminAttendanceDetail.tr(),
                  style: AppTextStyles.cardTitle.copyWith(
                    color: context.color.foreground,
                  ),
                ),
                Text(
                  LangKeys.viewDailyMonthly.tr(),
                  style: AppTextStyles.caption.copyWith(
                    color: context.color.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: AppDimens.iconLg,
            color: context.color.subtleForeground,
          ),
        ],
      ),
    );
  }
}
