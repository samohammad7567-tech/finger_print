import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/enrollment_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// The fingerprint section of the employee form.
///
/// Enrolment is a two-handed operation: the app puts the terminal into capture
/// mode, the person presses their finger on the *device*, and then the admin
/// confirms here so the app can verify a template landed.
class EmployeeFingerprintField extends StatelessWidget {
  const EmployeeFingerprintField({super.key, required this.nameOf});

  /// Read lazily — the admin usually types the name after opening the sheet.
  final String Function() nameOf;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnrollmentCubit, EnrollmentState>(
      builder: (context, state) {
        final cubit = context.read<EnrollmentCubit>();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    state.isEnrolled
                        ? Icons.fingerprint
                        : Icons.fingerprint_outlined,
                    size: 20,
                    color: state.isEnrolled
                        ? context.color.success
                        : context.color.subtleForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _summary(context, state)),
                  if (state.isBusy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              if (state.isWaiting) ...[
                const SizedBox(height: 10),
                _waitingPanel(context, cubit),
              ] else ...[
                const SizedBox(height: 10),
                _actionButton(context, state, cubit),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.error!.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.color.destructive,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _summary(BuildContext context, EnrollmentState state) {
    final label = switch (state.stage) {
      EnrollmentStage.preparing => LangKeys.enrollPreparing.tr(),
      EnrollmentStage.verifying => LangKeys.enrollVerifying.tr(),
      EnrollmentStage.enrolled => LangKeys.enrollEnrolled.tr(),
      EnrollmentStage.waitingForFinger => LangKeys.enrollPlaceFinger.tr(),
      EnrollmentStage.idle => LangKeys.enrollNone.tr(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LangKeys.enrollTitle.tr(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: state.isEnrolled
                ? context.color.success
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        // Shown as soon as the terminal has a slot, so the admin can see the
        // mapping even if they abandon the finger capture.
        if (state.deviceUserId != null)
          Text(
            '${LangKeys.enrollDeviceId.tr()}: ${state.deviceUserId}',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  Widget _waitingPanel(BuildContext context, EnrollmentCubit cubit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LangKeys.enrollPlaceFingerHint.tr(),
          style: const TextStyle(fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: cubit.confirm,
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                  LangKeys.enrollDone.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: cubit.cancel,
              child: Text(
                LangKeys.enrollCancel.tr(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context,
    EnrollmentState state,
    EnrollmentCubit cubit,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: state.isBusy ? null : () => cubit.start(name: nameOf()),
        icon: const Icon(Icons.fingerprint, size: 16),
        label: Text(
          state.isEnrolled ? LangKeys.enrollRedo.tr() : LangKeys.enrollAdd.tr(),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
