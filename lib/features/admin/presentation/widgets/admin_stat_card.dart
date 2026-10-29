import 'package:flutter/material.dart';

import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_icon_badge.dart';
import '../../../../core/widgets/glass_card.dart';

/// One figure on the admin dashboard: what it counts, and the count.
///
/// The number wears [AppTextStyles.statValue] with tabular figures, so a
/// column of these stays aligned as the counts tick between one and three
/// digits — the thing that made the old hand-rolled cards jitter on refresh.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;

  /// The badge fill. Carries the figure's semantic — a count of absences is
  /// destructive, a head count is simply primary.
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.statLabel.copyWith(
                    color: context.color.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              AppIconBadge(
                icon: icon,
                color: tone,
                size: 26,
                radius: AppDimens.radius,
                iconSize: AppDimens.iconSm,
              ),
            ],
          ),
          Text(
            value,
            style: AppTextStyles.statValue.copyWith(
              color: context.color.foreground,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
