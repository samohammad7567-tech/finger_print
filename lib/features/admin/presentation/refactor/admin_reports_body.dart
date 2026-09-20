import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/admin_reports_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class AdminReportsBody extends StatelessWidget {
  const AdminReportsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminReportsCubit, AdminReportsState>(
      listenWhen: (prev, curr) => curr.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<AdminReportsCubit>().clearError();
      },
      child: BlocBuilder<AdminReportsCubit, AdminReportsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LangKeys.adminReports.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLast7Days(context, state),
                const SizedBox(height: 16),
                if (state.deptStats.isNotEmpty) _buildDeptRates(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLast7Days(BuildContext context, AdminReportsState state) {
    final maxVal = state.last7Days.fold<int>(
      0,
      (m, d) => d.total > m ? d.total : m,
    );
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 16, color: context.color.primary),
              const SizedBox(width: 8),
              Text(
                LangKeys.adminLast7Days.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: state.last7Days.map((day) {
                final h = maxVal > 0 ? (day.total / maxVal * 100) : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${day.total}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: h.clamp(4, 100),
                          decoration: BoxDecoration(
                            color: context.color.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day.date,
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(context.color.success, LangKeys.present.tr()),
              const SizedBox(width: 16),
              _legend(context.color.warning, LangKeys.late.tr()),
              const SizedBox(width: 16),
              _legend(context.color.destructive, LangKeys.absent.tr()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeptRates(BuildContext context, AdminReportsState state) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: context.color.primary),
              const SizedBox(width: 8),
              Text(
                LangKeys.adminDeptRates.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...state.deptStats.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Everybody filed under no department still has an
                      // attendance rate; a blank label would leave their bar
                      // unexplained.
                      Flexible(
                        child: Text(
                          d.department.trim().isEmpty
                              ? LangKeys.departmentNone.tr()
                              : d.department,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${d.rate}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: d.rate / 100,
                      minHeight: 8,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(
                        d.rate >= 80
                            ? context.color.success
                            : d.rate >= 60
                            ? context.color.warning
                            : context.color.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }
}
