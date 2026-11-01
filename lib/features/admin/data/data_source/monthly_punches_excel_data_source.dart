import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/punch_pairs.dart';

/// One employee's one day, already formatted. The exporter writes cells and
/// works nothing out for itself.
class MonthlyPunchRow {
  final String date;
  final String dayName;
  final List<PunchPair> pairs;

  /// Who corrected this day, if anybody did. The whole point of the file is to
  /// settle an argument, and "an admin changed this" is part of the answer.
  final String corrected;

  const MonthlyPunchRow({
    required this.date,
    required this.dayName,
    this.pairs = const [],
    this.corrected = '',
  });

  /// The row padded to [pairCount] pairs, so every day fills every column.
  List<String> dayCells(int pairCount) => [
    date,
    dayName,
    for (var i = 0; i < pairCount; i++) ...[
      i < pairs.length ? (pairs[i].checkIn ?? '—') : '—',
      i < pairs.length ? (pairs[i].checkOut ?? '—') : '—',
    ],
    corrected,
  ];
}

/// One employee's month: their own tab, and their share of the combined sheet.
class MonthlyPunchEmployee {
  final String surname;
  final String name;
  final String personalId;
  final String accommodation;
  final String number;
  final String department;
  final List<MonthlyPunchRow> rows;

  /// Label/value pairs written under the days — worked, overtime, days present
  /// and so on. Named by the caller, since the words are the screen's.
  final List<({String label, String value})> totals;

  const MonthlyPunchEmployee({
    required this.name,
    required this.number,
    required this.department,
    required this.rows,
    this.surname = '',
    this.personalId = '',
    this.accommodation = '',
    this.totals = const [],
  });
}

/// Column headings and page furniture, translated by the caller.
class MonthlyPunchesExcelLabels {
  final String title;
  final String month;
  final String generatedAt;
  final String allSheet;
  final String serial;
  final String surname;
  final String employee;
  final String personalId;
  final String accommodation;
  final String traveler;
  final String overnight;
  final String employeeNumber;
  final String department;
  final String date;
  final String day;

  /// The headings for pair [index], numbered from one. A function rather than
  /// a list because the busiest day in the month is only known after it is read.
  final String Function(int index) pairCheckIn;
  final String Function(int index) pairCheckOut;

  final String breakTime;
  final String overtime;
  final String worked;
  final String corrected;
  final String totals;
  final String presentDays;
  final String absentDays;

  const MonthlyPunchesExcelLabels({
    required this.title,
    required this.month,
    required this.generatedAt,
    required this.allSheet,
    required this.serial,
    required this.surname,
    required this.employee,
    required this.personalId,
    required this.accommodation,
    required this.traveler,
    required this.overnight,
    required this.employeeNumber,
    required this.department,
    required this.date,
    required this.day,
    required this.pairCheckIn,
    required this.pairCheckOut,
    required this.breakTime,
    required this.overtime,
    required this.worked,
    required this.corrected,
    required this.totals,
    required this.presentDays,
    required this.absentDays,
  });

  /// The day columns, which both sheet shapes end with.
  List<String> dayHeaders(int pairCount) => [
    date,
    day,
    for (var i = 1; i <= pairCount; i++) ...[pairCheckIn(i), pairCheckOut(i)],
    corrected,
  ];

  /// The combined sheet names the person on every line, since a filter on it
  /// is how somebody looks at one employee across the whole workforce.
  List<String> allHeaders(int pairCount) => [
    serial,
    surname,
    employee,
    employeeNumber,
    department,
    personalId,
    accommodation,
    ...dayHeaders(pairCount),
  ];
}

/// Writes the month's punches to a real .xlsx workbook.
///
/// An employee who thinks their month is wrong needs something they can open,
/// sort and hand back — not a picture of a table. So this is a spreadsheet:
/// one combined sheet to filter across everybody, and a tab per person for the
/// conversation where you go through their days one by one.
class MonthlyPunchesExcelDataSource {
  /// Excel's own limits on a tab name: 31 characters, and none of these.
  static final _illegalInSheetName = RegExp(r'[\[\]\:\*\?\/\\]');
  static const _maxSheetName = 31;

  /// Asks the admin where the workbook should go.
  ///
  /// Returns the full path they chose, or null if they closed the dialog —
  /// which is an answer, not a failure, and the caller treats it as one.
  ///
  /// [initialDirectory] is where the dialog opens: the folder they used last
  /// time, so exporting the same report every month is one click after the
  /// first. [typeLabel] and [confirmLabel] arrive translated; a data source
  /// has no business knowing the language.
  Future<String?> pickDestination({
    required String fileName,
    required String typeLabel,
    String? initialDirectory,
    String? confirmLabel,
  }) async {
    final location = await getSaveLocation(
      suggestedName: fileName,
      initialDirectory: initialDirectory,
      confirmButtonText: confirmLabel,
      acceptedTypeGroups: [
        XTypeGroup(label: typeLabel, extensions: const ['xlsx']),
      ],
    );

    return withXlsxExtension(location?.path);
  }

  /// The chosen path, guaranteed to end in .xlsx.
  ///
  /// A dialog hands back exactly what was typed into it, and somebody typing
  /// their own name over the suggestion usually leaves the extension off.
  /// Excel will not open a file it cannot recognise, so it is put back.
  static String? withXlsxExtension(String? path) {
    final chosen = path?.trim();
    if (chosen == null || chosen.isEmpty) return null;
    return p.extension(chosen).toLowerCase() == '.xlsx'
        ? chosen
        : '$chosen.xlsx';
  }

  /// Writes [employees] and returns the file.
  ///
  /// [path] is where it goes when the admin chose somewhere. Without one — and
  /// [folder] is the test's way in — the file lands in the shared reports
  /// folder alongside the PDF exports, as it always did.
  Future<File> write({
    required List<MonthlyPunchEmployee> employees,
    required MonthlyPunchesExcelLabels labels,
    required String fileName,
    bool isArabic = false,
    String? path,
    Directory? folder,
  }) async {
    final book = Excel.createExcel();
    final taken = <String>{};

    var pairCount = 1;
    for (final employee in employees) {
      for (final row in employee.rows) {
        if (row.pairs.length > pairCount) pairCount = row.pairs.length;
      }
    }

    _writeAllSheet(book, employees, labels, isArabic, pairCount);
    taken.add(labels.allSheet);

    for (final employee in employees) {
      _writeEmployeeSheet(
        book,
        employee,
        labels,
        isArabic,
        _sheetName(employee, taken),
        pairCount,
      );
    }

    // createExcel seeds a 'Sheet1' nobody asked for. Removed last: a workbook
    // is not allowed to end up with no sheets at all, and by now it has ours.
    if (book.sheets.containsKey('Sheet1')) book.delete('Sheet1');

    final bytes = book.save(fileName: fileName);
    if (bytes == null) {
      throw const FileSystemException('the workbook produced no bytes');
    }

    final file = File(
      path ?? p.join((await _defaultFolder(folder)).path, fileName),
    );
    // The chosen folder exists — the dialog would not have offered it
    // otherwise — but a path typed by hand into it may name one that does not.
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Directory> _defaultFolder(Directory? override) async {
    final target =
        override ??
        Directory(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'GuardSync Reports',
          ),
        );
    await target.create(recursive: true);
    return target;
  }

  /// Hands the finished file to whatever the machine opens spreadsheets with.
  /// A failure here is not a failure of the export — the file is on disk.
  Future<void> open(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // Nothing to do: the admin still has the path.
    }
  }

  // ------------------------------------------------------------- the sheets

  void _writeAllSheet(
    Excel book,
    List<MonthlyPunchEmployee> employees,
    MonthlyPunchesExcelLabels labels,
    bool isArabic,
    int pairCount,
  ) {
    final sheet = book[labels.allSheet];
    sheet.isRTL = isArabic;

    _title(sheet, labels);
    _headerRow(sheet, labels.allHeaders(pairCount));

    var serial = 0;
    for (final employee in employees) {
      for (final row in employee.rows) {
        serial++;
        sheet.appendRow([
          TextCellValue('$serial'),
          TextCellValue(_orDash(employee.surname)),
          TextCellValue(_orDash(employee.name)),
          TextCellValue(_orDash(employee.number)),
          TextCellValue(_orDash(employee.department)),
          TextCellValue(_orDash(employee.personalId)),
          TextCellValue(_orDash(employee.accommodation)),
          ...row.dayCells(pairCount).map(TextCellValue.new),
        ]);
      }
    }

    _widths(sheet, [6, 18, 22, 11, 16, 18, 18, ..._dayWidths(pairCount)]);
  }

  void _writeEmployeeSheet(
    Excel book,
    MonthlyPunchEmployee employee,
    MonthlyPunchesExcelLabels labels,
    bool isArabic,
    String sheetName,
    int pairCount,
  ) {
    final sheet = book[sheetName];
    sheet.isRTL = isArabic;

    // The person is named once at the top rather than on all thirty lines —
    // this tab is already theirs.
    _bold(sheet, [TextCellValue(employee.name)]);
    sheet.appendRow([
      TextCellValue('${labels.surname}: ${_orDash(employee.surname)}'),
      TextCellValue('${labels.personalId}: ${_orDash(employee.personalId)}'),
      TextCellValue('${labels.accommodation}: ${_orDash(employee.accommodation)}'),
    ]);
    sheet.appendRow([
      TextCellValue('${labels.employeeNumber}: ${employee.number}'),
      TextCellValue('${labels.department}: ${employee.department}'),
    ]);
    sheet.appendRow([TextCellValue(labels.month)]);
    sheet.appendRow([]);

    _headerRow(sheet, labels.dayHeaders(pairCount));

    for (final row in employee.rows) {
      sheet.appendRow(row.dayCells(pairCount).map(TextCellValue.new).toList());
    }

    if (employee.totals.isNotEmpty) {
      sheet.appendRow([]);
      _bold(sheet, [TextCellValue(labels.totals)]);
      for (final total in employee.totals) {
        sheet.appendRow([
          TextCellValue(total.label),
          TextCellValue(total.value),
        ]);
      }
    }

    _widths(sheet, _dayWidths(pairCount));
  }

  // ------------------------------------------------------------- the pieces

  /// Date, day, a pair of scan columns for every pair in the month, then the
  /// correction trail.
  static List<double> _dayWidths(int pairCount) => [
    12,
    11,
    for (var i = 0; i < pairCount; i++) ...const [10, 10],
    18,
  ];

  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;

  void _title(Sheet sheet, MonthlyPunchesExcelLabels labels) {
    _bold(sheet, [TextCellValue(labels.title)]);
    sheet.appendRow([TextCellValue(labels.month)]);
    sheet.appendRow([TextCellValue(labels.generatedAt)]);
    sheet.appendRow([]);
  }

  /// The column headings, in bold so a sorted sheet still reads.
  void _headerRow(Sheet sheet, List<String> headers) =>
      _bold(sheet, headers.map(TextCellValue.new).toList());

  void _bold(Sheet sheet, List<CellValue> cells) {
    final row = sheet.maxRows;
    sheet.appendRow(cells);
    for (var column = 0; column < cells.length; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
          .cellStyle = CellStyle(
        bold: true,
      );
    }
  }

  void _widths(Sheet sheet, List<double> widths) {
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
  }

  /// A tab name Excel will accept, and that no other tab has already taken.
  ///
  /// Two people can share a name, and a workbook cannot share a tab, so a
  /// clash falls back to the staff number and then to a counter.
  String _sheetName(MonthlyPunchEmployee employee, Set<String> taken) {
    var base = employee.name.replaceAll(_illegalInSheetName, ' ').trim();
    if (base.isEmpty) base = employee.number.trim();
    if (base.isEmpty) base = 'employee';
    base = _clip(base);

    if (!taken.contains(base)) {
      taken.add(base);
      return base;
    }

    final numbered = _clip('$base ${employee.number}'.trim());
    if (numbered != base && !taken.contains(numbered)) {
      taken.add(numbered);
      return numbered;
    }

    for (var suffix = 2; ; suffix++) {
      final candidate = _clip('$base $suffix');
      if (taken.add(candidate)) return candidate;
    }
  }

  static String _clip(String name) => name.length <= _maxSheetName
      ? name
      : name.substring(0, _maxSheetName).trim();
}
