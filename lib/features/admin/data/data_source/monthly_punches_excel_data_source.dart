import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One employee's one day, already formatted. The exporter writes cells and
/// works nothing out for itself.
class MonthlyPunchRow {
  final String date;
  final String dayName;
  final String checkIn;
  final String checkOut;
  final String breaks;
  final String breakTime;
  final String overtime;
  final String worked;
  final String status;

  /// Who corrected this day, if anybody did. The whole point of the file is to
  /// settle an argument, and "an admin changed this" is part of the answer.
  final String corrected;

  const MonthlyPunchRow({
    required this.date,
    required this.dayName,
    required this.checkIn,
    required this.checkOut,
    required this.breaks,
    required this.breakTime,
    required this.overtime,
    required this.worked,
    required this.status,
    this.corrected = '',
  });

  List<String> get dayCells => [
    date,
    dayName,
    checkIn,
    checkOut,
    breaks,
    breakTime,
    overtime,
    worked,
    status,
    corrected,
  ];
}

/// One employee's month: their own tab, and their share of the combined sheet.
class MonthlyPunchEmployee {
  final String name;
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
    this.totals = const [],
  });
}

/// Column headings and page furniture, translated by the caller.
class MonthlyPunchesExcelLabels {
  final String title;
  final String month;
  final String generatedAt;
  final String allSheet;
  final String employee;
  final String employeeNumber;
  final String department;
  final String date;
  final String day;
  final String checkIn;
  final String checkOut;
  final String breaks;
  final String breakTime;
  final String overtime;
  final String worked;
  final String status;
  final String corrected;
  final String totals;
  final String presentDays;
  final String absentDays;

  const MonthlyPunchesExcelLabels({
    required this.title,
    required this.month,
    required this.generatedAt,
    required this.allSheet,
    required this.employee,
    required this.employeeNumber,
    required this.department,
    required this.date,
    required this.day,
    required this.checkIn,
    required this.checkOut,
    required this.breaks,
    required this.breakTime,
    required this.overtime,
    required this.worked,
    required this.status,
    required this.corrected,
    required this.totals,
    required this.presentDays,
    required this.absentDays,
  });

  /// The day columns, which both sheet shapes end with.
  List<String> get dayHeaders => [
    date,
    day,
    checkIn,
    checkOut,
    breaks,
    breakTime,
    overtime,
    worked,
    status,
    corrected,
  ];

  /// The combined sheet names the person on every line, since a filter on it
  /// is how somebody looks at one employee across the whole workforce.
  List<String> get allHeaders => [
    employee,
    employeeNumber,
    department,
    ...dayHeaders,
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

    _writeAllSheet(book, employees, labels, isArabic);
    taken.add(labels.allSheet);

    for (final employee in employees) {
      _writeEmployeeSheet(
        book,
        employee,
        labels,
        isArabic,
        _sheetName(employee, taken),
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
  ) {
    final sheet = book[labels.allSheet];
    sheet.isRTL = isArabic;

    _title(sheet, labels);
    _headerRow(sheet, labels.allHeaders);

    for (final employee in employees) {
      for (final row in employee.rows) {
        sheet.appendRow([
          TextCellValue(employee.name),
          TextCellValue(employee.number),
          TextCellValue(employee.department),
          ...row.dayCells.map(TextCellValue.new),
        ]);
      }
    }

    _widths(sheet, [22, 11, 16, ...(_dayWidths)]);
  }

  void _writeEmployeeSheet(
    Excel book,
    MonthlyPunchEmployee employee,
    MonthlyPunchesExcelLabels labels,
    bool isArabic,
    String sheetName,
  ) {
    final sheet = book[sheetName];
    sheet.isRTL = isArabic;

    // The person is named once at the top rather than on all thirty lines —
    // this tab is already theirs.
    _bold(sheet, [TextCellValue(employee.name)]);
    sheet.appendRow([
      TextCellValue('${labels.employeeNumber}: ${employee.number}'),
      TextCellValue('${labels.department}: ${employee.department}'),
    ]);
    sheet.appendRow([TextCellValue(labels.month)]);
    sheet.appendRow([]);

    _headerRow(sheet, labels.dayHeaders);

    for (final row in employee.rows) {
      sheet.appendRow(row.dayCells.map(TextCellValue.new).toList());
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

    _widths(sheet, _dayWidths);
  }

  // ------------------------------------------------------------- the pieces

  static const _dayWidths = <double>[12, 11, 10, 10, 26, 12, 11, 11, 14, 18];

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
