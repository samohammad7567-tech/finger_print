import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
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
      spacing: AppDimens.cardGap,
      runSpacing: AppDimens.cardGap,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: context.color.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppDimens.radius),
        border: Border.all(color: context.color.borderSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A total is a figure to be compared against the other three,
          // so it is set in the mono rank: the four chips line up on their
          // digits instead of each being centred on its own width.
          Text(
            value,
            style: AppTextStyles.mono.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.color.foreground,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.statLabel.copyWith(
              color: context.color.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
