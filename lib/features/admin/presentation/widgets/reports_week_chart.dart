import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/admin_reports_cubit.dart';

/// Records written per day over the last week.
///
/// **One series, named by the card's own title, so there is no legend.** It
/// used to carry a three-colour legend — present, late, absent — above bars
/// that encoded none of them: every bar was a single primary-tinted total, and
/// the legend promised a breakdown the chart did not draw.
///
/// The breakdown is real and worth having, but it cannot be carried by colour
/// here: the palette's `success` and `warning` sit ΔE 9.3 apart in normal
/// vision and 3.8 under protanopia, so a stacked column would be three
/// segments with two of them indistinguishable. The theme is fixed, so the
/// breakdown is delivered as *text* in each bar's tooltip instead — which is
/// legible to everybody, including a screen reader.
class ReportsWeekChart extends StatelessWidget {
  const ReportsWeekChart({super.key, required this.days});

  final List<DayStats> days;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(0, (m, d) => d.total > m ? d.total : m);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.bar_chart,
                size: AppDimens.iconMd,
                color: context.color.primary,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                LangKeys.adminLast7Days.tr(),
                style: AppTextStyles.cardTitle.copyWith(
                  color: context.color.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final day in days)
                  Expanded(
                    child: _Column(day: day, peak: peak),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          // A recessive baseline, so the columns read as standing on something
          // without the rule competing with them.
          Divider(height: 1, color: context.color.borderSoft),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.day, required this.peak});

  final DayStats day;
  final int peak;

  @override
  Widget build(BuildContext context) {
    // Proportional to the tallest day, with a visible stub for a day that is
    // genuinely zero — a column of no height reads as missing data.
    final fraction = peak > 0 ? day.total / peak : 0.0;

    return Tooltip(
      message: _breakdown(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              '${day.total}',
              style: AppTextStyles.monoMicro.copyWith(
                color: context.color.mutedForeground,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Flexible(
              child: FractionallySizedBox(
                heightFactor: fraction.clamp(0.03, 1.0),
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.color.primary,
                    // Rounded at the data end only; the foot stays square on
                    // the baseline it is measured from.
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimens.radiusXs),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              day.date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.monoMicro.copyWith(
                color: context.color.subtleForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The day's figures in words — the chart's secondary encoding, and the only
  /// place the three statuses are separated.
  String _breakdown() =>
      '${day.date}\n'
      '${LangKeys.present.tr()}: ${day.present}\n'
      '${LangKeys.late.tr()}: ${day.late}\n'
      '${LangKeys.absent.tr()}: ${day.absent}';
}
