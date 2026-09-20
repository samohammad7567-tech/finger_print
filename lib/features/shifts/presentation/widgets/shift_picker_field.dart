import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_toast.dart';
import '../cubit/shifts_cubit.dart';
import 'shift_form_sheet.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Picks the shift an employee is judged by, from the list the admin maintains.
///
/// Once any shift exists, choosing one is required and the field opens empty:
/// a company that has bothered to define its working days wants each person
/// filed under one, and silently defaulting them would be a decision the app
/// made rather than the admin.
///
/// Until then the field offers the default work hours and nothing else, so a
/// site running one working day has nothing to set up — they leave the list
/// empty and every employee is judged the same way, exactly as before shifts
/// existed.
///
/// [value] is the shift id, empty for the default hours — that is how it is
/// stored on the employee, and how the fold and every report resolve it.
class ShiftPickerField extends StatelessWidget {
  const ShiftPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // The form holds its own ShiftsCubit, separate from the one the shifts
    // screen has, so a shift refused here — a duplicate name, usually — has
    // nowhere else to be reported.
    return BlocConsumer<ShiftsCubit, ShiftsState>(
      listenWhen: (p, c) => p.errorKey != c.errorKey,
      listener: (context, state) {
        if (state.errorKey != null) {
          AppToast.error(context, state.errorKey!.tr());
        }
      },
      builder: (context, state) {
        final ids = [for (final shift in state.shifts) shift.id];

        return Row(
          children: [
            Expanded(child: _dropdown(context, state, ids)),
            const SizedBox(width: 8),
            // Adding one from here rather than sending the admin to the shifts
            // screen and back: a missing shift is usually only noticed while
            // filling this form in.
            IconButton(
              onPressed: () async {
                final added = await showShiftFormSheet(context);
                if (added != null) onChanged(added);
              },
              tooltip: LangKeys.shiftAdd.tr(),
              icon: Icon(
                Icons.add_circle_outline,
                size: 22,
                color: context.color.primary,
              ),
            ),
          ],
        );
      },
    );
  }

  /// An [InputDecorator] around a plain [DropdownButton] rather than a
  /// `DropdownButtonFormField`: this field is driven entirely by [value], and a
  /// form field keeps a selection of its own — so a shift added from the button
  /// beside it would not show up as chosen.
  Widget _dropdown(BuildContext context, ShiftsState state, List<String> ids) {
    final theme = Theme.of(context);
    final faded = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final schedule = state.companyDefault;

    // Still loading, or genuinely none set up. Either way there is nothing to
    // choose between yet, so the default hours are the only honest entry.
    final defaultIsAnOption = state.shifts.isEmpty;

    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        prefixIcon: Icon(Icons.access_time, size: 18, color: faded),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: _border(theme.dividerColor),
        enabledBorder: _border(theme.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          // Null shows the hint rather than a selection — an employee with no
          // shift at a site that has some has not been filed yet, and the
          // field should say so instead of looking answered. A shift deleted
          // while this form was open lands here too, which is exactly where
          // the employee now stands.
          value: ids.contains(value) ? value : (defaultIsAnOption ? '' : null),
          hint: _text(LangKeys.shiftChoose.tr(), color: faded),
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 20),
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          items: [
            if (defaultIsAnOption)
              DropdownMenuItem(
                value: '',
                child: _text(
                  '${LangKeys.shiftDefault.tr()}'
                  '  ·  ${schedule.workStart} – ${schedule.workEnd}',
                  color: faded,
                ),
              ),
            for (final shift in state.shifts)
              DropdownMenuItem(
                value: shift.id,
                // The hours beside the name: two shifts called "Gate" and
                // "Gate 2" are told apart by when they run, not by what they
                // are called.
                child: _text('${shift.name}  ·  ${shift.hours}'),
              ),
          ],
          onChanged: (selected) => onChanged(selected ?? ''),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );

  /// Shift names are typed by hand and carry their hours; the field is narrow.
  static Widget _text(String value, {Color? color}) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 14, color: color),
  );
}
