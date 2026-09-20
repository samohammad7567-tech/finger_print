import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/employee_management_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Fills the staff list in from the fingerprint terminal, on demand.
///
/// The device screen already syncs on a timer, but an admin setting the app up
/// wants the list populated now and does not want to go looking for another
/// screen to do it. Pressing this fetches the enrolment table, folds the new
/// arrivals into the same 001..N numbering as everybody else, and reports any
/// name that now appears twice.
class EmployeeDeviceFetchButton extends StatelessWidget {
  const EmployeeDeviceFetchButton({super.key, required this.state});

  final EmployeeManagementState state;

  @override
  Widget build(BuildContext context) {
    final busy = state.isFetchingFromDevice;
    final enabled = !state.isBusy;

    return Tooltip(
      message: LangKeys.deviceFetchHint.tr(),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? () => context.read<EmployeeManagementCubit>().fetchFromDevice()
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
                  Icons.fingerprint,
                  size: 16,
                  color: enabled
                      ? context.color.primary
                      : context.color.subtleForeground,
                ),
              const SizedBox(width: 6),
              Text(
                (busy ? LangKeys.deviceFetching : LangKeys.deviceFetch).tr(),
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
}
