import 'package:flutter/material.dart';

import '../../../attendance/data/models/attendance_record_model.dart';
import '../cubit/punch_report_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// How each kind of value is drawn in the punch report's table.
class PunchCells {
  const PunchCells._();

  static Widget head(String label) => Text(
    label,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
  );

  static Widget text(String value, {bool bold = false, Color? color}) => Text(
    value,
    style: TextStyle(
      fontSize: 12,
      color: color,
      fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
    ),
  );

  /// An unrecorded punch reads as a dash, not an empty cell, so a missing scan
  /// is visibly missing rather than looking like a rendering gap.
  static Widget time(BuildContext context, String? value) => Text(
    (value == null || value.isEmpty) ? '—' : value,
    style: TextStyle(
      fontSize: 12,
      color: (value == null || value.isEmpty)
          ? context.color.subtleForeground
          : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );

  static String duration(Duration? d) => d == null
      ? '—'
      : '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

  /// Each break as its own chip, wrapping onto a second line rather than being
  /// cut off — the point of the column is that none of them are hidden.
  static Widget breaks(BuildContext context, List<AttendanceBreak> breaks) {
    if (breaks.isEmpty) return text('—', color: context.color.subtleForeground);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${b.out} → ${b.backIn ?? '—'}',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
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
      children: [
        text(
          duration(row.overtime),
          bold: row.overtime != null,
          color: row.overtime == null ? null : context.color.primary,
        ),
        if (hasWindow)
          Text(
            '$from → $to',
            style: TextStyle(
              fontSize: 9,
              color: context.color.subtleForeground,
            ),
          ),
      ],
    );
  }
}
