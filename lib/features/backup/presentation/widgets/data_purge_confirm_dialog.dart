import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/context_extension.dart';

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
    builder: (ctx) => AlertDialog(
      title: Text(LangKeys.dataClearBeforeConfirmTitle.tr(args: [date])),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.dataClearBeforeConfirmMsg.tr(args: [date]),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ctx.color.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ctx.color.warning.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: ctx.color.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LangKeys.dataClearBeforeWarning.tr(),
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: ctx.color.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
