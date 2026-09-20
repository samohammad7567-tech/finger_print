import 'dart:io';

import '../data_source/monthly_report_pdf_data_source.dart';

/// Thin delegation over the monthly PDF writer.
class MonthlyReportPdfRepo {
  final MonthlyReportPdfDataSource _dataSource;

  MonthlyReportPdfRepo(this._dataSource);

  Future<File> write({
    required List<MonthlyReportPdfRow> rows,
    required MonthlyReportPdfLabels labels,
    required bool isArabic,
    required String fileName,
    List<String> totals = const [],
  }) => _dataSource.write(
    rows: rows,
    labels: labels,
    isArabic: isArabic,
    fileName: fileName,
    totals: totals,
  );

  Future<void> open(String path) => _dataSource.open(path);
}
