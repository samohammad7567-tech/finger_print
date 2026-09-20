import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/punch_report_cubit.dart';

/// Row count, worked time and overtime for whatever the filters currently
/// select.
class PunchReportTotals extends StatelessWidget {
  const PunchReportTotals({super.key, required this.state});

  final PunchReportState state;

  @override
  Widget build(BuildContext context) {
    String hhmm(Duration d) =>
        '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _chip(context, LangKeys.reportRows.tr(), '${state.visibleRows.length}'),
        _chip(context, LangKeys.reportWorked.tr(), hhmm(state.totalWorked)),
        _chip(
          context,
          LangKeys.reportBreakTime.tr(),
          hhmm(state.totalBreakTime),
        ),
        _chip(context, LangKeys.reportOvertime.tr(), hhmm(state.totalOvertime)),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
