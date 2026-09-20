import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/data_source/monthly_punches_excel_data_source.dart';
import '../../data/data_source/punch_report_pdf_data_source.dart';
import '../cubit/punch_report_cubit.dart';

/// The report's title, the hours it is measured against, and its four
/// actions: pull the terminal, export the range as a PDF, export the whole
/// month as a workbook, copy the CSV.
class PunchReportHeader extends StatelessWidget {
  const PunchReportHeader({super.key, required this.state});

  final PunchReportState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context),
          const SizedBox(height: 4),
          // A Wrap rather than a Row: four actions do not fit beside a title on
          // a narrow window, and an overflowing Row loses the last of them
          // rather than moving it down a line.
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _refreshButton(context),
              _pdfButton(context),
              _monthlyButton(context),
              TextButton.icon(
                onPressed: state.visibleRows.isEmpty
                    ? null
                    : () => _copyCsv(context),
                icon: const Icon(Icons.copy_all, size: 16),
                label: Text(
                  LangKeys.reportCopyCsv.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context) {
    final schedule = state.schedule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LangKeys.reportPunchTitle.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        // The hours the figures below were measured against — without them a
        // worked total is a number with no rule behind it. Once shifts exist
        // these are only the default day, and each row was judged by its own
        // person's shift, so the line says which it is rather than claiming
        // hours half the table never saw.
        Text(
          '${state.hasShifts ? '${LangKeys.shiftDefault.tr()}: ' : ''}'
          '${schedule.workStart} – ${schedule.workEnd}'
          '   ·   ${LangKeys.reportOvertime.tr()} '
          '${schedule.overtimeStart} – ${schedule.overtimeEnd}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  /// Pulls the terminal without leaving the report, and says so while it runs —
  /// a sync over the network takes long enough that a silent button looks dead.
  Widget _refreshButton(BuildContext context) {
    return TextButton.icon(
      onPressed: state.isSyncing
          ? null
          : () => context.read<PunchReportCubit>().refreshFromDevice(),
      icon: state.isSyncing
          ? const _Spinner()
          : const Icon(Icons.sync, size: 16),
      label: Text(
        (state.isSyncing ? LangKeys.reportRefreshing : LangKeys.reportRefresh)
            .tr(),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  /// Writes the rows on screen to a PDF. The headings are translated here —
  /// the exporter is a data source and has no business knowing the language.
  Widget _pdfButton(BuildContext context) {
    final busy = state.isExporting;

    return TextButton.icon(
      onPressed: state.visibleRows.isEmpty || busy
          ? null
          : () => context.read<PunchReportCubit>().exportPdf(
              labels: _pdfLabels(context),
              locale: context.locale.languageCode,
              isArabic: context.locale.languageCode == 'ar',
              statusLabel: _statusLabel,
            ),
      icon: busy
          ? const _Spinner()
          : const Icon(Icons.picture_as_pdf_outlined, size: 16),
      label: Text(
        (busy ? LangKeys.reportPdfBuilding : LangKeys.reportPdf).tr(),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  /// The whole month for everybody, as a workbook.
  ///
  /// Not tied to the rows on screen: it stays available on an empty range,
  /// because "there is nothing here" is one of the things somebody disputing
  /// their month may need the file to prove.
  Widget _monthlyButton(BuildContext context) {
    final busy = state.isExportingExcel;

    return TextButton.icon(
      onPressed: busy
          ? null
          : () => context.read<PunchReportCubit>().exportMonthlyExcel(
              labels: _excelLabels(context),
              locale: context.locale.languageCode,
              isArabic: context.locale.languageCode == 'ar',
              statusLabel: _statusLabel,
              saveLabel: LangKeys.adminSave.tr(),
            ),
      icon: busy
          ? const _Spinner()
          : const Icon(Icons.table_view_outlined, size: 16),
      label: Text(
        (busy ? LangKeys.reportMonthlyBuilding : LangKeys.reportMonthly).tr(),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  MonthlyPunchesExcelLabels _excelLabels(BuildContext context) {
    final locale = context.locale.languageCode;

    return MonthlyPunchesExcelLabels(
      title: LangKeys.reportMonthlyTitle.tr(),
      // The month the report is showing, named in the reader's language.
      month: DateFormat('MMMM yyyy', locale).format(state.start),
      generatedAt: LangKeys.reportGeneratedAt.tr(
        args: [DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())],
      ),
      allSheet: LangKeys.reportAllSheet.tr(),
      employee: LangKeys.adminFullName.tr(),
      employeeNumber: LangKeys.reportStaffNumber.tr(),
      department: LangKeys.adminDepartment.tr(),
      date: LangKeys.date.tr(),
      day: LangKeys.reportDay.tr(),
      checkIn: LangKeys.reportCheckIn.tr(),
      checkOut: LangKeys.reportCheckOut.tr(),
      breaks: LangKeys.reportBreaks.tr(),
      breakTime: LangKeys.reportBreakTime.tr(),
      overtime: LangKeys.reportOvertime.tr(),
      worked: LangKeys.reportWorked.tr(),
      status: LangKeys.status.tr(),
      corrected: LangKeys.reportCorrectedBy.tr(),
      totals: LangKeys.reportTotals.tr(),
      presentDays: LangKeys.presentDays.tr(),
      absentDays: LangKeys.absentDays.tr(),
    );
  }

  PunchReportPdfLabels _pdfLabels(BuildContext context) {
    final date = DateFormat('yyyy-MM-dd');
    return PunchReportPdfLabels(
      title: LangKeys.reportPunchTitle.tr(),
      range: '${date.format(state.start)}  →  ${date.format(state.end)}',
      generatedAt: LangKeys.reportGeneratedAt.tr(
        args: [DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())],
      ),
      name: LangKeys.adminEmployees.tr(),
      date: LangKeys.date.tr(),
      day: LangKeys.reportDay.tr(),
      checkIn: LangKeys.reportCheckIn.tr(),
      checkOut: LangKeys.reportCheckOut.tr(),
      breakTime: LangKeys.reportBreakTime.tr(),
      overtime: LangKeys.reportOvertime.tr(),
      workTime: LangKeys.reportWorked.tr(),
      status: LangKeys.status.tr(),
      totals: LangKeys.reportTotals.tr(),
    );
  }

  /// A stored status as a word on the page. The same mapping the status chip
  /// uses, so the file and the screen never say different things.
  /// The day's labels, translated and joined for a single export cell.
  ///
  /// A day carrying more than one — late in and early out — reads as both,
  /// exactly as the table shows it, so a printed report and the screen never
  /// disagree about what happened.
  static String _statusLabel(List<String> labelKeys) =>
      labelKeys.map((key) => key.tr()).join(' · ');

  /// The clipboard rather than a file: pasting straight into a spreadsheet is
  /// what an admin actually wants to do with the CSV.
  void _copyCsv(BuildContext context) {
    final csv = context.read<PunchReportCubit>().toCsv();
    Clipboard.setData(ClipboardData(text: csv));
    AppToast.success(context, LangKeys.reportCsvCopied.tr());
  }
}

/// Sized to sit where a 16px icon would, so the button does not jump when the
/// work starts.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 14,
    height: 14,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
