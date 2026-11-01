import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../cubit/enrollment_cubit.dart';

/// The part of the fingerprint panel below the finger picker: either the
/// terminal is waiting for a finger, or there is an action to start one.
class EnrollmentActions extends StatelessWidget {
  const EnrollmentActions({
    super.key,
    required this.state,
    required this.cubit,
    required this.nameOf,
  });

  final EnrollmentState state;
  final EnrollmentCubit cubit;
  final String Function() nameOf;

  @override
  Widget build(BuildContext context) {
    if (state.isWaiting) return _WaitingPanel(cubit: cubit);
    return _ActionButton(state: state, cubit: cubit, nameOf: nameOf);
  }
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({required this.cubit});

  final EnrollmentCubit cubit;

  @override
  Widget build(BuildContext context) {
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
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.state,
    required this.cubit,
    required this.nameOf,
  });

  final EnrollmentState state;
  final EnrollmentCubit cubit;
  final String Function() nameOf;

  @override
  Widget build(BuildContext context) {
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
