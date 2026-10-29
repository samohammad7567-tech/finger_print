import 'package:flutter/material.dart';

import '../../../attendance/data/models/attendance_record_model.dart';
import '../cubit/punch_report_cubit.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_tinted_pill.dart';

/// How each kind of value is drawn in the punch report's table.
///
/// Every clock time and duration here is set in **IBM Plex Mono**, through the
/// scale's `mono` ranks. That is what the family is bundled for — "every value
/// an operator has to compare character by character" — and it is the whole
/// difference in a column of forty arrival times: the digits line up, so a
/// 09:05 among 08:0x reads as odd at a glance instead of needing to be read.
/// The mono ranks also carry tabular figures already, so no caller has to ask.
class PunchCells {
  const PunchCells._();

  /// A column heading. [AppTextStyles.columnHeader] exists for exactly this —
  /// 10.5px semibold on wide tracking, so the band reads as a label rather
  /// than as the first row of data.
  static Widget head(String label) =>
      Text(label, style: AppTextStyles.columnHeader);

  static Widget text(String value, {bool bold = false, Color? color}) => Text(
    value,
    style: (bold ? AppTextStyles.captionMedium : AppTextStyles.caption)
        .copyWith(color: color),
  );

  /// An unrecorded punch reads as a dash, not an empty cell, so a missing scan
  /// is visibly missing rather than looking like a rendering gap.
  static Widget time(BuildContext context, String? value) {
    final missing = value == null || value.isEmpty;
    return Text(
      missing ? '—' : value,
      style: AppTextStyles.mono.copyWith(
        color: missing
            ? context.color.subtleForeground
            : context.color.foreground,
      ),
    );
  }

  static String duration(Duration? d) => d == null
      ? '—'
      : '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

  /// A duration, in the mono rank so a column of them aligns.
  static Widget durationCell(
    BuildContext context,
    Duration? value, {
    bool bold = false,
    Color? color,
  }) => Text(
    duration(value),
    style: AppTextStyles.mono.copyWith(
      color: color ?? (value == null ? context.color.subtleForeground : null),
      fontWeight: bold ? FontWeight.w600 : null,
    ),
  );

  /// Each break as its own chip, wrapping onto a second line rather than being
  /// cut off — the point of the column is that none of them are hidden.
  static Widget breaks(BuildContext context, List<AttendanceBreak> breaks) {
    if (breaks.isEmpty) return text('—', color: context.color.subtleForeground);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
        child: Wrap(
          spacing: AppDimens.spaceXs,
          runSpacing: AppDimens.spaceXs,
          children: breaks.map((b) => _breakChip(context, b)).toList(),
        ),
      ),
    );
  }

  static Widget _breakChip(BuildContext context, AttendanceBreak b) {
    // An open break — they left and never scanned back — is worth seeing as
    // such instead of being quietly dropped.
    final color = b.isClosed
        ? context.color.primary
        : context.color.warningSoft;

    return AppTintedPill(
      label: '${b.out} → ${b.backIn ?? '—'}',
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      radius: AppDimens.radiusSm,
      tintAlpha: 0.12,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// Overtime as a duration, with the hours it ran under it when there is a
  /// scanned overtime shift to point at.
  static Widget overtime(BuildContext context, PunchReportRow row) {
    final from = row.record.overtimeInTime;
    final to = row.record.overtimeOutTime;
    final hasWindow =
        row.overtime != null &&
        from != null &&
        from.isNotEmpty &&
        to != null &&
        to.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        durationCell(
          context,
          row.overtime,
          bold: row.overtime != null,
          color: row.overtime == null ? null : context.color.primary,
        ),
        if (hasWindow)
          Text(
            '$from → $to',
            style: AppTextStyles.monoMicro.copyWith(
              color: context.color.subtleForeground,
            ),
          ),
      ],
    );
  }
}
