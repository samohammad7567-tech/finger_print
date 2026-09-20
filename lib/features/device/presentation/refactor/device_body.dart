import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_toast.dart';
import '../cubit/device_cubit.dart';
import '../cubit/device_state.dart';
import '../widgets/device_connection_form.dart';
import '../widgets/device_mapping_card.dart';
import '../widgets/device_match_review_card.dart';
import '../widgets/device_status_card.dart';
import '../widgets/device_sync_card.dart';

class DeviceBody extends StatelessWidget {
  const DeviceBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeviceCubit, DeviceState>(
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
                LangKeys.deviceTitle.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                LangKeys.deviceSubtitle.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              DeviceStatusCard(state: state),
              const SizedBox(height: 12),
              DeviceSyncCard(state: state),
              const SizedBox(height: 12),
              // Above the mapping list on purpose: these are the people the
              // sync deliberately did not import, so they are the reason a name
              // is missing further down.
              if (state.hasPendingMatches) ...[
                DeviceMatchReviewCard(state: state),
                const SizedBox(height: 12),
              ],
              DeviceMappingCard(state: state),
              const SizedBox(height: 12),
              DeviceConnectionForm(settings: state.settings),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
