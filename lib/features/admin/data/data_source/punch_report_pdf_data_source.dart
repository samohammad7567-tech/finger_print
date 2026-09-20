import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

import '../../../../core/pdf/report_pdf_engine.dart';

/// One line of the exported report. Everything is already calculated and
/// formatted — the exporter lays out text and nothing else.
class PunchReportPdfRow {
  final String name;
  final String date;
  final String dayName;
  final String checkIn;
  final String checkOut;
  final String breakTime;
  final String overtime;
  final String workTime;
  final String status;

  const PunchReportPdfRow({
    required this.name,
    required this.date,
    required this.dayName,
    required this.checkIn,
    required this.checkOut,
    required this.breakTime,
    required this.overtime,
    required this.workTime,
    required this.status,
  });

  List<String> get cells => [
    name,
    date,
    dayName,
    checkIn,
    checkOut,
    breakTime,
    overtime,
    workTime,
    status,
  ];
}

/// Column headings and the page furniture, translated by the caller.
///
/// The exporter never touches the localisation itself — it is a data source,
/// and the words belong to the screen that asked for the file.
class PunchReportPdfLabels {
  final String title;
  final String range;
  final String generatedAt;
  final String name;
  final String date;
  final String day;
  final String checkIn;
  final String checkOut;
  final String breakTime;
  final String overtime;
  final String workTime;
  final String status;
  final String totals;

  const PunchReportPdfLabels({
    required this.title,
    required this.range,
    required this.generatedAt,
    required this.name,
    required this.date,
    required this.day,
    required this.checkIn,
    required this.checkOut,
    required this.breakTime,
    required this.overtime,
    required this.workTime,
    required this.status,
    required this.totals,
  });

  List<String> get headers => [
    name,
    date,
    day,
    checkIn,
    checkOut,
    breakTime,
    overtime,
    workTime,
    status,
  ];
}

/// Writes the punch report to a PDF an admin can print or send on.
class PunchReportPdfDataSource {
  final ReportPdfEngine _engine;

  PunchReportPdfDataSource([ReportPdfEngine? engine])
    : _engine = engine ?? ReportPdfEngine();

  /// Renders [rows] and returns the file it wrote.
  ///
  /// [folder] is for tests; left out, the file lands in the shared reports
  /// folder alongside every other export.
  Future<File> write({
    required List<PunchReportPdfRow> rows,
    required PunchReportPdfLabels labels,
    required bool isArabic,
    required String fileName,
    List<String> totals = const [],
    Directory? folder,
  }) => _engine.writeTable(
    title: labels.title,
    range: labels.range,
    generatedAt: labels.generatedAt,
    headers: labels.headers,
    rows: rows.map((r) => r.cells).toList(),
    isArabic: isArabic,
    fileName: fileName,
    totalsLabel: labels.totals,
    totals: totals,
    columnWidths: const {
      0: pw.FlexColumnWidth(2.4),
      1: pw.FlexColumnWidth(1.4),
      2: pw.FlexColumnWidth(1.4),
    },
    folder: folder,
  );

  /// Hands the finished file to whatever the machine opens PDFs with.
  Future<void> open(String path) => _engine.open(path);
}
