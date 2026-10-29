import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/admin_reports_cubit.dart';

/// Attendance rate per department, best first.
///
/// The bar is a magnitude and the colour is a *state* — good, watch, poor —
/// drawn from the palette's reserved status slots. Colour is never the only
/// carrier: every row shows its percentage as a direct label, so the ranking
/// reads without relying on three tints a colourblind operator may not be
/// able to separate.
class ReportsDeptRates extends StatelessWidget {
  const ReportsDeptRates({super.key, required this.stats});

  final List<DeptStat> stats;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.trending_up,
                size: AppDimens.iconMd,
                color: context.color.primary,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                LangKeys.adminDeptRates.tr(),
                style: AppTextStyles.cardTitle.copyWith(
                  color: context.color.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          for (final stat in stats) _Row(stat: stat),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.stat});

  final DeptStat stat;

  @override
  Widget build(BuildContext context) {
    final tone = switch (stat.rate) {
      >= 80 => context.color.success,
      >= 60 => context.color.warning,
      _ => context.color.destructive,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Everybody filed under no department still has an attendance
              // rate; a blank label would leave their bar unexplained.
              Flexible(
                child: Text(
                  stat.department.trim().isEmpty
                      ? LangKeys.departmentNone.tr()
                      : stat.department,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: context.color.foreground,
                  ),
                ),
              ),
              Text(
                '${stat.rate}%',
                style: AppTextStyles.monoMeta.copyWith(
                  color: context.color.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusXs),
            child: LinearProgressIndicator(
              value: stat.rate / 100,
              minHeight: 6,
              backgroundColor: context.color.muted,
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
        ],
      ),
    );
  }
}
