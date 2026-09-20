import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_toast.dart';
import '../cubit/departments_cubit.dart';
import 'department_name_dialog.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Picks an employee's department from the list the admin maintains.
///
/// "No department" is always offered, and is the default. A site with one
/// department has nothing to set up: they leave the list empty and every
/// employee is filed the same way, exactly as before this existed.
///
/// [value] is the department name, not an id — that is how it is stored on the
/// employee, and how every report and export reads it. An empty string is no
/// department.
class DepartmentPickerField extends StatelessWidget {
  const DepartmentPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // The form holds its own DepartmentsCubit, separate from the one the
    // departments screen has, so a name refused here — a duplicate, usually —
    // has nowhere else to be reported.
    return BlocConsumer<DepartmentsCubit, DepartmentsState>(
      listenWhen: (p, c) => p.errorKey != c.errorKey,
      listener: (context, state) {
        if (state.errorKey != null) {
          AppToast.error(context, state.errorKey!.tr());
        }
      },
      builder: (context, state) {
        final names = state.names;

        // The employee's own department, if it was removed from the list while
        // this form was open. Offered rather than silently swapped for "none":
        // saving would otherwise move somebody out of their department without
        // anybody choosing to.
        final options = [
          ...names,
          if (value.isNotEmpty && !names.contains(value)) value,
        ];

        return Row(
          children: [
            Expanded(child: _dropdown(context, options)),
            const SizedBox(width: 8),
            // Adding one from here rather than sending the admin to the
            // departments screen and back: a missing department is usually only
            // noticed while filling this form in.
            IconButton(
              onPressed: () async {
                final added = await showDepartmentNameDialog(context);
                if (added != null) onChanged(added);
              },
              tooltip: LangKeys.departmentAdd.tr(),
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
  /// form field keeps a selection of its own — so a department added from the
  /// button beside it would not show up as chosen.
  Widget _dropdown(BuildContext context, List<String> options) {
    final theme = Theme.of(context);
    final faded = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        prefixIcon: Icon(Icons.apartment, size: 18, color: faded),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: _border(theme.dividerColor),
        enabledBorder: _border(theme.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          // The empty string is the "no department" entry, not a missing
          // value, so the field always has a selection.
          value: options.contains(value) ? value : '',
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 20),
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          items: [
            DropdownMenuItem(
              value: '',
              child: _text(LangKeys.departmentNone.tr(), color: faded),
            ),
            for (final name in options)
              DropdownMenuItem(value: name, child: _text(name)),
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

  /// Department names are typed by hand and run long; the field is narrow.
  static Widget _text(String value, {Color? color}) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 14, color: color),
  );
}
