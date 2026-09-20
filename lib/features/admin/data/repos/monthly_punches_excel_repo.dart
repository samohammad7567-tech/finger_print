import 'dart:io';

import '../data_source/monthly_punches_excel_data_source.dart';

/// Thin delegation over the monthly punch workbook writer.
class MonthlyPunchesExcelRepo {
  final MonthlyPunchesExcelDataSource _dataSource;

  MonthlyPunchesExcelRepo(this._dataSource);

  Future<String?> pickDestination({
    required String fileName,
    required String typeLabel,
    String? initialDirectory,
    String? confirmLabel,
  }) => _dataSource.pickDestination(
    fileName: fileName,
    typeLabel: typeLabel,
    initialDirectory: initialDirectory,
    confirmLabel: confirmLabel,
  );

  Future<File> write({
    required List<MonthlyPunchEmployee> employees,
    required MonthlyPunchesExcelLabels labels,
    required String fileName,
    bool isArabic = false,
    String? path,
  }) => _dataSource.write(
    employees: employees,
    labels: labels,
    fileName: fileName,
    isArabic: isArabic,
    path: path,
  );

  Future<void> open(String path) => _dataSource.open(path);
}
