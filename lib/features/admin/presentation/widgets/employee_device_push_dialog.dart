import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../device/data/models/zk_push_models.dart';
import '../cubit/employee_management_cubit.dart';
import 'employee_device_push_summary.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Approves a push before anything is written to the terminal.
///
/// The question it asks is "send these names?", not "may I clear the device
/// first?". Nothing is deleted to make room: each person is written into their
/// own enrolment slot, so the fingerprints already on the unit — which this app
/// has never held a copy of and could not restore — survive the write.
class EmployeeDevicePushDialog extends StatelessWidget {
  const EmployeeDevicePushDialog({super.key, required this.plan});

  final ZkPushPlan plan;

  @override
  Widget build(BuildContext context) {
    // Nothing to do is an answer, not a dialog full of zeros with a live send
    // button underneath it.
    final nothingToDo = plan.isEmpty;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.upload_outlined,
            size: 20,
            color: context.color.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(LangKeys.devicePushTitle.tr())),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: nothingToDo
              ? Text(
                  LangKeys.devicePushNothing.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.color.mutedForeground,
                  ),
                )
              : EmployeeDevicePushSummary(plan: plan),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LangKeys.cancel.tr()),
        ),
        if (!nothingToDo)
          FilledButton(
            // Barred rather than hidden when the terminal is full: the admin
            // needs to see the send button they cannot press, next to the line
            // saying why.
            onPressed: plan.exceedsCapacity
                ? null
                : () {
                    final cubit = context.read<EmployeeManagementCubit>();
                    Navigator.pop(context);
                    cubit.pushToDevice(plan);
                  },
            child: Text(
              LangKeys.devicePushConfirm.tr(args: ['${plan.entries.length}']),
            ),
          ),
      ],
    );
  }
}

Future<void> showEmployeeDevicePushDialog(
  BuildContext context,
  ZkPushPlan plan,
) {
  final cubit = context.read<EmployeeManagementCubit>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: EmployeeDevicePushDialog(plan: plan),
    ),
  );
}
