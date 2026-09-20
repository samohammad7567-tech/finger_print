import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/attendance_detail_cubit.dart';
import '../cubit/attendance_detail_state.dart';
import '../widgets/employee_profile_card.dart';
import '../widgets/detail_stat_card.dart';
import '../../../../core/style/theme/context_extension.dart';

class AttendanceDetailBody extends StatelessWidget {
  const AttendanceDetailBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<SettingsCubit>().state.isArabic;

    return BlocListener<AttendanceDetailCubit, AttendanceDetailState>(
      listenWhen: (prev, curr) => curr.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<AttendanceDetailCubit>().clearError();
      },
      child: BlocBuilder<AttendanceDetailCubit, AttendanceDetailState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                if (state.employee != null)
                  EmployeeProfileCard(employee: state.employee!),
                const SizedBox(height: 16),
                _buildStats(context, state),
                const SizedBox(height: 24),
                Text(
                  LangKeys.attendanceHistory.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                ...state.records.map((rec) {
                  final status = parseStatus(rec.status);
                  final display = getStatusDisplay(status, context.color);
                  final hours = calcWorkingHours(
                    rec.checkInTime,
                    rec.checkOutTime,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 32,
                            decoration: BoxDecoration(
                              color: display.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatDateLocalized(
                                    rec.date,
                                    isArabic: isArabic,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (rec.checkInTime != null) ...[
                                      Icon(
                                        Icons.access_time,
                                        size: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        rec.checkInTime!,
                                        style: _timeStyle(context),
                                      ),
                                    ],
                                    if (rec.checkOutTime != null) ...[
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.access_time,
                                        size: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        rec.checkOutTime!,
                                        style: _timeStyle(context),
                                      ),
                                    ],
                                    if (hours != null) ...[
                                      const SizedBox(width: 12),
                                      Text(hours, style: _timeStyle(context)),
                                    ],
                                  ],
                                ),
                                if (rec.notes != null && rec.notes!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      rec.notes!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppStatusChip(
                                status: status,
                                size: StatusChipSize.sm,
                              ),
                              if (rec.isEarlyLeave ||
                                  rec.status == 'early_leave')
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 4,
                                  ),
                                  child: Icon(
                                    Icons.warning_amber,
                                    size: 14,
                                    color: context.color.warningSoft,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (state.records.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        LangKeys.noRecords.tr(),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back,
              size: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          LangKeys.attendanceDetails.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildStats(BuildContext context, AttendanceDetailState state) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        DetailStatCard(
          label: LangKeys.attendanceRate.tr(),
          value: '${state.attendanceRate}%',
          color: context.color.success,
        ),
        DetailStatCard(
          label: LangKeys.presentDays.tr(),
          value: '${state.presentCount}',
          color: context.color.primary,
        ),
        DetailStatCard(
          label: LangKeys.lateDays.tr(),
          value: '${state.lateCount}',
          color: context.color.warning,
        ),
        DetailStatCard(
          label: LangKeys.absentDays.tr(),
          value: '${state.absentCount}',
          color: context.color.destructive,
        ),
        DetailStatCard(
          label: LangKeys.earlyLeaveDays.tr(),
          value: '${state.earlyLeaveCount}',
          color: context.color.warningSoft,
        ),
      ],
    );
  }

  TextStyle _timeStyle(BuildContext context) => TextStyle(
    fontSize: 11,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
  );
}
