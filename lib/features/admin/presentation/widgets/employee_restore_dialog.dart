import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/employee_management_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Explains a fetch that found people on the terminal and imported none of
/// them, and offers the only thing that can fix it.
///
/// Deleting an employee records that their terminal id is not to come back, or
/// the next automatic sync would undo the deletion the moment it ran. That rule
/// is right and stays. What was missing is the way out of it: an admin who
/// clears the staff list and then presses "From device" is asking for those
/// people, and until now got a silent zero with no way to say "no, really".
class EmployeeRestoreDialog extends StatefulWidget {
  const EmployeeRestoreDialog({super.key, required this.outcome});

  final DeviceFetchOutcome outcome;

  @override
  State<EmployeeRestoreDialog> createState() => _EmployeeRestoreDialogState();
}

Future<void> showEmployeeRestoreDialog(
  BuildContext context,
  DeviceFetchOutcome outcome,
) {
  final cubit = context.read<EmployeeManagementCubit>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: EmployeeRestoreDialog(outcome: outcome),
    ),
  );
}

class _EmployeeRestoreDialogState extends State<EmployeeRestoreDialog> {
  late final Set<String> _selected = {
    for (final user in widget.outcome.deleted) user.deviceUserId,
  };

  @override
  Widget build(BuildContext context) {
    final deleted = widget.outcome.deleted;
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.restore_from_trash_outlined,
            size: 20,
            color: context.color.warningSoft,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(LangKeys.restoreTitle.tr())),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LangKeys.restoreHint.tr(
                args: ['${widget.outcome.readFromDevice}', '${deleted.length}'],
              ),
              style: TextStyle(fontSize: 12, color: faded),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final user in deleted)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selected.contains(user.deviceUserId),
                        onChanged: (on) => setState(() {
                          if (on ?? false) {
                            _selected.add(user.deviceUserId);
                          } else {
                            _selected.remove(user.deviceUserId);
                          }
                        }),
                        title: Text(
                          user.name.isEmpty
                              ? LangKeys.deviceMatchNoName.tr()
                              : user.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '#${user.deviceUserId}',
                          style: TextStyle(fontSize: 11, color: faded),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LangKeys.cancel.tr()),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () {
                  final ids = _selected.toList();
                  Navigator.pop(context);
                  context
                      .read<EmployeeManagementCubit>()
                      .restoreDeletedDeviceUsers(ids);
                },
          child: Text(LangKeys.restoreAction.tr(args: ['${_selected.length}'])),
        ),
      ],
    );
  }
}
