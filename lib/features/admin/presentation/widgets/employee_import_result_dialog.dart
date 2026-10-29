import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../attendance/data/models/employee_import_models.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

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
        style: AppTextStyles.subheading.copyWith(fontWeight: FontWeight.bold),
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
              const SizedBox(height: AppDimens.spaceMd),
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
      Icon(icon, size: AppDimens.iconLg, color: color),
      const SizedBox(width: AppDimens.spaceSm),
      Flexible(child: Text(text, style: AppTextStyles.body)),
    ],
  );

  Widget _skippedList(BuildContext context) {
    final muted = context.color.mutedForeground;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: result.skipped.length,
        separatorBuilder: (_, _) => const Divider(height: AppDimens.spaceMd),
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
                  style: AppTextStyles.meta.copyWith(color: muted),
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
                        style: AppTextStyles.captionMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      issue.reasonKey.tr(),
                      style: AppTextStyles.meta.copyWith(color: muted),
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
