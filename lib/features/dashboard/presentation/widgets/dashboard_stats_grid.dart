import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/lang_keys.dart';
import '../cubit/dashboard_state.dart';
import 'stat_card.dart';
import '../../../../core/style/theme/context_extension.dart';

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({super.key, required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: List.generate(
          4,
          (_) => Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        StatCard(
          label: LangKeys.present.tr(),
          value: state.present,
          icon: Icons.person,
          color: context.color.success,
        ),
        StatCard(
          label: LangKeys.late.tr(),
          value: state.late,
          icon: Icons.access_time,
          color: context.color.warning,
        ),
        StatCard(
          label: LangKeys.absent.tr(),
          value: state.absent,
          icon: Icons.person_off,
          color: context.color.destructive,
        ),
        StatCard(
          label: LangKeys.earlyLeave.tr(),
          value: state.earlyLeave,
          icon: Icons.warning_amber,
          color: context.color.primary,
        ),
      ],
    );
  }
}
