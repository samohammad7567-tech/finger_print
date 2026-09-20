import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../widgets/dashboard_hero.dart';
import '../widgets/dashboard_stats_grid.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_attendance_list.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<SettingsCubit>().state.isArabic;

    return BlocListener<DashboardCubit, DashboardState>(
      listenWhen: (prev, curr) => curr.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<DashboardCubit>().clearError();
      },
      child: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () async => context.read<DashboardCubit>().refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardHero(state: state, isArabic: isArabic),
                  const SizedBox(height: 24),
                  Text(
                    LangKeys.todaysSummary.tr(),
                    style: _sectionStyle(context),
                  ),
                  const SizedBox(height: 12),
                  DashboardStatsGrid(state: state),
                  const SizedBox(height: 24),
                  Text(
                    LangKeys.quickActions.tr(),
                    style: _sectionStyle(context),
                  ),
                  const SizedBox(height: 12),
                  const QuickActions(),
                  const SizedBox(height: 24),
                  Text(
                    LangKeys.recentEntries.tr(),
                    style: _sectionStyle(context),
                  ),
                  const SizedBox(height: 12),
                  RecentAttendanceList(
                    records: state.records.reversed.take(5).toList(),
                    isLoading: state.isLoading,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  TextStyle _sectionStyle(BuildContext context) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
  );
}
