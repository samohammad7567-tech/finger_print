import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/department_model.dart';
import '../cubit/departments_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Adds a department, or renames [department] when one is given.
///
/// Returns the name that was stored, so a caller mid-way through another form —
/// the employee sheet — can select the department it just created. Returns null
/// when the admin backed out or the name was refused.
Future<String?> showDepartmentNameDialog(
  BuildContext context, {
  DepartmentModel? department,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<DepartmentsCubit>(),
      child: _DepartmentNameDialog(department: department),
    ),
  );
}

class _DepartmentNameDialog extends StatefulWidget {
  const _DepartmentNameDialog({this.department});
  final DepartmentModel? department;

  @override
  State<_DepartmentNameDialog> createState() => _DepartmentNameDialogState();
}

class _DepartmentNameDialogState extends State<_DepartmentNameDialog> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.department?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);

    final cubit = context.read<DepartmentsCubit>();
    final existing = widget.department;
    final saved = existing == null
        ? await cubit.add(_nameCtrl.text)
        : await cubit.rename(existing, _nameCtrl.text);

    if (!mounted) return;
    // Null means the name was refused — a duplicate, most often. The dialog
    // stays open with the text still in it so the admin can correct it rather
    // than type it again.
    if (saved == null) {
      setState(() => _saving = false);
      return;
    }
    Navigator.pop(context, saved);
  }

  bool get _canSave => !_saving && _nameCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isRename = widget.department != null;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (isRename ? LangKeys.departmentRename : LangKeys.departmentAdd)
                  .tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _nameCtrl,
              hint: LangKeys.departmentName.tr(),
              prefixIcon: Icons.apartment,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _actions(context),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(LangKeys.adminCancel.tr()),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: _canSave ? context.color.primary : context.color.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: MaterialButton(
            onPressed: _canSave ? _submit : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.color.primaryForeground,
                    ),
                  )
                : Text(
                    LangKeys.adminSave.tr(),
                    style: TextStyle(
                      color: context.color.primaryForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    ],
  );
}
