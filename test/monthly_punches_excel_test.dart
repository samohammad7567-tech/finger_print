import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:attendence/features/admin/data/data_source/monthly_punches_excel_data_source.dart';

/// The monthly punch workbook. It is handed to an employee who thinks their
/// month is wrong, so it is opened and read back here rather than trusted to
/// have been written — a file that will not open fails at the worst moment.
void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('guardsync-xlsx-test');
  });

  tearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  const labels = MonthlyPunchesExcelLabels(
    title: 'تقرير البصمات الشهري',
    month: 'September 2026',
    generatedAt: 'Generated 2026-09-30 18:00',
    allSheet: 'All',
    employee: 'الموظف',
    employeeNumber: 'الرقم الوظيفي',
    department: 'القسم',
    date: 'التاريخ',
    day: 'اليوم',
    checkIn: 'الحضور',
    checkOut: 'الانصراف',
    breaks: 'الاستراحات',
    breakTime: 'مدة الاستراحات',
    overtime: 'الوقت الإضافي',
    worked: 'ساعات العمل',
    status: 'الحالة',
    corrected: 'صُحّح بواسطة',
    totals: 'الإجماليات',
    presentDays: 'أيام الحضور',
    absentDays: 'أيام الغياب',
  );

  MonthlyPunchRow row(String date, {String status = 'present'}) =>
      MonthlyPunchRow(
        date: date,
        dayName: 'Tuesday',
        checkIn: '08:00',
        checkOut: '17:10',
        breaks: '12:00 → 12:30',
        breakTime: '0h 30m',
        overtime: '—',
        worked: '8h 40m',
        status: status,
      );

  MonthlyPunchEmployee employee({
    String name = 'ابو يوسف',
    String number = 'EMP001',
    List<MonthlyPunchRow>? rows,
  }) => MonthlyPunchEmployee(
    name: name,
    number: number,
    department: 'Ops',
    rows: rows ?? [row('2026-09-01'), row('2026-09-02', status: 'absent')],
    totals: const [(label: 'ساعات العمل', value: '17h 20m')],
  );

  Future<Excel> writeAndRead(List<MonthlyPunchEmployee> employees) async {
    final file = await MonthlyPunchesExcelDataSource().write(
      employees: employees,
      labels: labels,
      fileName: 'month.xlsx',
      isArabic: true,
      folder: folder,
    );
    expect(await file.exists(), isTrue);
    return Excel.decodeBytes(await file.readAsBytes());
  }

  String? text(Sheet sheet, int rowIndex, int column) {
    final rows = sheet.rows;
    if (rowIndex >= rows.length || column >= rows[rowIndex].length) return null;
    final value = rows[rowIndex][column]?.value;
    return value is TextCellValue ? value.value.text : value?.toString();
  }

  /// The row the column headings landed on, whatever preamble came first.
  int headerRowOf(Sheet sheet, String firstHeading) {
    for (var i = 0; i < sheet.rows.length; i++) {
      if (text(sheet, i, 0) == firstHeading) return i;
    }
    fail('no header row starting with "$firstHeading"');
  }

  test('a combined sheet and one tab per employee', () async {
    final book = await writeAndRead([
      employee(),
      employee(name: 'Sara Khalid', number: 'EMP002'),
    ]);

    expect(book.tables.keys, ['All', 'ابو يوسف', 'Sara Khalid']);
    // The seeded default sheet is not left behind.
    expect(book.tables.containsKey('Sheet1'), isFalse);
  });

  test('the combined sheet names the employee on every line', () async {
    final book = await writeAndRead([
      employee(),
      employee(name: 'Sara Khalid', number: 'EMP002'),
    ]);

    final all = book.tables['All']!;
    final header = headerRowOf(all, labels.employee);

    expect(text(all, header, 0), labels.employee);
    expect(text(all, header, 3), labels.date);
    expect(text(all, header, 12), labels.corrected);

    // Two employees, two days each, in the order they were given.
    expect(text(all, header + 1, 0), 'ابو يوسف');
    expect(text(all, header + 1, 1), 'EMP001');
    expect(text(all, header + 1, 3), '2026-09-01');
    expect(text(all, header + 3, 0), 'Sara Khalid');
  });

  test("an employee's own tab carries their days and their totals", () async {
    final book = await writeAndRead([employee()]);

    final sheet = book.tables['ابو يوسف']!;
    expect(text(sheet, 0, 0), 'ابو يوسف');

    final header = headerRowOf(sheet, labels.date);
    // The day columns only — the tab is already theirs.
    expect(text(sheet, header, 0), labels.date);
    expect(text(sheet, header, 8), labels.status);

    expect(text(sheet, header + 1, 0), '2026-09-01');
    expect(text(sheet, header + 1, 2), '08:00');
    expect(text(sheet, header + 2, 8), 'absent');

    final totals = headerRowOf(sheet, labels.totals);
    expect(text(sheet, totals + 1, 0), 'ساعات العمل');
    expect(text(sheet, totals + 1, 1), '17h 20m');
  });

  test('every day of the month gets a line, silence included', () async {
    // What the cubit hands over for a day nobody scanned.
    const empty = MonthlyPunchRow(
      date: '2026-09-03',
      dayName: 'Thursday',
      checkIn: '—',
      checkOut: '—',
      breaks: '—',
      breakTime: '—',
      overtime: '—',
      worked: '—',
      status: 'Not Recorded',
    );

    final book = await writeAndRead([
      employee(rows: [row('2026-09-01'), empty]),
    ]);

    final sheet = book.tables['ابو يوسف']!;
    final header = headerRowOf(sheet, labels.date);

    expect(text(sheet, header + 2, 0), '2026-09-03');
    expect(text(sheet, header + 2, 2), '—');
    expect(text(sheet, header + 2, 8), 'Not Recorded');
  });

  test('a name Excel would reject is made into a tab it accepts', () async {
    final book = await writeAndRead([employee(name: 'Ops/Nights [A]:1')]);

    final name = book.tables.keys.last;
    expect(name, isNot(contains('/')));
    expect(name, isNot(contains('[')));
    expect(name, isNot(contains(':')));
    expect(name.length, lessThanOrEqualTo(31));
  });

  test('two people with the same name still get a tab each', () async {
    final book = await writeAndRead([
      employee(name: 'Mohammad Ali', number: 'EMP001'),
      employee(name: 'Mohammad Ali', number: 'EMP002'),
    ]);

    expect(book.tables.keys, hasLength(3));
    expect(book.tables.keys.toSet(), hasLength(3));
  });

  test('a very long name is clipped to a tab name Excel allows', () async {
    final book = await writeAndRead([employee(name: 'A' * 60)]);

    expect(book.tables.keys.last.length, lessThanOrEqualTo(31));
  });

  test('the workbook goes exactly where it is told to go', () async {
    final chosen = p.join(folder.path, 'payroll', 'september.xlsx');

    final file = await MonthlyPunchesExcelDataSource().write(
      employees: [employee()],
      labels: labels,
      fileName: 'ignored-when-a-path-is-given.xlsx',
      path: chosen,
    );

    expect(file.path, chosen);
    // A folder the admin typed into the dialog may not exist yet.
    expect(await File(chosen).exists(), isTrue);
    // And it is still a workbook that opens.
    expect(Excel.decodeBytes(await file.readAsBytes()).tables, isNotEmpty);
  });

  test('a chosen name keeps its extension, or is given one', () {
    const ensure = MonthlyPunchesExcelDataSource.withXlsxExtension;

    expect(ensure(r'C:\Reports\september.xlsx'), r'C:\Reports\september.xlsx');
    // Somebody typing over the suggested name usually drops the extension.
    expect(ensure(r'C:\Reports\september'), r'C:\Reports\september.xlsx');
    expect(ensure(r'C:\Reports\SEPTEMBER.XLSX'), r'C:\Reports\SEPTEMBER.XLSX');
    // Closing the dialog, which is not a path.
    expect(ensure(null), isNull);
    expect(ensure('   '), isNull);
  });

  test(
    'a month with no employees at all still writes a readable file',
    () async {
      final book = await writeAndRead(const []);

      expect(book.tables.containsKey('All'), isTrue);
      expect(text(book.tables['All']!, 0, 0), labels.title);
    },
  );
}
