import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../attendance/data/models/employee_import_models.dart';
import '../../../../core/style/theme/context_extension.dart';

/// What the import made of the file.
///
/// A count alone would leave the admin wondering which four of their forty
/// people are missing, so every refused row is named with its line number and
/// the reason — enough to go and fix the sheet.
Future<void> showEmployeeImportResultDialog(
  BuildContext context,
  EmployeeImportResult result,
) => showDialog<void>(
  context: context,
  builder: (_) => _EmployeeImportResultDialog(result: result),
);

class _EmployeeImportResultDialog extends StatelessWidget {
  const _EmployeeImportResultDialog({required this.result});

  final EmployeeImportResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        LangKeys.importResultTitle.tr(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(
              icon: Icons.check_circle_outline,
              color: context.color.success,
              text: LangKeys.importResultAdded.tr(
                args: ['${result.createdCount}'],
              ),
            ),
            if (result.hasSkipped) ...[
              const SizedBox(height: 6),
              _line(
                icon: Icons.error_outline,
                color: context.color.destructive,
                text: LangKeys.importResultSkipped.tr(
                  args: ['${result.skippedCount}'],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(child: _skippedList(context)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LangKeys.close.tr()),
        ),
      ],
    );
  }

  Widget _line({
    required IconData icon,
    required Color color,
    required String text,
  }) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Flexible(child: Text(text, style: const TextStyle(fontSize: 13))),
    ],
  );

  Widget _skippedList(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: result.skipped.length,
        separatorBuilder: (_, _) => const Divider(height: 12),
        itemBuilder: (_, i) {
          final issue = result.skipped[i];
          final name = issue.name.trim();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  LangKeys.importSkippedRow.tr(args: ['${issue.line}']),
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      issue.reasonKey.tr(),
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
