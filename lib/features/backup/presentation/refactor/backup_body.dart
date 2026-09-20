import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/backup_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class BackupBody extends StatelessWidget {
  const BackupBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BackupCubit, BackupState>(
      listenWhen: (previous, current) =>
          previous.error != current.error ||
          previous.message != current.message,
      listener: (context, state) {
        final error = state.error;
        final message = state.message;
        if (error != null) AppToast.error(context, error.tr());
        if (message != null) AppToast.success(context, message.tr());
      },
      builder: (context, state) {
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
                _pathCard(context, 'Database', state.databasePath!),
              if (state.lastBackupPath != null) ...[
                const SizedBox(height: 12),
                _pathCard(
                  context,
                  LangKeys.backupDone.tr(),
                  state.lastBackupPath!,
                ),
              ],
              const SizedBox(height: 16),
              AppPrimaryButton(
                onPressed: state.isSaving
                    ? null
                    : context.read<BackupCubit>().backupNow,
                label: LangKeys.backupNow.tr(),
                icon: Icons.save_alt,
                isLoading: state.isSaving,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pathCard(BuildContext context, String label, String path) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(path, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
