import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../data/models/shift_model.dart';
import '../cubit/shifts_cubit.dart';

/// Confirms deleting a shift, and says plainly what happens to the people on
/// it — they go back to the default work hours, they are not deleted with it.
Future<void> showShiftDeleteDialog(
  BuildContext context,
  ShiftModel shift,
) async {
  final cubit = context.read<ShiftsCubit>();

  final confirmed = await showAppConfirmDialog(
    context,
    title: LangKeys.shiftDeleteTitle.tr(),
    message:
        '"${shift.name}" (${shift.hours}) — '
        '${LangKeys.shiftDeleteMsg.tr()}',
    cancelLabel: LangKeys.adminCancel.tr(),
    // The part an admin cannot see from the list alone, and the reason this is
    // a confirmation rather than a plain delete: those people start being
    // judged by different hours the moment it happens.
    warning: shift.inUse > 0
        ? LangKeys.shiftDeleteMoves.tr(args: ['${shift.inUse}'])
        : null,
  );
  if (confirmed) cubit.remove(shift);
}
