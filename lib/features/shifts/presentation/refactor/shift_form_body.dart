import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/work_schedule.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../widgets/shift_hours_fields.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Everything on the shift form: its name, the four values the admin sets, and
/// what they come to.
///
/// Split from the sheet that owns them so the sheet stays about behaviour —
/// what is on the form, whether it can be saved, what happens when it is — and
/// this stays about layout. It holds no state: every value is passed in and
/// every change handed back.
class ShiftFormBody extends StatelessWidget {
  const ShiftFormBody({
    super.key,
    required this.isEditing,
    required this.nameController,
    required this.startWork,
    required this.endWork,
    required this.lateGrace,
    required this.earlyOutGrace,
    required this.restDays,
    required this.schedule,
    required this.showInvalidHours,
    required this.isSaving,
    required this.onNameChanged,
    required this.onStartWork,
    required this.onEndWork,
    required this.onLateGrace,
    required this.onEarlyOutGrace,
    required this.onRestDays,
    required this.onSave,
  });

  final bool isEditing;
  final TextEditingController nameController;

  final String startWork;
  final String endWork;
  final int lateGrace;
  final int earlyOutGrace;
  final Set<int> restDays;

  /// What these four values come to once the company default has supplied the
  /// overtime window — the day this shift actually means.
  final WorkSchedule schedule;

  /// True when the hours cannot be worked and the admin has got far enough
  /// into the form to be told so rather than scolded for a blank field.
  final bool showInvalidHours;

  final bool isSaving;

  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onStartWork;
  final ValueChanged<String> onEndWork;
  final ValueChanged<int> onLateGrace;
  final ValueChanged<int> onEarlyOutGrace;
  final ValueChanged<Set<int>> onRestDays;

  /// Null while the form cannot be saved, which is also what disables the
  /// button.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _hint(context, LangKeys.shiftName.tr(), size: 12),
        ),
        AppTextField(
          controller: nameController,
          hint: LangKeys.shiftNameHint.tr(),
          prefixIcon: Icons.access_time,
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 14),
        ShiftHoursFields(
          startWork: startWork,
          endWork: endWork,
          lateGrace: lateGrace,
          earlyOutGrace: earlyOutGrace,
          onStartWork: onStartWork,
          onEndWork: onEndWork,
          onLateGrace: onLateGrace,
          onEarlyOutGrace: onEarlyOutGrace,
          restDays: restDays,
          onRestDays: onRestDays,
        ),
        const SizedBox(height: 6),
        _hint(
          context,
          restDays.isEmpty
              ? LangKeys.restDaysNone.tr()
              : LangKeys.restDaysHint.tr(),
        ),
        const SizedBox(height: 10),
        _hint(context, LangKeys.shiftGraceHint.tr()),
        // The overtime window is not asked for — it follows the company
        // setting by the same distance it sits from the default day. Shown so
        // that is a fact the admin can see rather than a surprise on a payroll
        // run.
        _hint(
          context,
          LangKeys.shiftOvertimeDerived.tr(
            args: [schedule.overtimeStart, schedule.overtimeEnd],
          ),
        ),
        if (showInvalidHours) ...[
          const SizedBox(height: 10),
          Text(
            LangKeys.errorShiftInvalidHours.tr(),
            style: TextStyle(fontSize: 11, color: context.color.destructive),
          ),
        ],
        const SizedBox(height: 18),
        AppPrimaryButton(
          onPressed: onSave,
          label: LangKeys.adminSave.tr(),
          icon: Icons.check,
          isLoading: isSaving,
        ),
      ],
    );
  }

  Widget _header(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        (isEditing ? LangKeys.shiftEdit : LangKeys.shiftAdd).tr(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      IconButton(
        icon: const Icon(Icons.close, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );

  Widget _hint(BuildContext context, String text, {double size = 11}) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      height: 1.4,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    ),
  );
}
