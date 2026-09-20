import '../data_source/attendance_local_data_source.dart';
import '../models/attendance_record_model.dart';
import '../models/employee_import_models.dart';
import '../models/employee_model.dart';

class AttendanceRepo {
  final AttendanceLocalDataSource _dataSource;

  AttendanceRepo(this._dataSource);

  Future<List<EmployeeModel>> getEmployees() => _dataSource.getEmployees();

  Future<EmployeeModel?> getEmployeeById(String id) =>
      _dataSource.getEmployeeById(id);

  Future<List<AttendanceRecordModel>> getRecordsByDate(String date) =>
      _dataSource.getRecordsByDate(date);

  Future<List<AttendanceRecordModel>> getRecordsByEmployee(String employeeId) =>
      _dataSource.getRecordsByEmployee(employeeId);

  Future<AttendanceRecordModel?> findRecord(String employeeId, String date) =>
      _dataSource.findRecord(employeeId, date);

  Future<AttendanceRecordModel> createRecord(AttendanceRecordModel record) =>
      _dataSource.createRecord(record);

  Future<AttendanceRecordModel> updateRecord(
    String id,
    Map<String, dynamic> updates,
  ) => _dataSource.updateRecord(id, updates);

  Future<AttendanceRecordModel> correctPunches({
    required String recordId,
    String? checkInTime,
    String? checkOutTime,
    String? correctedBy,
  }) => _dataSource.correctPunches(
    recordId: recordId,
    checkInTime: checkInTime,
    checkOutTime: checkOutTime,
    correctedBy: correctedBy,
  );

  Future<EmployeeModel> createEmployee(Map<String, dynamic> data) =>
      _dataSource.createEmployee(data);

  Future<EmployeeModel> updateEmployee(String id, Map<String, dynamic> data) =>
      _dataSource.updateEmployee(id, data);

  Future<void> deleteEmployee(String id) => _dataSource.deleteEmployee(id);

  Future<EmployeeImportResult> importEmployees(List<EmployeeImportRow> rows) =>
      _dataSource.importEmployees(rows);

  Future<String> nextEmployeeNumber() => _dataSource.nextEmployeeNumber();

  /// Closes the gaps in the staff numbers so the list reads 001..N.
  Future<int> resequenceEmployeeNumbers() =>
      _dataSource.resequenceEmployeeNumbers();

  /// Employees who answer to the same name, for the admin to tell apart.
  Future<List<EmployeeNameClash>> findNameClashes() =>
      _dataSource.findNameClashes();

  Future<List<EmployeeModel>> getAllEmployees() =>
      _dataSource.getAllEmployees();

  Future<int> countMonthlyEarlyLeaves(String employeeId, String yearMonth) =>
      _dataSource.countMonthlyEarlyLeaves(employeeId, yearMonth);

  Future<List<AttendanceRecordModel>> getRecentRecords(int limit) =>
      _dataSource.getRecentRecords(limit);

  Future<List<AttendanceRecordModel>> getRecordsByDateRange(
    String startDate,
    String endDate,
  ) => _dataSource.getRecordsByDateRange(startDate, endDate);
}
