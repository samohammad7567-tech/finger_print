import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/enrollment_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

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
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: context.color.muted,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
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
                    size: AppDimens.iconXl,
                    color: state.isEnrolled
                        ? context.color.success
                        : context.color.subtleForeground,
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(child: _summary(context, state)),
                  if (state.isBusy)
                    const SizedBox(
                      width: AppDimens.spaceLg,
                      height: AppDimens.spaceLg,
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
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  state.error!.tr(),
                  style: AppTextStyles.meta.copyWith(
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
          style: AppTextStyles.captionMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.meta.copyWith(
            color: state.isEnrolled
                ? context.color.success
                : context.color.mutedForeground,
          ),
        ),
        // Shown as soon as the terminal has a slot, so the admin can see the
        // mapping even if they abandon the finger capture.
        if (state.deviceUserId != null)
          Text(
            '${LangKeys.enrollDeviceId.tr()}: ${state.deviceUserId}',
            style: AppTextStyles.micro.copyWith(
              color: context.color.mutedForeground,
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
          style: AppTextStyles.meta.copyWith(height: 1.4),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: cubit.confirm,
                icon: const Icon(Icons.check, size: AppDimens.iconMd),
                label: Text(
                  LangKeys.enrollDone.tr(),
                  style: AppTextStyles.caption,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            TextButton(
              onPressed: cubit.cancel,
              child: Text(
                LangKeys.enrollCancel.tr(),
                style: AppTextStyles.caption,
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
        icon: const Icon(Icons.fingerprint, size: AppDimens.iconMd),
        label: Text(
          state.isEnrolled ? LangKeys.enrollRedo.tr() : LangKeys.enrollAdd.tr(),
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}
