import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/backup_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Confirms replacing the live database with a chosen backup.
///
/// The path is shown in full and selectable. Backups are named by timestamp,
/// so the filename is the only thing telling two of them apart — and picking
/// yesterday's instead of this morning's is the mistake this dialog exists to
/// catch.
class BackupRestoreConfirmDialog extends StatelessWidget {
  const BackupRestoreConfirmDialog({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.settings_backup_restore,
            size: 20,
            color: context.color.warning,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(LangKeys.backupRestoreConfirmTitle.tr())),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                path,
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 12),
              Text(
                LangKeys.backupRestoreConfirmMsg.tr(),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              // The reason this is recoverable, said where the decision is
              // being made rather than only on the card behind it.
              Text(
                LangKeys.backupRestoreRollback.tr(),
                style: TextStyle(fontSize: 11, color: context.color.success),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LangKeys.cancel.tr()),
        ),
        TextButton(
          onPressed: () {
            final cubit = context.read<BackupCubit>();
            Navigator.pop(context);
            cubit.restore(path);
          },
          child: Text(
            LangKeys.confirm.tr(),
            style: TextStyle(color: context.color.destructive),
          ),
        ),
      ],
    );
  }
}

Future<void> showBackupRestoreConfirmDialog(
  BuildContext context,
  String path,
) {
  final cubit = context.read<BackupCubit>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: BackupRestoreConfirmDialog(path: path),
    ),
  );
}
