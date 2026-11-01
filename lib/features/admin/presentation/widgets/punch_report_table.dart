import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../cubit/punch_report_cubit.dart';
import '../refactor/punch_pair_header.dart';
import 'punch_correction_sheet.dart';
import 'punch_report_cells.dart';

/// One row per employee per day: every scan pair in order, from the first
/// check-in to the last check-out.
///
/// Built on [Table] with proportional columns rather than [DataTable]: a report
/// of twelve-plus columns is wider than the window at its minimum size, and a
/// horizontal scrollbar hides the scan columns the operator opened the page to
/// read. Proportional columns keep every column on screen at once and clip long
/// identities instead.
class PunchReportTable extends StatelessWidget {
  const PunchReportTable({super.key, required this.rows});

  final List<PunchReportRow> rows;

  /// Relative widths of the leading columns: serial, surname, full name,
  /// personal id, accommodation, date and day.
  static const List<int> _leadFlex = <int>[1, 3, 4, 3, 3, 3, 2];

  /// Width of each of the two columns a scan pair contributes, and of the
  /// trailing correction column.
  static const int _scanFlex = 2;

  /// Wide enough for the correction button's own 30px tap target plus padding.
  /// At one unit the column collapsed to a sliver and the button could not be
  /// hit.
  static const int _correctFlex = 2;

  @override
  Widget build(BuildContext context) {
    // Read once for the whole table: which rows are still correctable is a
    // question about today, and every row must be asked the same one.
    final today = DateTime.now();

    var pairCount = 1;
    for (final row in rows) {
      if (row.pairs.length > pairCount) pairCount = row.pairs.length;
    }

    final flex = <int>[
      ..._leadFlex,
      for (var i = 0; i < pairCount * 2; i++) _scanFlex,
      _correctFlex,
    ];

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: <int, TableColumnWidth>{
        for (var i = 0; i < flex.length; i++)
          i: FlexColumnWidth(flex[i].toDouble()),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: context.color.borderSoft),
      ),
      children: <TableRow>[
        TableRow(
          decoration: BoxDecoration(color: context.color.backgroundSubtle),
          children: <Widget>[
            _head(LangKeys.reportSerialNumber.tr()),
            _head(LangKeys.adminSurname.tr()),
            _head(LangKeys.adminFullName.tr()),
            _head(LangKeys.adminPersonalId.tr()),
            _head(LangKeys.reportAccommodation.tr()),
            _head(LangKeys.date.tr()),
            _head(LangKeys.reportDay.tr()),
            for (var i = 1; i <= pairCount; i++) ...<Widget>[
              _head(punchPairHeader(i, checkIn: true)),
              _head(punchPairHeader(i, checkIn: false)),
            ],
            _head(LangKeys.reportCorrect.tr()),
          ],
        ),
        for (final (index, row) in rows.indexed)
          _row(context, row, today, pairCount, index + 1),
      ],
    );
  }

  TableRow _row(
    BuildContext context,
    PunchReportRow row,
    DateTime today,
    int pairCount,
    int serial,
  ) {
    final r = row.record;
    final dayName = DateFormat('EEEE', context.locale.languageCode);
    final accommodation = row.accommodationText(
      traveler: LangKeys.reportTraveler.tr(),
      overnight: LangKeys.reportOvernight.tr(),
    );

    return TableRow(
      children: <Widget>[
        _cell(PunchCells.text('$serial')),
        _cell(_ellipsis(context, row.surname)),
        _cell(_ellipsis(context, row.employee.fullName)),
        _cell(_ellipsis(context, row.personalId)),
        _cell(_ellipsis(context, accommodation)),
        _cell(PunchCells.text(r.date)),
        _cell(PunchCells.text(dayName.format(row.day))),
        for (var i = 0; i < pairCount; i++) ...<Widget>[
          _cell(
            PunchCells.time(
              context,
              i < row.pairs.length ? row.pairs[i].checkIn : null,
            ),
          ),
          _cell(
            PunchCells.time(
              context,
              i < row.pairs.length ? row.pairs[i].checkOut : null,
            ),
          ),
        ],
        _actionCell(_correctButton(context, row, today)),
      ],
    );
  }

  /// A column heading. Two lines are permitted so a long label such as
  /// "First check-in" wraps rather than being ellipsized on a narrow window;
  /// the header band grows to fit it and every body row follows.
  Widget _head(String label) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppDimens.tableHeaderHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.tableCellPaddingH,
          vertical: AppDimens.spaceXs,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.columnHeader,
          ),
        ),
      ),
    );
  }

  /// One body cell at the table's own metrics, so every row is the same height
  /// and the figures line up across the page.
  Widget _cell(Widget child) {
    return SizedBox(
      height: AppDimens.tableRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.tableCellPaddingH,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: child,
        ),
      ),
    );
  }

  /// The action column's cell.
  ///
  /// It uses the tight cell padding of the identity columns only on its leading
  /// edge: the button needs its whole 30px tap target, and 12px of padding on
  /// both sides would squeeze it back to a sliver on the minimum window.
  Widget _actionCell(Widget child) {
    return SizedBox(
      height: AppDimens.tableRowHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppDimens.spaceXs,
          end: AppDimens.spaceXs,
        ),
        child: Center(child: child),
      ),
    );
  }

  /// A plain value clipped rather than allowed to push the scan columns off
  /// the table. An empty identity field reads as a dash, the same as a missing
  /// scan does.
  Widget _ellipsis(BuildContext context, String value) {
    final text = value.trim().isEmpty ? '—' : value;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.captionMedium.copyWith(
        color: context.color.foreground,
      ),
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

    return SizedBox(
      width: AppDimens.iconButtonSize,
      height: AppDimens.iconButtonSize,
      child: IconButton(
        onPressed: canCorrect
            ? () => PunchCorrectionSheet.show(context, row)
            : null,
        tooltip: canCorrect
            ? LangKeys.reportCorrect.tr()
            : (row.isCorrected
                      ? LangKeys.reportCorrectUsed
                      : LangKeys.reportCorrectClosed)
                  .tr(),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: AppDimens.iconButtonSize,
          height: AppDimens.iconButtonSize,
        ),
        visualDensity: VisualDensity.compact,
        iconSize: AppDimens.iconMd,
        icon: Icon(
          row.isCorrected ? Icons.lock_outline : Icons.edit_outlined,
        ),
      ),
    );
  }
}
