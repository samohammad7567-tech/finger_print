import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_time_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/rest_day_picker.dart';
import 'shift_grace_field.dart';

/// The four values that define a shift: when its day starts and ends, and how
/// much lateness and how early a departure it forgives.
///
/// Two cards rather than one, because they are two different kinds of answer —
/// the first pair are clock times the shift runs between, the second pair are
/// minutes it lets go of at each end.
class ShiftHoursFields extends StatelessWidget {
  const ShiftHoursFields({
    super.key,
    required this.startWork,
    required this.endWork,
    required this.lateGrace,
    required this.earlyOutGrace,
    required this.onStartWork,
    required this.onEndWork,
    required this.onLateGrace,
    required this.onEarlyOutGrace,
    required this.restDays,
    required this.onRestDays,
  });

  final String startWork;
  final String endWork;
  final int lateGrace;
  final int earlyOutGrace;

  final ValueChanged<String> onStartWork;
  final ValueChanged<String> onEndWork;
  final ValueChanged<int> onLateGrace;
  final ValueChanged<int> onEarlyOutGrace;

  /// The weekdays this shift does not work. Part of what defines it, so it
  /// sits with the hours rather than off on its own.
  final Set<int> restDays;
  final ValueChanged<Set<int>> onRestDays;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              AppTimeField(
                icon: Icons.login,
                label: LangKeys.shiftStartWork.tr(),
                value: startWork,
                onChanged: onStartWork,
              ),
              _divider(context),
              AppTimeField(
                icon: Icons.logout,
                label: LangKeys.shiftEndWork.tr(),
                value: endWork,
                onChanged: onEndWork,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ShiftGraceField(
                icon: Icons.timelapse,
                label: LangKeys.shiftLateGrace.tr(),
                minutes: lateGrace,
                onChanged: onLateGrace,
              ),
              _divider(context),
              ShiftGraceField(
                icon: Icons.exit_to_app,
                label: LangKeys.shiftEarlyOutGrace.tr(),
                minutes: earlyOutGrace,
                onChanged: onEarlyOutGrace,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              LangKeys.restDaysTitle.tr(),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        RestDayPicker(restDays: restDays, onChanged: onRestDays),
      ],
    );
  }

  Widget _divider(BuildContext context) => Divider(
    height: 1,
    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
  );
}
