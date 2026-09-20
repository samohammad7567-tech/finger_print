import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/features/admin/data/data_source/punch_report_pdf_data_source.dart';

/// The exported report. A PDF that fails to render fails at the moment an
/// admin needs it, so the writer is exercised here rather than by hand.
void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('guardsync-pdf-test');
  });

  tearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  const labels = PunchReportPdfLabels(
    title: 'تقرير البصمات',
    range: '2026-08-24  →  2026-08-24',
    generatedAt: 'أُنشئ في 2026-08-24 18:00',
    name: 'الموظف',
    date: 'التاريخ',
    day: 'اليوم',
    checkIn: 'الحضور',
    checkOut: 'الانصراف',
    breakTime: 'مدة الاستراحات',
    overtime: 'الوقت الإضافي',
    workTime: 'ساعات العمل',
    status: 'الحالة',
    totals: 'الإجماليات',
  );

  const rows = [
    PunchReportPdfRow(
      name: 'ابو يوسف',
      date: '2026-08-24',
      dayName: 'الاثنين',
      checkIn: '08:00',
      checkOut: '19:00',
      breakTime: '1h 15m',
      overtime: '1h 30m',
      workTime: '8h 15m',
      status: 'حاضر',
    ),
    PunchReportPdfRow(
      name: 'Sara Khalid',
      date: '2026-08-24',
      dayName: 'Monday',
      checkIn: '08:45',
      checkOut: '17:05',
      breakTime: '0h 30m',
      overtime: '—',
      workTime: '7h 50m',
      status: 'Late',
    ),
  ];

  test('writes a PDF for the rows it is given', () async {
    final file = await PunchReportPdfDataSource().write(
      rows: rows,
      labels: labels,
      isArabic: true,
      fileName: 'report.pdf',
      totals: const ['ساعات العمل: 16h 05m'],
      folder: folder,
    );

    expect(await file.exists(), isTrue);

    final bytes = await file.readAsBytes();
    // A real document, not an empty file: the magic number plus enough content
    // to be two rows and a table.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('an empty report still produces a readable page', () async {
    final file = await PunchReportPdfDataSource().write(
      rows: const [],
      labels: labels,
      isArabic: false,
      fileName: 'empty.pdf',
      folder: folder,
    );

    expect(await file.exists(), isTrue);
    expect(String.fromCharCodes((await file.readAsBytes()).take(5)), '%PDF-');
  });
}
