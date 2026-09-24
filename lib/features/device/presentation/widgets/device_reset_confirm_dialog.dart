import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../data/data_source/zk_device_data_source.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Asks before wiping or rebooting the terminal, and says plainly what goes.
///
/// The reassurance line matters as much as the warning: an admin reading
/// "reset the device" can reasonably fear it means the attendance history, and
/// hesitating over a button that only clears the terminal's own memory is a
/// worse outcome than the wipe itself.
Future<bool> showDeviceResetConfirmDialog(
  BuildContext context,
  ZkResetAction action,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _DeviceResetConfirmDialog(action: action),
  );
  return confirmed == true;
}

class _DeviceResetConfirmDialog extends StatelessWidget {
  const _DeviceResetConfirmDialog({required this.action});

  final ZkResetAction action;

  bool get _isDestructive => action != ZkResetAction.restart;

  String get _titleKey => switch (action) {
    ZkResetAction.attendanceLog => LangKeys.deviceResetLog,
    ZkResetAction.enrolledUsers => LangKeys.deviceResetUsers,
    ZkResetAction.everything => LangKeys.deviceResetAll,
    ZkResetAction.restart => LangKeys.deviceRestart,
  };

  String get _hintKey => switch (action) {
    ZkResetAction.attendanceLog => LangKeys.deviceResetLogHint,
    ZkResetAction.enrolledUsers => LangKeys.deviceResetUsersHint,
    ZkResetAction.everything => LangKeys.deviceResetAllHint,
    ZkResetAction.restart => LangKeys.deviceRestartHint,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _isDestructive
        ? context.color.destructive
        : context.color.primary;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _isDestructive ? Icons.warning_amber : Icons.restart_alt,
                size: 28,
                color: context.color.primaryForeground,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isDestructive
                  ? LangKeys.deviceResetConfirmTitle.tr()
                  : _titleKey.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _hintKey.tr(),
              style: TextStyle(
                fontSize: 12,
                color: context.color.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            if (_isDestructive) ...[
              const SizedBox(height: 12),
              _note(
                context,
                LangKeys.deviceResetIrreversible.tr(),
                context.color.warningSoft,
              ),
              const SizedBox(height: 8),
              _note(
                context,
                LangKeys.deviceResetKeepsLocal.tr(),
                context.color.success,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(LangKeys.cancel.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: MaterialButton(
                      onPressed: () => Navigator.pop(context, true),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        LangKeys.confirm.tr(),
                        style: TextStyle(
                          color: context.color.primaryForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(BuildContext context, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
}
