import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_card_skeleton.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../cubit/admin_reports_cubit.dart';
import '../widgets/reports_dept_rates.dart';
import '../widgets/reports_week_chart.dart';

class AdminReportsBody extends StatelessWidget {
  const AdminReportsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminReportsCubit, AdminReportsState>(
      listenWhen: (prev, curr) => prev.error != curr.error,
      listener: (context, state) {
        // Was a bare SnackBar showing the untranslated key.
        if (state.error != null) AppToast.error(context, state.error!.tr());
      },
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
                LangKeys.adminReports.tr(),
                style: AppTextStyles.heading.copyWith(
                  color: context.color.foreground,
                ),
              ),
              const SizedBox(height: AppDimens.sectionGap),
              _content(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, AdminReportsState state) {
    if (state.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppCardSkeleton(lines: 1, height: 212),
          SizedBox(height: AppDimens.sectionGap),
          AppCardSkeleton(lines: 4),
        ],
      );
    }

    if (state.error != null && state.last7Days.isEmpty) {
      return AppErrorState(
        messageKey: state.error,
        onRetry: () => context.read<AdminReportsCubit>().load(),
      );
    }

    if (state.last7Days.isEmpty) {
      return AppEmptyState(
        icon: Icons.bar_chart,
        title: LangKeys.noRecords.tr(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ReportsWeekChart(days: state.last7Days),
        if (state.deptStats.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppDimens.sectionGap),
          ReportsDeptRates(stats: state.deptStats),
        ],
      ],
    );
  }
}
