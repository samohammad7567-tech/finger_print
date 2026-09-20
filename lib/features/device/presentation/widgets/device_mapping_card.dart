import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/device_cubit.dart';
import '../cubit/device_state.dart';
import 'device_employee_picker.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Device user ids seen in the punch log with no employee behind them.
///
/// Punches for these ids are already stored; mapping one applies its whole
/// history, so nothing is lost by enrolling someone before the admin gets to
/// this screen.
class DeviceMappingCard extends StatelessWidget {
  const DeviceMappingCard({super.key, required this.state});

  final DeviceState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeviceCubit>();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 18, color: context.color.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LangKeys.deviceMapping.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (state.isLoadingUsers)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: state.settings.isConfigured && !state.isBusy
                      ? cubit.loadDeviceUsers
                      : null,
                  child: Text(
                    LangKeys.deviceLoadUsers.tr(),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          Text(
            LangKeys.deviceMappingHint.tr(),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          if (state.unmapped.isEmpty)
            _empty(context)
          else
            ...state.unmapped.map((user) => _tile(context, cubit, user)),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 16,
          color: context.color.primary,
        ),
        const SizedBox(width: 6),
        Text(
          LangKeys.deviceNoUnmapped.tr(),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, DeviceCubit cubit, UnmappedUser user) {
    final name = state.nameForDeviceUser(user.deviceUserId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.color.warningSoft.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${user.deviceUserId}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.color.warningSoft,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name != null)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  LangKeys.devicePunchCount.tr(args: ['${user.punchCount}']),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showDeviceEmployeePicker(
              context: context,
              employees: state.unmappedEmployees,
              onSelected: (employeeId) => cubit.mapDeviceUser(
                employeeId: employeeId,
                deviceUserId: user.deviceUserId,
              ),
            ),
            child: Text(
              LangKeys.deviceMapToEmployee.tr(),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
