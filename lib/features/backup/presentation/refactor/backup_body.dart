import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/backup_cubit.dart';
import '../widgets/backup_actions_card.dart';
import '../widgets/backup_footprint_card.dart';
import '../widgets/backup_path_card.dart';
import '../widgets/backup_restore_confirm_dialog.dart';
import '../widgets/data_cleanup_card.dart';
import '../../../../core/style/theme/context_extension.dart';

class BackupBody extends StatelessWidget {
  const BackupBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BackupCubit, BackupState>(
      listenWhen: (previous, current) =>
          previous.error != current.error ||
          previous.message != current.message ||
          previous.pendingRestorePath != current.pendingRestorePath,
      listener: (context, state) {
        final error = state.error;
        if (error != null) AppToast.error(context, error.tr());

        final message = state.message;
        if (message != null) AppToast.success(context, _successText(state));

        // A backup chosen but not yet applied. The confirmation names the file
        // so a restore of the wrong one is caught here rather than discovered
        // afterwards, when the database it replaced is already gone.
        final pending = state.pendingRestorePath;
        if (pending != null) showBackupRestoreConfirmDialog(context, pending);
      },
      builder: (context, state) {
        final footprint = state.footprint;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.backupTitle.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: context.color.warningSoft,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LangKeys.backupHint.tr(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (state.databasePath != null)
                BackupPathCard(label: 'Database', path: state.databasePath!),
              if (state.lastBackupPath != null) ...[
                const SizedBox(height: 12),
                BackupPathCard(
                  label: LangKeys.backupDone.tr(),
                  path: state.lastBackupPath!,
                ),
              ],
              const SizedBox(height: 16),
              BackupActionsCard(state: state),
              if (footprint != null) ...[
                const SizedBox(height: 16),
                BackupFootprintCard(footprint: footprint),
              ],
              const SizedBox(height: 16),
              DataCleanupCard(state: state),
            ],
          ),
        );
      },
    );
  }

  /// A purge reports what it removed rather than only that it finished: the
  /// figures are how an admin tells "cleared six months" from "matched
  /// nothing", and the freed space is usually why they pressed it.
  static String _successText(BackupState state) {
    final base = state.message!.tr();

    // A restore leaves every other screen in the app reading the data it
    // loaded before. Nothing here can reach in and refresh them, so the toast
    // says so rather than letting the admin act on stale figures.
    if (state.message == LangKeys.backupRestoreDone) {
      return '$base · ${LangKeys.backupRestartHint.tr()}';
    }

    final purge = state.purgeResult;
    if (purge == null || purge.removedNothing) return base;

    return [
      base,
      '${LangKeys.dataRemovedDays.tr()}: ${purge.attendanceRemoved}',
      '${LangKeys.dataRemovedPunches.tr()}: ${purge.punchesRemoved}',
      if (purge.bytesFreed > 0)
        '${LangKeys.dataFreed.tr()}: ${purge.freedMb} MB',
    ].join(' · ');
  }
}
