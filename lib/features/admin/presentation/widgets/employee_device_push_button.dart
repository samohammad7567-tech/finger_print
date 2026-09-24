import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/employee_management_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Writes the staff list onto the fingerprint terminal — the other direction
/// to [EmployeeDeviceFetchButton].
///
/// Pressing it only *reads* the terminal: what comes back is a plan the admin
/// approves before a byte is written. Nothing is ever cleared to make room —
/// each person is written into their own enrolment slot, which is what leaves
/// the fingerprints already on the device intact.
class EmployeeDevicePushButton extends StatelessWidget {
  const EmployeeDevicePushButton({super.key, required this.state});

  final EmployeeManagementState state;

  @override
  Widget build(BuildContext context) {
    final busy = state.isPreparingPush || state.isPushingToDevice;
    final enabled = !state.isBusy && state.hasActiveEmployees;

    return Tooltip(
      message: LangKeys.devicePushHint.tr(),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? () =>
                  context.read<EmployeeManagementCubit>().preparePushToDevice()
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.color.primary.withValues(
                alpha: enabled ? 0.5 : 0.2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.upload_outlined,
                  size: 16,
                  color: enabled
                      ? context.color.primary
                      : context.color.subtleForeground,
                ),
              const SizedBox(width: 6),
              Text(
                _label(state),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? context.color.primary
                      : context.color.subtleForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A count while the write runs. A staff list takes long enough on this
  /// hardware that a spinner alone reads as a hang, and the admin has no other
  /// way to tell how far through it is.
  static String _label(EmployeeManagementState state) {
    if (state.isPreparingPush) return LangKeys.devicePushPreparing.tr();
    if (state.isPushingToDevice) {
      return state.pushTotal > 0
          ? '${state.pushDone}/${state.pushTotal}'
          : LangKeys.devicePushing.tr();
    }
    return LangKeys.devicePush.tr();
  }
}
