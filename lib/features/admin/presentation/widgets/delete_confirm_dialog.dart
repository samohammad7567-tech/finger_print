import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../cubit/employee_management_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

void showDeleteConfirmDialog(BuildContext context, EmployeeModel employee) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<EmployeeManagementCubit>(),
      child: _DeleteConfirmDialog(employee: employee),
    ),
  );
}

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
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
              LangKeys.adminConfirmDelete.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${LangKeys.adminDeleteMsg.tr()} "${employee.fullName}"?',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            // Deleting also clears their enrolment, which is not obvious and is
            // not reversible — they would have to scan their finger again.
            if ((employee.deviceUserId ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                LangKeys.deleteAlsoRemovesFingerprint.tr(),
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
                      onPressed: () async {
                        final cubit = context.read<EmployeeManagementCubit>();
                        final messenger = context;
                        Navigator.pop(context);

                        final clearedFromDevice = await cubit.deleteEmployee(
                          employee.id,
                        );

                        // The employee is gone either way; this only reports
                        // whether the terminal let go of the fingerprint.
                        if (!clearedFromDevice &&
                            (employee.deviceUserId ?? '').isNotEmpty &&
                            messenger.mounted) {
                          AppToast.error(
                            messenger,
                            LangKeys.deleteDeviceUnreachable.tr(),
                          );
                        }
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
