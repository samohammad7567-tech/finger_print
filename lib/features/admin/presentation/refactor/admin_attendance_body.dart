import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
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
          curr.error != null || curr.message != prev.message,
      listener: (context, state) {
        final cubit = context.read<AdminAttendanceCubit>();
        // The cubit deals in keys; the words are this layer's job.
        if (state.error != null) {
          AppToast.error(context, state.error!.tr());
          cubit.clearError();
        } else if (state.message != null) {
          AppToast.success(context, state.message!.tr());
        }
      },
      child: BlocBuilder<AdminAttendanceCubit, AdminAttendanceState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            LangKeys.adminAttendanceDetail.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Only the monthly view has a month to export.
                        if (state.isMonthlyView)
                          MonthlyReportExportButton(state: state),
                        const AdminViewToggle(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AdminDatePicker(isArabic: isArabic),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppTextField(
                  hint: LangKeys.searchByNameOrId.tr(),
                  prefixIcon: Icons.search,
                  onChanged: (v) =>
                      context.read<AdminAttendanceCubit>().setSearch(v),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.isMonthlyView
                    ? AdminMonthlyView(state: state)
                    : AdminDailyView(state: state),
              ),
            ],
          );
        },
      ),
    );
  }
}
