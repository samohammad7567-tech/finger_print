import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_wide_dialog.dart';
import '../../../../core/widgets/app_note_banner.dart';

/// Confirms clearing everything before a date.
///
/// The warning is the part that earns the dialog. Two consequences are not
/// obvious from the button: the punches go with the days, so those days can
/// never be re-folded or corrected again — and a terminal still holding old
/// punches will hand them straight back on the next sync.
Future<bool> showDataPurgeConfirmDialog(
  BuildContext context,
  String date,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppWideDialog(
      title: LangKeys.dataClearBeforeConfirmTitle.tr(args: [date]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LangKeys.dataClearBeforeConfirmMsg.tr(args: [date]),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          AppNoteBanner(
            icon: Icons.warning_amber_rounded,
            text: LangKeys.dataClearBeforeWarning.tr(),
            color: ctx.color.warning,
            iconSize: 16,
            borderAlpha: 0.30,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(LangKeys.cancel.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            LangKeys.confirm.tr(),
            style: TextStyle(color: ctx.color.destructive),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
