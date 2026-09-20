import 'dart:io';

import '../data_source/punch_report_pdf_data_source.dart';

/// Thin delegation over the PDF writer.
class PunchReportPdfRepo {
  final PunchReportPdfDataSource _dataSource;

  PunchReportPdfRepo(this._dataSource);

  Future<File> write({
    required List<PunchReportPdfRow> rows,
    required PunchReportPdfLabels labels,
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
