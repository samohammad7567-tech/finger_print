import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../device/data/models/zk_push_models.dart';
import 'employee_device_push_rows.dart';
import '../../../../core/style/theme/context_extension.dart';

/// The body of the push dialog: what the write would do, before it does it.
///
/// Counts first, then only the warnings that apply. The one thing it never
/// asks for is permission to clear the terminal — the write does not need an
/// empty table, and saying so here is what stops an admin reaching for the
/// wipe on the device screen to "make room".
class EmployeeDevicePushSummary extends StatelessWidget {
  const EmployeeDevicePushSummary({super.key, required this.plan});

  final ZkPushPlan plan;

  @override
  Widget build(BuildContext context) {
    final faded = context.color.mutedForeground;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LangKeys.devicePushIntro.tr(
            args: ['${plan.entries.length}', '${plan.onDevice}'],
          ),
          style: TextStyle(fontSize: 12, color: faded),
        ),
        const SizedBox(height: 12),
        PushSummaryRow(
          icon: Icons.person_add_alt,
          label: LangKeys.devicePushNew,
          count: plan.createCount,
        ),
        PushSummaryRow(
          icon: Icons.drive_file_rename_outline,
          label: LangKeys.devicePushUpdate,
          count: plan.updateCount,
        ),
        if (plan.extras.isNotEmpty)
          PushSummaryRow(
            icon: Icons.help_outline,
            label: LangKeys.devicePushExtra,
            count: plan.extras.length,
            hint: LangKeys.devicePushExtraHint,
          ),
        const SizedBox(height: 12),
        // The reassurance an admin needs before pressing send, and the reason
        // no wipe is offered anywhere on this dialog.
        PushSummaryNote(
          icon: Icons.fingerprint,
          text: LangKeys.devicePushKeepsFingerprints.tr(),
          color: context.color.success,
        ),
        if (plan.truncated.isNotEmpty) ...[
          const SizedBox(height: 8),
          PushSummaryNote(
            icon: Icons.short_text,
            text:
                '${LangKeys.devicePushTruncated.tr()} (${plan.truncated.length})'
                '\n${LangKeys.devicePushTruncatedHint.tr()}',
            color: context.color.warning,
          ),
        ],
        if (plan.exceedsCapacity) ...[
          const SizedBox(height: 8),
          PushSummaryNote(
            icon: Icons.storage_outlined,
            text: LangKeys.devicePushCapacity.tr(
              args: ['${plan.freeSlots}', '${plan.createCount}'],
            ),
            color: context.color.destructive,
          ),
        ],
      ],
    );
  }
}
