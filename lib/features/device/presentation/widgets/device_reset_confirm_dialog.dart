import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../data/data_source/zk_device_data_source.dart';

/// Asks before wiping or rebooting the terminal, and says plainly what goes.
///
/// The reassurance line matters as much as the warning: an admin reading
/// "reset the device" can reasonably fear it means the attendance history, and
/// hesitating over a button that only clears the terminal's own memory is a
/// worse outcome than the wipe itself.
Future<bool> showDeviceResetConfirmDialog(
  BuildContext context,
  ZkResetAction action,
) {
  final isDestructive = action != ZkResetAction.restart;

  final titleKey = switch (action) {
    ZkResetAction.attendanceLog => LangKeys.deviceResetLog,
    ZkResetAction.enrolledUsers => LangKeys.deviceResetUsers,
    ZkResetAction.everything => LangKeys.deviceResetAll,
    ZkResetAction.restart => LangKeys.deviceRestart,
  };

  final hintKey = switch (action) {
    ZkResetAction.attendanceLog => LangKeys.deviceResetLogHint,
    ZkResetAction.enrolledUsers => LangKeys.deviceResetUsersHint,
    ZkResetAction.everything => LangKeys.deviceResetAllHint,
    ZkResetAction.restart => LangKeys.deviceRestartHint,
  };

  return showAppConfirmDialog(
    context,
    title: isDestructive
        ? LangKeys.deviceResetConfirmTitle.tr()
        : titleKey.tr(),
    message: hintKey.tr(),
    confirmLabel: LangKeys.confirm.tr(),
    icon: isDestructive ? Icons.warning_amber : Icons.restart_alt,
    accent: isDestructive ? context.color.destructive : context.color.primary,
    notes: isDestructive
        ? [
            AppConfirmNote(
              LangKeys.deviceResetIrreversible.tr(),
              context.color.warningSoft,
            ),
            AppConfirmNote(
              LangKeys.deviceResetKeepsLocal.tr(),
              context.color.success,
            ),
          ]
        : const [],
  );
}
