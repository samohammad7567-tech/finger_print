import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../refactor/employee_pattern.dart';
import '../../../../core/style/theme/context_extension.dart';

/// One person's range, as a name and a row of chips.
///
/// The chips carry counts rather than a single worst label: "Late ×6" and
/// "Absent ×1" are two different conversations, and collapsing them to one
/// word is what the day flags were introduced to stop.
class EmployeePatternRow extends StatelessWidget {
  const EmployeePatternRow({super.key, required this.pattern});

  final EmployeePattern pattern;

  @override
  Widget build(BuildContext context) {
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _name(faded)),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: pattern.isClean ? _clean(context) : _chips(context),
          ),
        ],
      ),
    );
  }

  Widget _name(Color faded) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        pattern.employee.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 2),
      Text(
        LangKeys.reportIssueDays.tr(
          args: ['${pattern.daysWithIssues}', '${pattern.daysCovered}'],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, color: faded),
      ),
    ],
  );

  Widget _chips(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final flag in pattern.presentFlags)
        _flagChip(context, flag, pattern.countOf(flag)),
      // The minutes behind the counts: five minutes late six times and an
      // hour late once are the same tally and a very different problem.
      if (pattern.lateMinutes > 0)
        _minutesChip(
          LangKeys.reportLateTotal.tr(),
          pattern.lateMinutes,
          context.color.warning,
        ),
      if (pattern.earlyOutMinutes > 0)
        _minutesChip(
          LangKeys.reportEarlyOutTotal.tr(),
          pattern.earlyOutMinutes,
          context.color.warningSoft,
        ),
    ],
  );

  Widget _clean(BuildContext context) => Row(
    children: [
      Icon(Icons.check_circle_outline, size: 14, color: context.color.success),
      const SizedBox(width: 6),
      Text(
        LangKeys.reportNoIssues.tr(),
        style: TextStyle(
          fontSize: 11,
          color: context.color.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  static Widget _flagChip(
    BuildContext context,
    AttendanceFlag flag,
    int count,
  ) {
    final display = getFlagDisplay(flag, context.color);
    return _chip('${display.labelKey.tr()} ×$count', display.color);
  }

  static Widget _minutesChip(String label, int minutes, Color color) => _chip(
    '$label ${minutes ~/ 60}h '
    '${(minutes % 60).toString().padLeft(2, '0')}m',
    color,
  );

  static Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );
}
