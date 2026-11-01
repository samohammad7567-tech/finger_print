import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

import '../../../../core/pdf/report_pdf_engine.dart';
import '../../../../core/utils/punch_pairs.dart';

/// One line of the exported report. Everything is already calculated and
/// formatted — the exporter lays out text and nothing else.
class PunchReportPdfRow {
  /// The line's number in the report, counted from one.
  final int serial;
  final String surname;
  final String name;
  final String personalId;
  final String accommodation;
  final String date;
  final String dayName;
  final List<PunchPair> pairs;

  const PunchReportPdfRow({
    this.serial = 0,
    this.surname = '',
    required this.name,
    this.personalId = '',
    this.accommodation = '—',
    required this.date,
    required this.dayName,
    this.pairs = const [],
  });

  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;

  /// The row padded to [pairCount] pairs, so every line fills every column.
  List<String> cells(int pairCount) => [
    '$serial',
    _orDash(surname),
    _orDash(name),
    _orDash(personalId),
    _orDash(accommodation),
    date,
    dayName,
    for (var i = 0; i < pairCount; i++) ...[
      i < pairs.length ? (pairs[i].checkIn ?? '—') : '—',
      i < pairs.length ? (pairs[i].checkOut ?? '—') : '—',
    ],
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
  final String serial;
  final String surname;
  final String name;
  final String personalId;
  final String accommodation;
  final String traveler;
  final String overnight;
  final String date;
  final String day;

  /// The headings for pair [index], numbered from one. A function rather than
  /// a list because the widest day is only known once the rows are in hand.
  final String Function(int index) pairCheckIn;
  final String Function(int index) pairCheckOut;

  final String breakTime;
  final String overtime;
  final String workTime;
  final String totals;

  const PunchReportPdfLabels({
    required this.title,
    required this.range,
    required this.generatedAt,
    required this.serial,
    required this.surname,
    required this.name,
    required this.personalId,
    required this.accommodation,
    required this.traveler,
    required this.overnight,
    required this.date,
    required this.day,
    required this.pairCheckIn,
    required this.pairCheckOut,
    required this.breakTime,
    required this.overtime,
    required this.workTime,
    required this.totals,
  });

  List<String> headers(int pairCount) => [
    serial,
    surname,
    name,
    personalId,
    accommodation,
    date,
    day,
    for (var i = 1; i <= pairCount; i++) ...[pairCheckIn(i), pairCheckOut(i)],
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
  }) {
    var pairCount = 1;
    for (final row in rows) {
      if (row.pairs.length > pairCount) pairCount = row.pairs.length;
    }

    return _engine.writeTable(
      title: labels.title,
      range: labels.range,
      generatedAt: labels.generatedAt,
      headers: labels.headers(pairCount),
      rows: rows.map((r) => r.cells(pairCount)).toList(),
      isArabic: isArabic,
      fileName: fileName,
      totalsLabel: labels.totals,
      totals: totals,
      columnWidths: {
        0: const pw.FlexColumnWidth(0.6),
        1: const pw.FlexColumnWidth(1.8),
        2: const pw.FlexColumnWidth(2.4),
        3: const pw.FlexColumnWidth(1.8),
        4: const pw.FlexColumnWidth(1.8),
        5: const pw.FlexColumnWidth(1.4),
        6: const pw.FlexColumnWidth(1.3),
        for (var i = 0; i < pairCount * 2; i++)
          7 + i: const pw.FlexColumnWidth(1.2),
      },
      folder: folder,
    );
  }

  /// Hands the finished file to whatever the machine opens PDFs with.
  Future<void> open(String path) => _engine.open(path);
}
