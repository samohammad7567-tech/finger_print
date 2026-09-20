import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../data/data_source/monthly_report_pdf_data_source.dart';
import '../cubit/admin_attendance_cubit.dart';

/// One tap exports the month on screen. Nothing to pick first — the admin is
/// already looking at the rows the file will contain.
class MonthlyReportExportButton extends StatelessWidget {
  const MonthlyReportExportButton({super.key, required this.state});

  final AdminAttendanceState state;

  @override
  Widget build(BuildContext context) {
    final busy = state.isExportingPdf;
    final canExport =
        !busy && !state.isLoading && state.filteredSummaries.isNotEmpty;

    return TextButton.icon(
      onPressed: canExport
          ? () => context.read<AdminAttendanceCubit>().exportMonthlyPdf(
              labels: _labels(context),
              isArabic: context.locale.languageCode == 'ar',
            )
          : null,
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined, size: 16),
      label: Text(
        (busy ? LangKeys.reportPdfBuilding : LangKeys.reportPdf).tr(),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  /// The headings are translated here — the exporter is a data source and has
  /// no business knowing the language.
  MonthlyReportPdfLabels _labels(BuildContext context) {
    final locale = context.locale.languageCode;
    return MonthlyReportPdfLabels(
      title: LangKeys.monthlyReportTitle.tr(),
      month: DateFormat('MMMM yyyy', locale).format(state.selectedDate),
      generatedAt: LangKeys.reportGeneratedAt.tr(
        args: [DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())],
      ),
      name: LangKeys.adminFullName.tr(),
      department: LangKeys.adminDepartment.tr(),
      presentDays: LangKeys.presentDays.tr(),
      lateTimes: LangKeys.lateTimes.tr(),
      earlyLeave: LangKeys.earlyLeave.tr(),
      absentDays: LangKeys.absent.tr(),
      permissionDays: LangKeys.permissionsDays.tr(),
      lateHours: LangKeys.totalLateHours.tr(),
      overtime: LangKeys.reportOvertime.tr(),
      totals: LangKeys.reportTotals.tr(),
    );
  }
}
