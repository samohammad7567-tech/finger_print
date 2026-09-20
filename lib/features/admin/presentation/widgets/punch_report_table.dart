import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/punch_report_cubit.dart';
import 'punch_correction_sheet.dart';
import 'punch_report_cells.dart';
import 'punch_status_cell.dart';

/// One row per employee per day: when they arrived and left, every break they
/// took, and what the three durations come to under the admin's hours.
///
/// Wide by nature, so it scrolls horizontally inside its own viewport rather
/// than forcing the page to.
class PunchReportTable extends StatelessWidget {
  const PunchReportTable({super.key, required this.rows});

  final List<PunchReportRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Read once for the whole table: which rows are still correctable is a
    // question about today, and every row must be asked the same one.
    final today = DateTime.now();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 44,
        dataRowMinHeight: 40,
        // A day with several breaks needs more than one line for them.
        dataRowMaxHeight: double.infinity,
        columnSpacing: 22,
        headingRowColor: WidgetStatePropertyAll(
          theme.colorScheme.onSurface.withValues(alpha: 0.04),
        ),
        columns: [
          DataColumn(label: PunchCells.head(LangKeys.adminEmployees.tr())),
          DataColumn(label: PunchCells.head(LangKeys.date.tr())),
          DataColumn(label: PunchCells.head(LangKeys.reportDay.tr())),
          DataColumn(label: PunchCells.head(LangKeys.reportCheckIn.tr())),
          DataColumn(label: PunchCells.head(LangKeys.reportCheckOut.tr())),
          DataColumn(label: PunchCells.head(LangKeys.reportBreaks.tr())),
          DataColumn(label: PunchCells.head(LangKeys.reportBreakTime.tr())),
          DataColumn(label: PunchCells.head(LangKeys.reportOvertime.tr())),
          DataColumn(label: PunchCells.head(LangKeys.reportWorked.tr())),
          DataColumn(label: PunchCells.head(LangKeys.status.tr())),
          DataColumn(label: PunchCells.head(LangKeys.reportCorrect.tr())),
        ],
        rows: rows.map((row) => _row(context, row, today)).toList(),
      ),
    );
  }

  DataRow _row(BuildContext context, PunchReportRow row, DateTime today) {
    final r = row.record;
    final dayName = DateFormat('EEEE', context.locale.languageCode);

    return DataRow(
      cells: [
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              row.employee.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        DataCell(PunchCells.text(r.date)),
        DataCell(PunchCells.text(dayName.format(row.day))),
        DataCell(PunchCells.time(context, r.checkInTime)),
        DataCell(PunchCells.time(context, r.checkOutTime)),
        DataCell(PunchCells.breaks(context, row.breaks)),
        DataCell(
          PunchCells.text(
            row.breaks.isEmpty ? '—' : PunchCells.duration(row.breakTime),
          ),
        ),
        DataCell(PunchCells.overtime(context, row)),
        DataCell(PunchCells.text(PunchCells.duration(row.worked), bold: true)),
        DataCell(PunchStatusCell(row: row)),
        DataCell(_correctButton(context, row, today)),
      ],
    );
  }

  /// The day's one correction.
  ///
  /// Offered on today's rows and only until it is spent; the tooltip says
  /// which of the two closed the door, because a button that is simply dead
  /// tells an admin nothing about why.
  Widget _correctButton(
    BuildContext context,
    PunchReportRow row,
    DateTime today,
  ) {
    final canCorrect = row.canCorrect(today);

    return IconButton(
      onPressed: canCorrect
          ? () => PunchCorrectionSheet.show(context, row)
          : null,
      tooltip: canCorrect
          ? LangKeys.reportCorrect.tr()
          : (row.isCorrected
                    ? LangKeys.reportCorrectUsed
                    : LangKeys.reportCorrectClosed)
                .tr(),
      visualDensity: VisualDensity.compact,
      icon: Icon(
        row.isCorrected ? Icons.lock_outline : Icons.edit_outlined,
        size: 16,
      ),
    );
  }
}
