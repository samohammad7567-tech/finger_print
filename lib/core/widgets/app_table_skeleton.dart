import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/context_extension.dart';
import 'app_skeleton.dart';

/// The placeholder for a table that has not loaded.
///
/// Drawn at the table's own metrics — [AppDimens.tableHeaderHeight] for the
/// band, [AppDimens.tableRowHeight] for each row, [AppDimens.tableCellPaddingH]
/// either side of every cell — so the real rows land exactly where the grey
/// ones were. That is the whole point: a spinner in the middle of a page makes
/// the table arrive as a jolt, and on a dense report the operator loses the
/// line they were reading.
///
/// [columnFlex] should mirror the real columns' relative widths. The default
/// is a plausible report shape — a wide name, then narrow figures — and is
/// better than nothing, but a caller that knows its own table should say so.
class AppTableSkeleton extends StatelessWidget {
  const AppTableSkeleton({
    super.key,
    this.rows = 8,
    this.columnFlex = const <int>[4, 2, 2, 2, 2, 2],
    this.showHeader = true,
  });

  final int rows;
  final List<int> columnFlex;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showHeader) _band(context),
          for (var i = 0; i < rows; i++) _row(context, i),
        ],
      ),
    );
  }

  Widget _band(BuildContext context) {
    return Container(
      height: AppDimens.tableHeaderHeight,
      decoration: BoxDecoration(
        color: context.color.backgroundSubtle,
        border: Border(bottom: BorderSide(color: context.color.border)),
      ),
      child: Row(children: _cells(headerRow: true)),
    );
  }

  Widget _row(BuildContext context, int index) {
    return Container(
      height: AppDimens.tableRowHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.color.borderSoft)),
      ),
      child: Row(children: _cells(headerRow: false, seed: index)),
    );
  }

  /// One grey line per column, inset by the cell padding.
  ///
  /// The line is shortened on a varying subset of the columns so the block
  /// does not read as a solid grid — real rows are ragged, and a skeleton that
  /// is perfectly regular looks like a rendering fault rather than a wait.
  List<Widget> _cells({required bool headerRow, int seed = 0}) {
    return <Widget>[
      for (final (index, flex) in columnFlex.indexed)
        Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.tableCellPaddingH,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: headerRow
                    ? 0.55
                    : ((index + seed) % 3 == 0 ? 0.62 : 0.84),
                child: AppSkeleton.line(height: headerRow ? 8 : 10),
              ),
            ),
          ),
        ),
    ];
  }
}
