import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/device_cubit.dart';
import '../cubit/device_state.dart';
import '../../../../core/style/theme/context_extension.dart';

/// The sync action and what the last run did.
class DeviceSyncCard extends StatelessWidget {
  const DeviceSyncCard({super.key, required this.state});

  final DeviceState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeviceCubit>();
    final result = state.lastResult;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isLive) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.color.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  state.lastLivePunchAt == null
                      ? LangKeys.deviceLiveActive.tr()
                      : '${LangKeys.deviceLiveActive.tr()} · '
                            '${DateFormat('HH:mm').format(state.lastLivePunchAt!)}',
                  style: TextStyle(fontSize: 11, color: context.color.success),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Icon(Icons.sync, size: 18, color: context.color.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.lastSync == null
                      ? LangKeys.deviceNeverSynced.tr()
                      : '${LangKeys.deviceLastSync.tr()}: '
                            '${DateFormat('yyyy-MM-dd HH:mm').format(state.lastSync!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            onPressed: state.settings.isConfigured && !state.isBusy
                ? cubit.syncNow
                : null,
            label: state.isSyncing
                ? LangKeys.deviceSyncing.tr()
                : LangKeys.deviceSyncNow.tr(),
            icon: Icons.download,
            isLoading: state.isSyncing,
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _stat(
                  context,
                  LangKeys.devicePunchesRead.tr(),
                  result.punchesRead,
                ),
                _stat(
                  context,
                  LangKeys.devicePunchesNew.tr(),
                  result.punchesNew,
                ),
                _stat(
                  context,
                  LangKeys.deviceRecordsWritten.tr(),
                  result.recordsWritten,
                ),
                if (result.employeesImported > 0)
                  _stat(
                    context,
                    LangKeys.deviceEmployeesImported.tr(),
                    result.employeesImported,
                  ),
                if (result.employeesPendingReview > 0)
                  _stat(
                    context,
                    LangKeys.deviceEmployeesPending.tr(),
                    result.employeesPendingReview,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
