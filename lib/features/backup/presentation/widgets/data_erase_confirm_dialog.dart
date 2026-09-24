import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Confirms erasing the staff list and everything hanging off it.
///
/// The tick box is not ceremony. This is the one action in the app that cannot
/// be undone from inside it, and a dialog whose confirm button is live the
/// moment it opens is a dialog people dismiss by reflex. Ticking makes the
/// admin stop on the sentence that matters.
class DataEraseConfirmDialog extends StatefulWidget {
  const DataEraseConfirmDialog({super.key});

  @override
  State<DataEraseConfirmDialog> createState() => _DataEraseConfirmDialogState();
}

Future<bool> showDataEraseConfirmDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const DataEraseConfirmDialog(),
  );
  return confirmed ?? false;
}

class _DataEraseConfirmDialogState extends State<DataEraseConfirmDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.delete_forever_outlined,
            size: 20,
            color: context.color.destructive,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(LangKeys.dataEraseConfirmTitle.tr())),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.dataEraseConfirmMsg.tr(),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              // What survives, spelled out. An admin who thinks this also
              // wipes the fingerprints on the terminal would go and re-enrol
              // forty people for nothing.
              Text(
                LangKeys.dataEraseKept.tr(),
                style: TextStyle(fontSize: 11, color: context.color.success),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _acknowledged,
                onChanged: (on) =>
                    setState(() => _acknowledged = on ?? false),
                title: Text(
                  LangKeys.dataEraseAck.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(LangKeys.cancel.tr()),
        ),
        TextButton(
          onPressed: _acknowledged
              ? () => Navigator.pop(context, true)
              : null,
          child: Text(
            LangKeys.confirm.tr(),
            style: TextStyle(
              color: _acknowledged
                  ? context.color.destructive
                  : context.color.subtleForeground,
            ),
          ),
        ),
      ],
    );
  }
}
