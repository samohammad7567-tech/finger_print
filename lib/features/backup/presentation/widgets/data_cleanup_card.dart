import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/backup_cubit.dart';
import 'data_cleanup_action_row.dart';
import 'data_erase_confirm_dialog.dart';
import 'data_purge_confirm_dialog.dart';
import '../../../../core/style/theme/context_extension.dart';

/// The two ways of deleting in bulk, last on the screen.
///
/// Below the backup and the figures, for the same reason the terminal's wipe
/// sits at the bottom of the device screen: it is the only part of this page
/// that destroys anything, and everything an admin would reach for first comes
/// above it. Narrower before wider — a date cut is the one people actually
/// want; the full erase is there for starting an install over.
class DataCleanupCard extends StatelessWidget {
  const DataCleanupCard({super.key, required this.state});

  final BackupState state;

  @override
  Widget build(BuildContext context) {
    final busy = state.isBusy;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LangKeys.dataTitle.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DataCleanupActionRow(
            icon: Icons.auto_delete_outlined,
            label: LangKeys.dataClearBefore,
            hint: LangKeys.dataClearBeforeHint,
            color: context.color.warning,
            enabled: !busy,
            onTap: () => _clearBefore(context),
          ),
          Divider(
            height: 24,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
          DataCleanupActionRow(
            icon: Icons.delete_forever_outlined,
            label: LangKeys.dataErase,
            hint: LangKeys.dataEraseHint,
            color: context.color.destructive,
            enabled: !busy,
            onTap: () => _eraseAll(context),
          ),
          if (state.isClearing) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  LangKeys.dataClearing.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.color.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Pick the cut-off, then confirm it. The picker opens on the oldest record
  /// rather than today, so the admin is choosing inside the history they
  /// actually have.
  Future<void> _clearBefore(BuildContext context) async {
    final cubit = context.read<BackupCubit>();
    final now = DateTime.now();
    final oldest =
        DateTime.tryParse(state.footprint?.oldestAttendanceDate ?? '') ??
        DateTime(now.year - 1, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: oldest,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: LangKeys.dataChooseDate.tr(),
    );
    if (picked == null || !context.mounted) return;

    // The database stores dates as yyyy-MM-dd text, and the purge compares
    // against them as strings — so the cut-off is built the same way.
    final date =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';

    if (await showDataPurgeConfirmDialog(context, date)) {
      await cubit.clearBefore(date);
    }
  }

  Future<void> _eraseAll(BuildContext context) async {
    final cubit = context.read<BackupCubit>();
    if (await showDataEraseConfirmDialog(context)) {
      await cubit.eraseAll();
    }
  }
}
