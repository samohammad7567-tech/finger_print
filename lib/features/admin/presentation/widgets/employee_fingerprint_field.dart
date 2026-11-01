import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../cubit/enrollment_cubit.dart';
import 'enrollment_actions.dart';
import 'finger_selector.dart';

/// The fingerprint section of the employee form.
///
/// Enrolment is a two-handed operation: the app puts the terminal into capture
/// mode, the person presses a finger on the *device*, and then the admin
/// confirms here so the app can verify a template landed. Any of the terminal's
/// ten finger slots can be enrolled, and each is read back on open so the admin
/// can see what is already stored.
class EmployeeFingerprintField extends StatefulWidget {
  const EmployeeFingerprintField({super.key, required this.nameOf});

  /// Read lazily — the admin usually types the name after opening the sheet.
  final String Function() nameOf;

  @override
  State<EmployeeFingerprintField> createState() =>
      _EmployeeFingerprintFieldState();
}

class _EmployeeFingerprintFieldState extends State<EmployeeFingerprintField> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<EnrollmentCubit>();
      cubit.loadEnrolledFingers();
    });
  }

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
              _Header(state: state),
              const SizedBox(height: 10),
              FingerSelector(
                selected: state.finger,
                enrolled: state.enrolledFingers,
                enabled: !state.isBusy && !state.isWaiting,
                onSelected: cubit.selectFinger,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                LangKeys.enrollFingerHint.tr(),
                style: AppTextStyles.micro.copyWith(
                  color: context.color.mutedForeground,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              EnrollmentActions(
                state: state,
                cubit: cubit,
                nameOf: widget.nameOf,
              ),
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
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final EnrollmentState state;

  @override
  Widget build(BuildContext context) {
    final enrolled = state.hasAnyEnrolled;

    return Row(
      children: [
        Icon(
          enrolled ? Icons.fingerprint : Icons.fingerprint_outlined,
          size: AppDimens.iconXl,
          color: enrolled
              ? context.color.success
              : context.color.subtleForeground,
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.enrollTitle.tr(),
                style: AppTextStyles.captionMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _label(),
                style: AppTextStyles.meta.copyWith(
                  color: state.isEnrolled
                      ? context.color.success
                      : context.color.mutedForeground,
                ),
              ),
              Text(
                '${state.enrolledFingers.length} ${LangKeys.enrollFingerCount.tr()}',
                style: AppTextStyles.micro.copyWith(
                  color: context.color.mutedForeground,
                ),
              ),
              // Shown as soon as the terminal has a slot, so the admin can see
              // the mapping even if they abandon the finger capture.
              if (state.deviceUserId != null)
                Text(
                  '${LangKeys.enrollDeviceId.tr()}: ${state.deviceUserId}',
                  style: AppTextStyles.micro.copyWith(
                    color: context.color.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
        if (state.isBusy || state.isLoadingFingers)
          const SizedBox(
            width: AppDimens.spaceLg,
            height: AppDimens.spaceLg,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  String _label() => switch (state.stage) {
    EnrollmentStage.preparing => LangKeys.enrollPreparing.tr(),
    EnrollmentStage.verifying => LangKeys.enrollVerifying.tr(),
    EnrollmentStage.waitingForFinger => LangKeys.enrollPlaceFinger.tr(),
    EnrollmentStage.enrolled || EnrollmentStage.idle =>
      state.isEnrolled
          ? LangKeys.enrollEnrolled.tr()
          // Another finger is stored, but not the one currently selected — say
          // so rather than contradicting the count underneath.
          : state.hasAnyEnrolled
          ? LangKeys.enrollSelectedEmpty.tr()
          : LangKeys.enrollNone.tr(),
  };
}
