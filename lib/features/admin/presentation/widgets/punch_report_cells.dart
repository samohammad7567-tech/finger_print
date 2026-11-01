import 'package:flutter/material.dart';

import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';

/// How each kind of value is drawn in the punch report's table.
///
/// Every clock time here is set in **IBM Plex Mono**, through the scale's `mono`
/// rank. That is what the family is bundled for — "every value an operator has
/// to compare character by character" — and it is the whole difference in a
/// column of forty arrival times: the digits line up, so a 09:05 among 08:0x
/// reads as odd at a glance instead of needing to be read. The mono rank also
/// carries tabular figures already, so no caller has to ask.
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
}
