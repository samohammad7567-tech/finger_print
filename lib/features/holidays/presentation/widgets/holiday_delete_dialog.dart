import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../data/models/holiday_model.dart';
import '../cubit/holidays_cubit.dart';

/// Confirms deleting a holiday, and says what it means: those dates start
/// counting as ordinary working days again, in every report.
Future<void> showHolidayDeleteDialog(
  BuildContext context,
  HolidayModel holiday,
) async {
  final cubit = context.read<HolidaysCubit>();

  final confirmed = await showAppConfirmDialog(
    context,
    title: LangKeys.holidayDeleteTitle.tr(),
    message:
        '"${holiday.name}" — '
        '${LangKeys.holidayDays.tr(args: ['${holiday.dayCount}'])}',
    cancelLabel: LangKeys.adminCancel.tr(),
    warning: LangKeys.holidayDeleteMsg.tr(),
  );
  if (confirmed) cubit.remove(holiday);
}
