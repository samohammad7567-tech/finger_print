import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/device_cubit.dart';
import '../cubit/device_state.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Whether the terminal answers, and what it says about itself.
class DeviceStatusCard extends StatelessWidget {
  const DeviceStatusCard({super.key, required this.state});

  final DeviceState state;

  @override
  Widget build(BuildContext context) {
    final info = state.connection;
    final cubit = context.read<DeviceCubit>();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                info == null ? Icons.usb_off : Icons.usb,
                size: 18,
                color: info == null
                    ? context.color.subtleForeground
                    : context.color.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.settings.isConfigured
                      ? '${state.settings.ip}:${state.settings.port}'
                      : LangKeys.deviceNotConfiguredHint.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (state.isTesting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: state.settings.isConfigured && !state.isBusy
                      ? cubit.testConnection
                      : null,
                  child: Text(
                    LangKeys.deviceTestConnection.tr(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          if (info != null) ...[
            const Divider(height: 20),
            _row(context, LangKeys.deviceName.tr(), info.deviceName),
            _row(context, LangKeys.deviceSerial.tr(), info.serialNumber),
            _row(context, LangKeys.deviceFirmware.tr(), info.firmware),
            _row(
              context,
              LangKeys.deviceClock.tr(),
              info.deviceTime == null
                  ? null
                  : DateFormat('yyyy-MM-dd HH:mm').format(info.deviceTime!),
            ),
            _clockWarning(context, info.clockDrift, cubit),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// A terminal with a drifted clock files punches under the wrong time, and
  /// past midnight under the wrong day, so this is worth shouting about.
  Widget _clockWarning(
    BuildContext context,
    Duration? drift,
    DeviceCubit cubit,
  ) {
    if (drift == null || drift.inMinutes < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: context.color.warningSoft),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              LangKeys.deviceClockDrift.tr(args: ['${drift.inMinutes} min']),
              style: TextStyle(fontSize: 11, color: context.color.warningSoft),
            ),
          ),
          TextButton(
            onPressed: cubit.syncDeviceClock,
            child: Text(
              LangKeys.deviceSyncClock.tr(),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
