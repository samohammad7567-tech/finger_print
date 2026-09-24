import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/backup_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Taking a copy, and putting one back.
///
/// The two sit together on purpose: a restore is only ever as good as the last
/// backup, and an admin about to replace their database should be looking
/// straight at the button that would have saved them.
class BackupActionsCard extends StatelessWidget {
  const BackupActionsCard({super.key, required this.state});

  final BackupState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BackupCubit>();
    final busy = state.isBusy;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPrimaryButton(
            onPressed: busy ? null : cubit.backupNow,
            label: LangKeys.backupNow.tr(),
            icon: Icons.save_alt,
            isLoading: state.isSaving,
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            LangKeys.backupRestore.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            LangKeys.backupRestoreHint.tr(),
            style: TextStyle(fontSize: 11, color: context.color.mutedForeground),
          ),
          const SizedBox(height: 4),
          // Said here rather than only in the dialog: it is the fact that makes
          // trying a restore reasonable at all.
          Text(
            LangKeys.backupRestoreRollback.tr(),
            style: TextStyle(fontSize: 11, color: context.color.success),
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            onPressed: busy
                ? null
                : () => cubit.chooseBackupToRestore(
                    typeLabel: LangKeys.backupRestoreFileType.tr(),
                    confirmLabel: LangKeys.backupRestorePick.tr(),
                  ),
            label: state.isRestoring
                ? LangKeys.backupRestoring.tr()
                : LangKeys.backupRestore.tr(),
            icon: Icons.settings_backup_restore,
            isLoading: state.isRestoring,
            color: context.color.warning,
          ),
        ],
      ),
    );
  }
}
