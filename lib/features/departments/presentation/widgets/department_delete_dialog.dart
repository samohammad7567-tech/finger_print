import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../data/models/department_model.dart';
import '../cubit/departments_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Confirms deleting a department, and says plainly what happens to the people
/// in it — they are left without one, not deleted with it.
void showDepartmentDeleteDialog(
  BuildContext context,
  DepartmentModel department,
) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<DepartmentsCubit>(),
      child: _DepartmentDeleteDialog(department: department),
    ),
  );
}

class _DepartmentDeleteDialog extends StatelessWidget {
  const _DepartmentDeleteDialog({required this.department});
  final DepartmentModel department;

  @override
  Widget build(BuildContext context) {
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.color.destructive,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.warning_amber,
                size: 28,
                color: context.color.primaryForeground,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              LangKeys.departmentDeleteTitle.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '"${department.name}" — ${LangKeys.departmentDeleteMsg.tr()}',
              style: TextStyle(fontSize: 13, color: faded),
              textAlign: TextAlign.center,
            ),
            // The part an admin cannot see from the list alone, and the reason
            // this is a confirmation rather than a plain delete.
            if (department.inUse > 0) ...[
              const SizedBox(height: 8),
              Text(
                LangKeys.departmentDeleteMoves.tr(
                  args: ['${department.inUse}'],
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: context.color.warningSoft,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Row(
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
                      color: context.color.destructive,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: MaterialButton(
                      onPressed: () {
                        final cubit = context.read<DepartmentsCubit>();
                        Navigator.pop(context);
                        cubit.remove(department);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        LangKeys.adminDelete.tr(),
                        style: TextStyle(
                          color: context.color.primaryForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
