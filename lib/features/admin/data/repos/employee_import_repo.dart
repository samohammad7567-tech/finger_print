import 'dart:io';

import '../../../attendance/data/models/employee_import_models.dart';
import '../data_source/employee_import_excel_data_source.dart';

/// Thin delegation over the employee workbook reader.
class EmployeeImportRepo {
  final EmployeeImportExcelDataSource _dataSource;

  EmployeeImportRepo(this._dataSource);

  Future<String?> pickFile({
    required String typeLabel,
    String? initialDirectory,
    String? confirmLabel,
  }) => _dataSource.pickFile(
    typeLabel: typeLabel,
    initialDirectory: initialDirectory,
    confirmLabel: confirmLabel,
  );

  Future<List<EmployeeImportRow>> read(String path) => _dataSource.read(path);

  Future<String?> pickTemplateDestination({
    required String fileName,
    required String typeLabel,
    String? initialDirectory,
    String? confirmLabel,
  }) => _dataSource.pickTemplateDestination(
    fileName: fileName,
    typeLabel: typeLabel,
    initialDirectory: initialDirectory,
    confirmLabel: confirmLabel,
  );

  Future<File> writeTemplate({
    required String path,
    required EmployeeImportLabels labels,
    bool isArabic = false,
  }) =>
      _dataSource.writeTemplate(path: path, labels: labels, isArabic: isArabic);

  Future<void> open(String path) => _dataSource.open(path);
}
