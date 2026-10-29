import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../cubit/employee_management_cubit.dart';

/// Confirms deleting an employee, and warns that their enrolment goes too.
///
/// Clearing the fingerprint is not obvious from the button and is not
/// reversible — the person would have to stand at the terminal and scan again.
Future<void> showDeleteConfirmDialog(
  BuildContext context,
  EmployeeModel employee,
) async {
  final cubit = context.read<EmployeeManagementCubit>();
  final enrolled = (employee.deviceUserId ?? '').isNotEmpty;

  final confirmed = await showAppConfirmDialog(
    context,
    title: LangKeys.adminConfirmDelete.tr(),
    message: '${LangKeys.adminDeleteMsg.tr()} "${employee.fullName}"?',
    cancelLabel: LangKeys.adminCancel.tr(),
    warning: enrolled ? LangKeys.deleteAlsoRemovesFingerprint.tr() : null,
  );
  if (!confirmed) return;

  final clearedFromDevice = await cubit.deleteEmployee(employee.id);

  // The employee is gone either way; this only reports whether the terminal
  // let go of the fingerprint.
  if (!clearedFromDevice && enrolled && context.mounted) {
    AppToast.error(context, LangKeys.deleteDeviceUnreachable.tr());
  }
}
