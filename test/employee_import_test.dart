import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/localization/lang_keys.dart';
import 'package:attendence/core/network/api_exception.dart';
import 'package:attendence/features/admin/data/data_source/employee_import_excel_data_source.dart';
import 'package:attendence/features/attendance/data/data_source/attendance_local_data_source.dart';

/// The employee import. The workbook is somebody else's file, so the parsing
/// is checked against the shapes real lists come in — a title row above the
/// headings, columns in whatever order, staff numbers typed as numbers, and
/// headings in either language.
void main() {
  late Directory folder;
  late EmployeeImportExcelDataSource excel;
  late AppDatabase database;
  late AttendanceLocalDataSource attendance;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('guardsync-import-test');
    excel = EmployeeImportExcelDataSource();
    database = AppDatabase();
    await database.init(overridePath: inMemoryDatabasePath);
    attendance = AttendanceLocalDataSource(database);
  });

  tearDown(() async {
    await database.close();
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  /// Writes a sheet and hands back its path.
  Future<String> workbook(
    List<List<CellValue?>> rows, {
    String name = 'Sheet1',
  }) async {
    final book = Excel.createExcel();
    final sheet = book[name];
    for (final row in rows) {
      sheet.appendRow(row);
    }
    if (name != 'Sheet1' && book.sheets.containsKey('Sheet1')) {
      book.delete('Sheet1');
    }

    final path = p.join(folder.path, 'employees.xlsx');
    await File(path).writeAsBytes(book.save()!);
    return path;
  }

  CellValue? text(String value) => TextCellValue(value);

  test(
    'reads an English sheet with a title row and columns in any order',
    () async {
      final path = await workbook([
        [text('Staff list — September')],
        // A spacer line above the headings, as real files have.
        [text('')],
        [
          text('Department'),
          text('Full Name'),
          text('Employee No'),
          text('Mobile'),
          text('Housing'),
        ],
        [
          text('Operations'),
          text('Sara Nasser'),
          // Staff and phone numbers are routinely typed as numbers.
          IntCellValue(1042),
          DoubleCellValue(555123456),
          text('yes'),
        ],
        [text('Gate'), text('Omar Adel'), null, null, text('no')],
      ]);

      final rows = await excel.read(path);

      expect(rows, hasLength(2));
      expect(rows.first.fullName, 'Sara Nasser');
      expect(rows.first.department, 'Operations');
      expect(rows.first.employeeNumber, '1042');
      expect(rows.first.phone, '555123456');
      expect(rows.first.hasHousing, isTrue);
      // The line number is the one the admin sees in Excel.
      expect(rows.first.line, 4);

      expect(rows.last.employeeNumber, isNull);
      expect(rows.last.hasHousing, isFalse);
      // Nobody said otherwise, so they work here.
      expect(rows.last.isActive, isTrue);
    },
  );

  test('reads Arabic headings, and the Arabic words for yes and no', () async {
    final path = await workbook([
      [
        text('اسم الموظف'),
        text('القسم'),
        text('الرقم الوظيفي'),
        text('لديه سكن'),
        text('الحالة'),
      ],
      [
        text('أحمد علي'),
        text('الأمن'),
        text('EMP007'),
        text('نعم'),
        text('غير نشط'),
      ],
    ]);

    final rows = await excel.read(path);

    expect(rows, hasLength(1));
    expect(rows.single.fullName, 'أحمد علي');
    expect(rows.single.employeeNumber, 'EMP007');
    expect(rows.single.hasHousing, isTrue);
    expect(rows.single.isActive, isFalse);
  });

  test('a device id column is not mistaken for the staff number', () async {
    final path = await workbook([
      [text('Name'), text('Device ID'), text('ID')],
      [text('Layla'), text('12'), text('EMP003')],
    ]);

    final rows = await excel.read(path);

    expect(rows.single.deviceUserId, '12');
    expect(rows.single.employeeNumber, 'EMP003');
  });

  test('a sheet with no name column is refused, and says why', () async {
    final path = await workbook([
      [text('Date'), text('Check in'), text('Check out')],
      [text('2026-09-01'), text('08:00'), text('17:00')],
    ]);

    expect(
      () => excel.read(path),
      throwsA(
        isA<ApiException>().having(
          (e) => e.errorKey,
          'errorKey',
          LangKeys.importNoNameColumn,
        ),
      ),
    );
  });

  test(
    'only .xlsx is read, and the older format is named as the problem',
    () async {
      final path = p.join(folder.path, 'employees.xls');
      await File(path).writeAsString('not a workbook');

      expect(
        () => excel.read(path),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorKey,
            'errorKey',
            LangKeys.importUnsupportedFile,
          ),
        ),
      );
    },
  );

  test('the template it writes is a file it can read back', () async {
    // Exactly the strings ar.json hands the widget, brackets and all: the
    // template is the file the admin fills in, so its own headings have to be
    // ones the reader recognises.
    const labels = EmployeeImportLabels(
      sheetName: 'موظف',
      fullName: 'الاسم الكامل',
      employeeNumber: 'رقم الموظف',
      department: 'القسم',
      position: 'المسمى الوظيفي',
      phone: 'رقم الهاتف',
      deviceUserId: 'معرّف المستخدم على الجهاز',
      housing: 'يملك سكن (مغادرة 4:30 م)',
      travel: 'إذن سفر خميس (مغادرة 2:00 م)',
      active: 'موظف نشط',
      yes: 'نعم',
      no: 'لا',
      sampleName: 'أحمد علي',
      sampleDepartment: 'الأمن',
      samplePosition: 'حارس',
    );

    final path = p.join(folder.path, 'template.xlsx');
    await excel.writeTemplate(path: path, labels: labels, isArabic: true);

    final rows = await excel.read(path);

    expect(rows, hasLength(2));
    expect(rows.first.fullName, 'أحمد علي');
    expect(rows.first.department, 'الأمن');
    expect(rows.first.position, 'حارس');
    expect(rows.first.phone, '0500000000');
    expect(rows.first.hasHousing, isTrue);
    expect(rows.first.hasTravelPermission, isTrue);
    expect(rows.first.isActive, isTrue);
    expect(rows.last.employeeNumber, 'EMP014');
    expect(rows.last.hasHousing, isFalse);
    expect(rows.last.hasTravelPermission, isFalse);
  });

  test(
    'the English headings the template is given are recognised too',
    () async {
      final path = await workbook([
        [
          text('Employee ID'),
          text('Full Name'),
          text('Department'),
          text('Position'),
          text('Phone'),
          text('Device user ID'),
          text('Has Housing (leaves 4:30 PM)'),
          text('Thursday Travel (leaves 2:00 PM)'),
          text('Active Employee'),
        ],
        [
          text('EMP021'),
          text('Nour Salem'),
          text('Ops'),
          text('Supervisor'),
          text('0500000000'),
          text('31'),
          text('yes'),
          text('no'),
          text('no'),
        ],
      ]);

      final row = (await excel.read(path)).single;

      expect(row.employeeNumber, 'EMP021');
      expect(row.fullName, 'Nour Salem');
      expect(row.department, 'Ops');
      expect(row.position, 'Supervisor');
      expect(row.phone, '0500000000');
      expect(row.deviceUserId, '31');
      expect(row.hasHousing, isTrue);
      expect(row.hasTravelPermission, isFalse);
      expect(row.isActive, isFalse);
    },
  );

  test('imports the good rows and reports every refusal', () async {
    await attendance.createEmployee({
      'full_name': 'ابو خالد',
      'department': 'Gate',
    });

    final path = await workbook([
      [text('Full name'), text('Department'), text('Employee number')],
      [text('Sara Nasser'), text('Ops'), null],
      // Already on file, spelled with the other alef.
      [text('أبو خالد'), text('Gate'), null],
      // No name, but the line is not empty — worth telling the admin about.
      [null, text('Ops'), text('EMP900')],
      [text('Sara Nasser'), text('Ops'), null],
      [text('Omar Adel'), text('Gate'), text('EMP555')],
    ]);

    final result = await attendance.importEmployees(await excel.read(path));

    expect(result.createdCount, 2);
    expect(
      result.created.map((e) => e.fullName),
      containsAll(['Sara Nasser', 'Omar Adel']),
    );
    // A blank staff number is filled from the app's own sequence.
    expect(result.created.first.employeeId, isNotEmpty);
    expect(
      result.created.firstWhere((e) => e.fullName == 'Omar Adel').employeeId,
      'EMP555',
    );

    expect(result.skipped.map((i) => i.reasonKey), [
      LangKeys.importRowDuplicateName,
      LangKeys.importRowNoName,
      LangKeys.importRowRepeatedInFile,
    ]);
    expect(result.skipped.map((i) => i.line), [3, 4, 5]);

    // The workforce grew by exactly the two rows that were accepted.
    expect(await attendance.getAllEmployees(), hasLength(3));
  });

  test(
    'a staff number already in use is refused, not silently renumbered',
    () async {
      await attendance.createEmployee({
        'full_name': 'Layla',
        'department': 'Ops',
        'employee_id': 'EMP777',
      });

      final path = await workbook([
        [text('Name'), text('Employee number')],
        [text('Nour'), text('EMP777')],
      ]);

      final result = await attendance.importEmployees(await excel.read(path));

      expect(result.createdCount, 0);
      expect(
        result.skipped.single.reasonKey,
        LangKeys.errorDuplicateEmployeeNumber,
      );
    },
  );
}
