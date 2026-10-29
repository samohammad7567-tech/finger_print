import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../data/models/department_model.dart';
import '../cubit/departments_cubit.dart';

/// Confirms deleting a department, and says plainly what happens to the people
/// in it — they are left without one, not deleted with it.
Future<void> showDepartmentDeleteDialog(
  BuildContext context,
  DepartmentModel department,
) async {
  final cubit = context.read<DepartmentsCubit>();

  final confirmed = await showAppConfirmDialog(
    context,
    title: LangKeys.departmentDeleteTitle.tr(),
    message: '"${department.name}" — ${LangKeys.departmentDeleteMsg.tr()}',
    cancelLabel: LangKeys.adminCancel.tr(),
    // The part an admin cannot see from the list alone, and the reason this is
    // a confirmation rather than a plain delete.
    warning: department.inUse > 0
        ? LangKeys.departmentDeleteMoves.tr(args: ['${department.inUse}'])
        : null,
  );
  if (confirmed) cubit.remove(department);
}
