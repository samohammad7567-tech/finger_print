import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/attendance_utils.dart';
import '../cubit/punch_report_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Everything unusual about the day, one chip each.
///
/// A day is often more than one thing — late in and early out is the common
/// pair — and the stored status can only be one of them. Showing the whole
/// list is the point of the column: an admin reading down it is looking for a
/// pattern, and a day that quietly dropped half of what happened would hide
/// exactly the pattern they are looking for.
///
/// An ordinary day still shows its single status, so nothing changes for the
/// rows there was never anything to say about.
class PunchStatusCell extends StatelessWidget {
  const PunchStatusCell({super.key, required this.row});

  final PunchReportRow row;

  @override
  Widget build(BuildContext context) {
    final flags = row.flags;

    if (flags.isEmpty) {
      final display = getStatusDisplay(parseStatus(row.status), context.color);
      return chip(display.labelKey.tr(), display.color);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final flag in flags)
              Builder(
                builder: (_) {
                  final display = getFlagDisplay(flag, context.color);
                  return chip(display.labelKey.tr(), display.color);
                },
              ),
          ],
        ),
      ),
    );
  }

  static Widget chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );
}
