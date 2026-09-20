import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/admin_dashboard_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class AdminDashboardBody extends StatelessWidget {
  const AdminDashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<SettingsCubit>().state.isArabic;

    return BlocListener<AdminDashboardCubit, AdminDashboardState>(
      listenWhen: (prev, curr) => curr.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<AdminDashboardCubit>().clearError();
      },
      child: BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LangKeys.adminDashboard.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDateLocalized(getTodayDate(), isArabic: isArabic),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                if (state.isLoading)
                  _buildShimmer(context)
                else ...[
                  _buildStats(context, state),
                  const SizedBox(height: 16),
                  _buildAttendanceRate(context, state),
                  const SizedBox(height: 16),
                  _buildAttendanceDetailButton(context),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats(BuildContext context, AdminDashboardState state) {
    final cards = [
      (
        LangKeys.adminTotalEmployees.tr(),
        '${state.totalEmployees}',
        Icons.people,
        context.color.primary,
      ),
      (
        LangKeys.adminPresentToday.tr(),
        '${state.present}',
        Icons.check_circle,
        context.color.success,
      ),
      (
        LangKeys.absent.tr(),
        '${state.absent}',
        Icons.cancel,
        context.color.destructive,
      ),
      (
        LangKeys.late.tr(),
        '${state.late}',
        Icons.access_time,
        context.color.warning,
      ),
      (
        LangKeys.adminTodayRecords.tr(),
        '${state.totalRecords}',
        Icons.trending_up,
        context.color.primary,
      ),
      (
        LangKeys.adminUnregistered.tr(),
        '${state.unregistered}',
        Icons.warning_amber,
        context.color.warning,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: cards
          .map(
            (c) => GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          c.$1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c.$4,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          c.$3,
                          size: 14,
                          color: context.color.primaryForeground,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    c.$2,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAttendanceRate(BuildContext context, AdminDashboardState state) {
    if (state.totalEmployees == 0) return const SizedBox.shrink();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LangKeys.adminAttendanceRateToday.tr(),
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: state.attendanceRate / 100,
                    minHeight: 12,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(context.color.success),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${state.attendanceRate}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceDetailButton(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/admin/attendance'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.color.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.list_alt,
              size: 20,
              color: context.color.primaryForeground,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LangKeys.adminAttendanceDetail.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  LangKeys.viewDailyMonthly.tr(),
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
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: List.generate(
        6,
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
}
