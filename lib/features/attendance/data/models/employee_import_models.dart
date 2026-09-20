import '../../../../core/utils/name_matching.dart';
import 'employee_model.dart';

/// One employee as read out of an import sheet, already normalized.
///
/// The workbook is somebody else's file — a payroll export, a list a manager
/// keeps — so nothing here is trusted to be tidy. By the time a row reaches
/// this class the blanks are null, the numbers are strings and the "yes/نعم"
/// columns are booleans; the database layer only has to decide whether the
/// person is already on file.
class EmployeeImportRow {
  /// The line in the workbook this came from, numbered as Excel numbers it.
  /// A skipped row is useless to the admin without it — "row 14" is how they
  /// find the problem in their own file.
  final int line;

  final String fullName;
  final String? employeeNumber;
  final String department;
  final String? position;
  final String? phone;
  final String? deviceUserId;
  final bool hasHousing;
  final bool hasTravelPermission;
  final bool isActive;

  const EmployeeImportRow({
    required this.line,
    required this.fullName,
    this.employeeNumber,
    this.department = '',
    this.position,
    this.phone,
    this.deviceUserId,
    this.hasHousing = false,
    this.hasTravelPermission = false,
    this.isActive = true,
  });

  /// The comparable form of the name, so "أحمد علي" and "احمد  علي" are one
  /// person and not two employees.
  String get nameKey => NameMatching.key(fullName);

  bool get hasName => nameKey.isNotEmpty;

  /// The shape `createEmployee` reads. An empty staff number means "give me
  /// the next one in the sequence" — exactly what the add-employee form does
  /// when the admin clears the field.
  Map<String, dynamic> toEmployeeData() => {
    'employee_id': employeeNumber ?? '',
    'full_name': fullName,
    'department': department,
    'position': position,
    'phone': phone,
    'device_user_id': deviceUserId,
    'has_housing': hasHousing,
    'has_travel_permission': hasTravelPermission,
    'is_active': isActive,
  };
}

/// A row that did not become an employee, and why.
///
/// [reasonKey] is a localization key, so the import reports its refusals
/// through the same path every other error in the app takes.
class EmployeeImportIssue {
  final int line;
  final String name;
  final String reasonKey;

  const EmployeeImportIssue({
    required this.line,
    required this.name,
    required this.reasonKey,
  });
}

/// What the import did.
///
/// A partial import is the normal outcome — one bad row must not throw away
/// the ninety good ones — so both halves are always reported.
class EmployeeImportResult {
  final List<EmployeeModel> created;
  final List<EmployeeImportIssue> skipped;

  const EmployeeImportResult({
    this.created = const [],
    this.skipped = const [],
  });

  int get createdCount => created.length;
  int get skippedCount => skipped.length;
  bool get hasCreated => created.isNotEmpty;
  bool get hasSkipped => skipped.isNotEmpty;
}

/// Employees on file who answer to the same name.
///
/// Raised whenever two records normalise to one name, whether they arrived from
/// the terminal, a spreadsheet or the form. The app cannot settle it: two people
/// really do share a name, and the only one who knows which case this is — and
/// what to call them so the list stays readable — is the admin.
class EmployeeNameClash {
  /// The normalised name all of them share, for grouping and for tests.
  final String nameKey;

  final List<EmployeeModel> employees;

  const EmployeeNameClash({required this.nameKey, required this.employees});

  /// The ones the terminal recognises. When this is empty the clash is two
  /// hand-entered records; when it holds more than one, they are certainly
  /// different people, because a fingerprint enrolment cannot be shared.
  List<EmployeeModel> get enrolled =>
      employees.where((e) => (e.deviceUserId ?? '').isNotEmpty).toList();

  /// Certainly different people: more than one of them is enrolled under a
  /// different id on the terminal, so no rename can merge them and none should.
  bool get isDefinitelyDistinct => enrolled.length > 1;
}
