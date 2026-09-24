import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/data_source/zk_device_data_source.dart';
import '../cubit/device_cubit.dart';
import '../cubit/device_state.dart';
import 'device_reset_confirm_dialog.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Clearing what the terminal stores, and rebooting it.
///
/// Last on the device screen on purpose: it is the only card here that destroys
/// anything, and it sits below everything an admin would try first.
class DeviceResetCard extends StatelessWidget {
  const DeviceResetCard({super.key, required this.state});

  final DeviceState state;

  /// Mildest first. The reboot leads because it is what an admin facing a stuck
  /// terminal should reach for before any of the wipes.
  static const _actions = <ZkResetAction>[
    ZkResetAction.restart,
    ZkResetAction.attendanceLog,
    ZkResetAction.enrolledUsers,
    ZkResetAction.everything,
  ];

  @override
  Widget build(BuildContext context) {
    final enabled = state.settings.isConfigured && !state.isBusy;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_outlined,
                size: 18,
                color: context.color.destructive,
              ),
              const SizedBox(width: 8),
              Text(
                LangKeys.deviceMaintenance.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            LangKeys.deviceMaintenanceHint.tr(),
            style: TextStyle(
              fontSize: 11,
              color: context.color.mutedForeground,
            ),
          ),
          for (final action in _actions) ...[
            Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
            _ResetRow(action: action, state: state, enabled: enabled),
          ],
        ],
      ),
    );
  }
}

/// One maintenance action. The whole row is the button — the consequence is
/// long enough that a separate label beside it would only repeat the title.
class _ResetRow extends StatelessWidget {
  const _ResetRow({
    required this.action,
    required this.state,
    required this.enabled,
  });

  final ZkResetAction action;
  final DeviceState state;
  final bool enabled;

  bool get _isDestructive => action != ZkResetAction.restart;

  @override
  Widget build(BuildContext context) {
    final running = state.resettingAction == action;
    final accent = _isDestructive
        ? context.color.destructive
        : context.color.primary;
    final view = _viewFor(action);
    final dimmed = !enabled && !running;

    return InkWell(
      onTap: enabled ? () => _confirmAndRun(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              view.icon,
              size: 18,
              color: dimmed ? context.color.subtleForeground : accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.label.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dimmed ? context.color.subtleForeground : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    running ? LangKeys.deviceResetRunning.tr() : view.hint.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: running ? accent : context.color.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (running)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 18,
                color: dimmed ? context.color.subtleForeground : accent,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndRun(BuildContext context) async {
    final cubit = context.read<DeviceCubit>();
    if (await showDeviceResetConfirmDialog(context, action)) {
      await cubit.resetDevice(action);
    }
  }

  /// The icon, title and one-line consequence each action shows.
  static ({IconData icon, String label, String hint}) _viewFor(
    ZkResetAction action,
  ) => switch (action) {
    ZkResetAction.restart => (
      icon: Icons.restart_alt,
      label: LangKeys.deviceRestart,
      hint: LangKeys.deviceRestartHint,
    ),
    ZkResetAction.attendanceLog => (
      icon: Icons.delete_sweep_outlined,
      label: LangKeys.deviceResetLog,
      hint: LangKeys.deviceResetLogHint,
    ),
    ZkResetAction.enrolledUsers => (
      icon: Icons.person_remove_outlined,
      label: LangKeys.deviceResetUsers,
      hint: LangKeys.deviceResetUsersHint,
    ),
    ZkResetAction.everything => (
      icon: Icons.settings_backup_restore,
      label: LangKeys.deviceResetAll,
      hint: LangKeys.deviceResetAllHint,
    ),
  };
}
