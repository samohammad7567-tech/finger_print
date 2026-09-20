import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/name_matching.dart';
import '../../../attendance/data/models/employee_import_models.dart';

/// The words the blank template writes into its header row and its example
/// lines, translated by the caller — a data source has no business knowing the
/// language.
class EmployeeImportLabels {
  final String sheetName;
  final String fullName;
  final String employeeNumber;
  final String department;
  final String position;
  final String phone;
  final String deviceUserId;
  final String housing;
  final String travel;
  final String active;
  final String yes;
  final String no;
  final String sampleName;
  final String sampleDepartment;
  final String samplePosition;

  const EmployeeImportLabels({
    required this.sheetName,
    required this.fullName,
    required this.employeeNumber,
    required this.department,
    required this.position,
    required this.phone,
    required this.deviceUserId,
    required this.housing,
    required this.travel,
    required this.active,
    required this.yes,
    required this.no,
    required this.sampleName,
    required this.sampleDepartment,
    required this.samplePosition,
  });

  List<String> get headers => [
    employeeNumber,
    fullName,
    department,
    position,
    phone,
    deviceUserId,
    housing,
    travel,
    active,
  ];
}

/// Reads a workbook of employees the admin already keeps somewhere else.
///
/// The file is not ours, so it is not told what to look like beyond one thing:
/// a header row naming its columns. Those headings are matched against the
/// spellings people actually use, in Arabic and in English, in whatever order
/// the sheet has them, with columns we know nothing about simply ignored. Only
/// the name column is required — everything else is optional, and a blank
/// staff number is filled from the app's own sequence.
///
/// Nothing here writes to the database. It turns a file into rows; deciding
/// who is already on file belongs to the data source that owns the table.
class EmployeeImportExcelDataSource {
  // ------------------------------------------------------------- the columns

  static const _fullName = 'full_name';
  static const _employeeNumber = 'employee_number';
  static const _department = 'department';
  static const _position = 'position';
  static const _phone = 'phone';
  static const _deviceUserId = 'device_user_id';
  static const _housing = 'housing';
  static const _travel = 'travel';
  static const _active = 'active';

  /// Header spellings this recognises, compared through [NameMatching.key] so
  /// case, spacing, punctuation and the Arabic letter forms stop mattering.
  ///
  /// Order is load-bearing: a heading is offered to each field in turn, and the
  /// device column is asked first so a sheet headed "Device ID" does not lose
  /// it to the staff number's much looser "id".
  static const _aliases = <String, List<String>>{
    _deviceUserId: [
      'device user id',
      'device id',
      'device user',
      'terminal id',
      'fingerprint id',
      'fingerprint',
      'معرف المستخدم على الجهاز',
      'معرف المستخدم',
      'معرف الجهاز',
      'رقم الجهاز',
      'رقم البصمة',
      'البصمة',
    ],
    _fullName: [
      'full name',
      'employee name',
      'staff name',
      'name',
      'الاسم الكامل',
      'اسم الموظف',
      'الاسم',
      'الموظف',
    ],
    _employeeNumber: [
      'employee number',
      'employee id',
      'employee no',
      'staff number',
      'staff id',
      'emp id',
      'emp no',
      'number',
      'code',
      'id',
      'الرقم الوظيفي',
      'رقم الموظف',
      'رقم الملف',
      'الرقم',
    ],
    _department: ['department', 'dept', 'section', 'القسم', 'الإدارة'],
    _position: [
      'job title',
      'position',
      'title',
      'role',
      'job',
      'المسمى الوظيفي',
      'الوظيفة',
      'المنصب',
    ],
    _phone: [
      'phone number',
      'mobile number',
      'phone',
      'mobile',
      'contact',
      'tel',
      'رقم الهاتف',
      'رقم الجوال',
      'الهاتف',
      'الجوال',
    ],
    _housing: [
      'has housing',
      'housing',
      'accommodation',
      'لديه سكن',
      'السكن',
      'سكن',
    ],
    _travel: [
      'travel permission',
      'has travel',
      'travel',
      'إذن السفر',
      'تصريح السفر',
      'السفر',
      'سفر',
    ],
    _active: [
      'is active',
      'active',
      'status',
      'state',
      'الحالة',
      'نشط',
      'فعال',
    ],
  };

  /// How far down the sheet the header row is looked for. A file that opens
  /// with a company name and a blank line is normal; one that hides its
  /// headings twenty rows down is not a list of employees.
  static const _headerScanDepth = 15;

  /// Words that mean yes, in either language. Anything that is neither these
  /// nor a recognised no leaves the column at its default.
  static const _trueWords = [
    '1',
    'true',
    'yes',
    'y',
    'active',
    'enabled',
    'نعم',
    'صح',
    'يوجد',
    'لديه',
    'متوفر',
    'نشط',
    'فعال',
    'مفعل',
  ];

  static const _falseWords = [
    '0',
    'false',
    'no',
    'n',
    'none',
    'inactive',
    'disabled',
    'لا',
    'ليس',
    'لا يوجد',
    'غير نشط',
    'غير فعال',
    'موقوف',
    'معطل',
  ];

  // --------------------------------------------------------------- the file

  /// Asks the admin which workbook to read.
  ///
  /// Returns null when they close the dialog, which is an answer and not a
  /// failure — the caller treats it as one.
  Future<String?> pickFile({
    required String typeLabel,
    String? initialDirectory,
    String? confirmLabel,
  }) async {
    final file = await openFile(
      initialDirectory: initialDirectory,
      confirmButtonText: confirmLabel,
      acceptedTypeGroups: [
        XTypeGroup(label: typeLabel, extensions: const ['xlsx']),
      ],
    );
    return file?.path;
  }

  /// Reads [path] and returns everybody it names.
  ///
  /// Throws [ApiException] carrying a localization key when the file cannot be
  /// read at all, or when no sheet in it has a column of names — both are
  /// things the admin has to fix in the file, so they are told which.
  Future<List<EmployeeImportRow>> read(String path) async {
    if (p.extension(path).toLowerCase() != '.xlsx') {
      throw const ApiException(LangKeys.importUnsupportedFile);
    }

    final Excel book;
    try {
      book = Excel.decodeBytes(await File(path).readAsBytes());
    } catch (e) {
      throw ApiException(LangKeys.importUnreadableFile, detail: e.toString());
    }

    var sawNameColumn = false;
    for (final sheet in book.tables.values) {
      final rows = _readSheet(sheet);
      if (rows == null) continue;
      sawNameColumn = true;
      // A sheet with headings and nothing under them is somebody's leftover
      // tab; keep looking before giving up on the workbook.
      if (rows.isNotEmpty) return rows;
    }

    if (!sawNameColumn) throw const ApiException(LangKeys.importNoNameColumn);
    return const [];
  }

  /// The rows of one sheet, or null when it has no name column and so is not a
  /// list of employees at all.
  List<EmployeeImportRow>? _readSheet(Sheet sheet) {
    final table = sheet.rows;
    final limit = table.length < _headerScanDepth
        ? table.length
        : _headerScanDepth;

    for (var index = 0; index < limit; index++) {
      final columns = _resolveColumns(table[index]);
      if (!columns.containsKey(_fullName)) continue;

      final rows = <EmployeeImportRow>[];
      for (var line = index + 1; line < table.length; line++) {
        // Numbered as Excel numbers it, so a skipped row can be found again.
        final row = _readRow(table[line], columns, line + 1);
        if (row != null) rows.add(row);
      }
      return rows;
    }
    return null;
  }

  /// Which column holds what, for the headings in [header].
  Map<String, int> _resolveColumns(List<Data?> header) {
    final headings = [for (final cell in header) NameMatching.key(_text(cell))];
    final columns = <String, int>{};
    final claimed = <int>{};

    void claim(String field, int column) {
      columns[field] = column;
      claimed.add(column);
    }

    // Exact headings first, so a sheet that says exactly what it means is
    // never talked out of it by another field's looser spelling.
    for (final entry in _aliases.entries) {
      for (var column = 0; column < headings.length; column++) {
        if (claimed.contains(column) || columns.containsKey(entry.key))
          continue;
        final match = entry.value.any(
          (alias) => NameMatching.key(alias) == headings[column],
        );
        if (match) claim(entry.key, column);
      }
    }

    // Then headings that merely contain a known word — "Employee Full Name"
    // and the rest of what real files are headed.
    for (final entry in _aliases.entries) {
      if (columns.containsKey(entry.key)) continue;
      for (var column = 0; column < headings.length; column++) {
        if (claimed.contains(column) || headings[column].isEmpty) continue;
        final match = entry.value.any((alias) {
          final key = NameMatching.key(alias);
          return key.length > 2 && headings[column].contains(key);
        });
        if (match) {
          claim(entry.key, column);
          break;
        }
      }
    }

    return columns;
  }

  /// One employee, or null when the line is blank.
  ///
  /// A line with something on it but no name is kept: it becomes a skipped row
  /// the admin can go and look at, which is more use than silence.
  EmployeeImportRow? _readRow(
    List<Data?> cells,
    Map<String, int> columns,
    int line,
  ) {
    String read(String field) {
      final column = columns[field];
      if (column == null || column >= cells.length) return '';
      return _text(cells[column]);
    }

    final values = {for (final field in columns.keys) field: read(field)};
    if (values.values.every((text) => text.isEmpty)) return null;

    return EmployeeImportRow(
      line: line,
      fullName: values[_fullName] ?? '',
      employeeNumber: _orNull(values[_employeeNumber]),
      department: values[_department] ?? '',
      position: _orNull(values[_position]),
      phone: _orNull(values[_phone]),
      deviceUserId: _orNull(values[_deviceUserId]),
      hasHousing: _flag(values[_housing], fallback: false),
      hasTravelPermission: _flag(values[_travel], fallback: false),
      // A row nobody marked is a working employee — the column is usually
      // absent altogether.
      isActive: _flag(values[_active], fallback: true),
    );
  }

  // ------------------------------------------------------------ the template

  /// Asks where the blank template should be saved.
  Future<String?> pickTemplateDestination({
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

    final chosen = location?.path.trim();
    if (chosen == null || chosen.isEmpty) return null;
    // A dialog hands back exactly what was typed into it, and somebody typing
    // over the suggestion usually leaves the extension off.
    return p.extension(chosen).toLowerCase() == '.xlsx'
        ? chosen
        : '$chosen.xlsx';
  }

  /// Writes an empty sheet with the headings this reader understands, and two
  /// filled-in lines showing what a row looks like.
  ///
  /// The alternative is the admin guessing at column names and finding out
  /// they guessed wrong only after the import reports nothing.
  Future<File> writeTemplate({
    required String path,
    required EmployeeImportLabels labels,
    bool isArabic = false,
  }) async {
    final book = Excel.createExcel();
    final sheet = book[labels.sheetName];
    sheet.isRTL = isArabic;

    sheet.appendRow(labels.headers.map(TextCellValue.new).toList());
    for (var column = 0; column < labels.headers.length; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
      );
    }

    // The examples leave the staff number blank on one line and fill it on the
    // other, because both are allowed: blank takes the next number in
    // sequence. The device id is blank throughout — only enrolment sets that.
    _example(sheet, [
      '',
      labels.sampleName,
      labels.sampleDepartment,
      labels.samplePosition,
      '0500000000',
      '',
      labels.yes,
      labels.yes,
      labels.yes,
    ]);
    _example(sheet, [
      'EMP014',
      labels.sampleName,
      labels.sampleDepartment,
      '',
      '',
      '',
      labels.no,
      labels.no,
      labels.yes,
    ]);

    const widths = <double>[14, 26, 18, 18, 16, 14, 10, 10, 10];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }

    // createExcel seeds a 'Sheet1' nobody asked for. Removed last: a workbook
    // is not allowed to end up with no sheets at all, and by now it has ours.
    if (book.sheets.containsKey('Sheet1')) book.delete('Sheet1');

    final bytes = book.save(fileName: p.basename(path));
    if (bytes == null) {
      throw const FileSystemException('the template produced no bytes');
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  void _example(Sheet sheet, List<String> cells) =>
      sheet.appendRow(cells.map(TextCellValue.new).toList());

  /// Hands the template to whatever the machine opens spreadsheets with. A
  /// failure here is not a failure of the write — the file is on disk.
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

  // -------------------------------------------------------------- the cells

  /// A cell as text, whatever the sheet stored in it.
  ///
  /// Staff numbers and phone numbers are routinely typed as numbers, and Excel
  /// hands those back as doubles — 5.05e8 is not a phone number anybody can
  /// dial, so whole values are written out whole.
  static String _text(Data? cell) {
    final value = cell?.value;
    return switch (value) {
      null => '',
      TextCellValue v => v.value.toString().trim(),
      IntCellValue v => '${v.value}',
      DoubleCellValue v => _number(v.value),
      BoolCellValue v => v.value ? 'true' : 'false',
      DateCellValue v => v.asDateTimeLocal().toIso8601String(),
      // A formula cell carries the formula, not its result; there is nothing
      // useful to read out of it.
      FormulaCellValue _ => '',
      _ => value.toString().trim(),
    };
  }

  static String _number(double value) =>
      value == value.roundToDouble() && value.abs() < 1e15
      ? value.toInt().toString()
      : value.toString();

  static String? _orNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// A yes/no column, in either language, falling back to [fallback] for a
  /// blank cell or a word nobody here recognises.
  static bool _flag(String? value, {required bool fallback}) {
    final key = NameMatching.key(value ?? '');
    if (key.isEmpty) return fallback;
    if (_trueWords.any((word) => NameMatching.key(word) == key)) return true;
    if (_falseWords.any((word) => NameMatching.key(word) == key)) return false;
    return fallback;
  }
}
