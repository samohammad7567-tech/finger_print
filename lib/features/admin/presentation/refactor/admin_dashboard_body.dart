import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/app_card_skeleton.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/admin_dashboard_cubit.dart';
import '../widgets/admin_dashboard_cards.dart';
import '../widgets/admin_stat_card.dart';

class AdminDashboardBody extends StatelessWidget {
  const AdminDashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<SettingsCubit>().state.isArabic;

    return BlocListener<AdminDashboardCubit, AdminDashboardState>(
      listenWhen: (prev, curr) => prev.error != curr.error,
      listener: (context, state) {
        // Was a bare SnackBar carrying the untranslated key.
        if (state.error != null) AppToast.error(context, state.error!.tr());
      },
      child: BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.pagePaddingTop,
              AppDimens.pagePadding,
              AppDimens.pagePaddingBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  LangKeys.adminDashboard.tr(),
                  style: AppTextStyles.heading.copyWith(
                    color: context.color.foreground,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  formatDateLocalized(getTodayDate(), isArabic: isArabic),
                  style: AppTextStyles.caption.copyWith(
                    color: context.color.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppDimens.sectionGap),
                _content(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, AdminDashboardState state) {
    if (state.isLoading) {
      // Three to a row, matching _StatGrid exactly, so the six figures do
      // not re-wrap as they resolve.
      return const AppStatRowSkeleton(count: 6, cardHeight: 84, perRow: 3);
    }

    // Nothing counted and an error on file: the load failed rather than the
    // company being empty.
    if (state.error != null && state.totalEmployees == 0) {
      return AppErrorState(
        messageKey: state.error,
        onRetry: () => context.read<AdminDashboardCubit>().load(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatGrid(state: state),
        const SizedBox(height: AppDimens.sectionGap),
        AdminAttendanceRateCard(state: state),
        const SizedBox(height: AppDimens.sectionGap),
        const AdminAttendanceLinkCard(),
      ],
    );
  }
}

/// The six figures, three to a row on a full-width window and two to a row
/// under [AppDimens.statFoldWidth] — folding beats truncating a count.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.state});

  final AdminDashboardState state;

  @override
  Widget build(BuildContext context) {
    final cards = <AdminStatCard>[
      AdminStatCard(
        label: LangKeys.adminTotalEmployees.tr(),
        value: '${state.totalEmployees}',
        icon: Icons.people,
        tone: context.color.primary,
      ),
      AdminStatCard(
        label: LangKeys.adminPresentToday.tr(),
        value: '${state.present}',
        icon: Icons.check_circle,
        tone: context.color.success,
      ),
      AdminStatCard(
        label: LangKeys.absent.tr(),
        value: '${state.absent}',
        icon: Icons.cancel,
        tone: context.color.destructive,
      ),
      AdminStatCard(
        label: LangKeys.late.tr(),
        value: '${state.late}',
        icon: Icons.access_time,
        tone: context.color.warning,
      ),
      AdminStatCard(
        label: LangKeys.adminTodayRecords.tr(),
        value: '${state.totalRecords}',
        icon: Icons.trending_up,
        tone: context.color.primary,
      ),
      AdminStatCard(
        label: LangKeys.adminUnregistered.tr(),
        value: '${state.unregistered}',
        icon: Icons.warning_amber,
        tone: context.color.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth < AppDimens.statFoldWidth ? 2 : 3;
        final gaps = (perRow - 1) * AppDimens.cardGap;
        final width = (constraints.maxWidth - gaps) / perRow;

        return Wrap(
          spacing: AppDimens.cardGap,
          runSpacing: AppDimens.cardGap,
          children: <Widget>[
            for (final card in cards)
              SizedBox(width: width, height: 84, child: card),
          ],
        );
      },
    );
  }
}
