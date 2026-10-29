import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_table_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/admin_attendance_cubit.dart';
import '../widgets/admin_view_toggle.dart';
import '../widgets/admin_date_picker.dart';
import '../widgets/admin_daily_view.dart';
import '../widgets/admin_monthly_view.dart';
import '../widgets/monthly_report_export_button.dart';

class AdminAttendanceBody extends StatelessWidget {
  const AdminAttendanceBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<SettingsCubit>().state.isArabic;

    return BlocListener<AdminAttendanceCubit, AdminAttendanceState>(
      listenWhen: (prev, curr) =>
          curr.error != prev.error || curr.message != prev.message,
      listener: (context, state) {
        // The cubit deals in keys; the words are this layer's job. The error
        // is not cleared here — it is what the page below renders when the
        // load left nothing to show, and the next load retires it.
        if (state.error != null) {
          AppToast.error(context, state.error!.tr());
        } else if (state.message != null) {
          AppToast.success(context, state.message!.tr());
        }
      },
      child: BlocBuilder<AdminAttendanceCubit, AdminAttendanceState>(
        builder: (context, state) {
          return Column(
            children: <Widget>[
              _Toolbar(state: state, isArabic: isArabic),
              const SizedBox(height: AppDimens.spaceSm),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding,
                ),
                child: AppTextField(
                  hint: LangKeys.searchByNameOrId.tr(),
                  prefixIcon: Icons.search,
                  onChanged: (v) =>
                      context.read<AdminAttendanceCubit>().setSearch(v),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Expanded(child: _content(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, AdminAttendanceState state) {
    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
        child: AppTableSkeleton(
          rows: 10,
          // The monthly view carries a figure per column; the daily one is a
          // name, a pair of times and a status.
          columnFlex: state.isMonthlyView
              ? const <int>[4, 2, 2, 2, 2, 2, 2]
              : const <int>[4, 2, 2, 3],
        ),
      );
    }

    // Nothing loaded and an error on file: the load failed. The views below
    // handle their own empty case, which is a different thing entirely.
    if (state.error != null && state.employees.isEmpty) {
      return AppErrorState(
        messageKey: state.error,
        onRetry: () {
          final cubit = context.read<AdminAttendanceCubit>();
          state.isMonthlyView ? cubit.loadMonth() : cubit.loadDay();
        },
      );
    }

    return state.isMonthlyView
        ? AdminMonthlyView(state: state)
        : AdminDailyView(state: state);
  }
}

/// The page title, the month export, the day/month switch and the date picker.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state, required this.isArabic});

  final AdminAttendanceState state;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.pagePaddingTop,
        AppDimens.pagePadding,
        0,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  LangKeys.adminAttendanceDetail.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subheading.copyWith(
                    color: context.color.foreground,
                  ),
                ),
              ),
              // Only the monthly view has a month to export.
              if (state.isMonthlyView) MonthlyReportExportButton(state: state),
              const AdminViewToggle(),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          AdminDatePicker(isArabic: isArabic),
        ],
      ),
    );
  }
}
