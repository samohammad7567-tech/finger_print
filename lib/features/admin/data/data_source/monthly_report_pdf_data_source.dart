import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

import '../../../../core/pdf/report_pdf_engine.dart';

/// One employee's month, already counted and formatted. The exporter lays out
/// text and nothing else.
class MonthlyReportPdfRow {
  final String name;
  final String department;
  final String presentDays;
  final String lateTimes;
  final String earlyLeave;
  final String absentDays;
  final String permissionDays;
  final String lateHours;
  final String overtime;

  const MonthlyReportPdfRow({
    required this.name,
    required this.department,
    required this.presentDays,
    required this.lateTimes,
    required this.earlyLeave,
    required this.absentDays,
    required this.permissionDays,
    required this.lateHours,
    required this.overtime,
  });

  List<String> get cells => [
    name,
    department,
    presentDays,
    lateTimes,
    earlyLeave,
    absentDays,
    permissionDays,
    lateHours,
    overtime,
  ];
}

/// Column headings and the page furniture, translated by the caller.
///
/// The exporter never touches the localisation itself — it is a data source,
/// and the words belong to the screen that asked for the file.
class MonthlyReportPdfLabels {
  final String title;
  final String month;
  final String generatedAt;
  final String name;
  final String department;
  final String presentDays;
  final String lateTimes;
  final String earlyLeave;
  final String absentDays;
  final String permissionDays;
  final String lateHours;
  final String overtime;
  final String totals;

  const MonthlyReportPdfLabels({
    required this.title,
    required this.month,
    required this.generatedAt,
    required this.name,
    required this.department,
    required this.presentDays,
    required this.lateTimes,
    required this.earlyLeave,
    required this.absentDays,
    required this.permissionDays,
    required this.lateHours,
    required this.overtime,
    required this.totals,
  });

  List<String> get headers => [
    name,
    department,
    presentDays,
    lateTimes,
    earlyLeave,
    absentDays,
    permissionDays,
    lateHours,
    overtime,
  ];
}

/// Writes the monthly attendance summary to a PDF an admin can print or send
/// on.
class MonthlyReportPdfDataSource {
  final ReportPdfEngine _engine;

  MonthlyReportPdfDataSource([ReportPdfEngine? engine])
    : _engine = engine ?? ReportPdfEngine();

  /// Renders [rows] and returns the file it wrote.
  ///
  /// [folder] is for tests; left out, the file lands in the shared reports
  /// folder alongside every other export.
  Future<File> write({
    required List<MonthlyReportPdfRow> rows,
    required MonthlyReportPdfLabels labels,
    required bool isArabic,
    required String fileName,
    List<String> totals = const [],
    Directory? folder,
  }) => _engine.writeTable(
    title: labels.title,
    range: labels.month,
    generatedAt: labels.generatedAt,
    headers: labels.headers,
    rows: rows.map((r) => r.cells).toList(),
    isArabic: isArabic,
    fileName: fileName,
    totalsLabel: labels.totals,
    totals: totals,
    // The name and the department carry words; the counters after them are
    // a couple of characters each and share what is left evenly.
    columnWidths: const {
      0: pw.FlexColumnWidth(2.6),
      1: pw.FlexColumnWidth(1.8),
    },
    folder: folder,
  );

  /// Hands the finished file to whatever the machine opens PDFs with.
  Future<void> open(String path) => _engine.open(path);
}
