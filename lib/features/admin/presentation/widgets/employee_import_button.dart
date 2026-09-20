import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../data/data_source/employee_import_excel_data_source.dart';
import '../cubit/employee_management_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Adds a whole staff list at once, from the spreadsheet the admin already
/// keeps. The blank template sits behind the same button: somebody who has no
/// file yet needs the column headings more than they need the importer.
class EmployeeImportButton extends StatelessWidget {
  const EmployeeImportButton({super.key, required this.state});

  final EmployeeManagementState state;

  static const _templateFileName = 'employees_template.xlsx';

  @override
  Widget build(BuildContext context) {
    final busy = state.isImporting;
    final enabled = !busy && !state.isSaving && !state.isDeleting;

    return PopupMenuButton<_ImportAction>(
      enabled: enabled,
      tooltip: LangKeys.importEmployees.tr(),
      onSelected: (action) => switch (action) {
        _ImportAction.pickFile => _import(context),
        _ImportAction.template => _template(context),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _ImportAction.pickFile,
          child: _item(
            context,
            icon: Icons.upload_file_outlined,
            title: LangKeys.importEmployees.tr(),
            hint: LangKeys.importColumnsHint.tr(),
          ),
        ),
        PopupMenuItem(
          value: _ImportAction.template,
          child: _item(
            context,
            icon: Icons.download_outlined,
            title: LangKeys.importTemplate.tr(),
            hint: LangKeys.importTemplateHint.tr(),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.color.primary.withValues(alpha: enabled ? 0.5 : 0.2),
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
                Icons.table_view_outlined,
                size: 16,
                color: enabled
                    ? context.color.primary
                    : context.color.subtleForeground,
              ),
            const SizedBox(width: 6),
            Text(
              (busy ? LangKeys.importing : LangKeys.importExcel).tr(),
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
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String hint,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: context.color.primary),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: context.color.subtleForeground,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  void _import(BuildContext context) =>
      context.read<EmployeeManagementCubit>().importFromExcel(
        typeLabel: LangKeys.importFileType.tr(),
        confirmLabel: LangKeys.importEmployees.tr(),
      );

  void _template(BuildContext context) =>
      context.read<EmployeeManagementCubit>().saveImportTemplate(
        fileName: _templateFileName,
        typeLabel: LangKeys.importFileType.tr(),
        confirmLabel: LangKeys.importTemplate.tr(),
        isArabic: context.locale.languageCode == 'ar',
        labels: _labels(),
      );

  /// The headings are translated here — the writer is a data source and has no
  /// business knowing the language.
  EmployeeImportLabels _labels() => EmployeeImportLabels(
    sheetName: LangKeys.employees.tr(),
    fullName: LangKeys.adminFullName.tr(),
    employeeNumber: LangKeys.adminEmployeeId.tr(),
    department: LangKeys.adminDepartment.tr(),
    position: LangKeys.adminPosition.tr(),
    phone: LangKeys.adminPhone.tr(),
    deviceUserId: LangKeys.enrollDeviceId.tr(),
    housing: LangKeys.adminHasHousing.tr(),
    travel: LangKeys.adminHasTravel.tr(),
    active: LangKeys.adminActiveEmployee.tr(),
    yes: LangKeys.yes.tr(),
    no: LangKeys.no.tr(),
    sampleName: LangKeys.importSampleName.tr(),
    sampleDepartment: LangKeys.importSampleDepartment.tr(),
    samplePosition: LangKeys.importSamplePosition.tr(),
  );
}

enum _ImportAction { pickFile, template }
