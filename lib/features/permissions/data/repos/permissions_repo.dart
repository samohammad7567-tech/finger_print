import '../data_source/permissions_local_data_source.dart';
import '../models/permission_request_model.dart';

class PermissionsRepo {
  final PermissionsLocalDataSource _dataSource;

  PermissionsRepo(this._dataSource);

  Future<List<PermissionRequestModel>> getPermissions() =>
      _dataSource.getPermissions();

  Future<PermissionRequestModel> createPermission(
    PermissionRequestModel perm,
  ) => _dataSource.createPermission(perm);

  Future<PermissionRequestModel> updatePermissionStatus(
    String id,
    String status,
    String approvedBy,
  ) => _dataSource.updatePermissionStatus(id, status, approvedBy);

  Future<int> countMonthlyVacations(String employeeId, String yearMonth) =>
      _dataSource.countMonthlyVacations(employeeId, yearMonth);

  Future<List<PermissionRequestModel>> getPermissionsByDate(String date) =>
      _dataSource.getPermissionsByDate(date);

  Future<List<PermissionRequestModel>> getAllPermissions() =>
      _dataSource.getAllPermissions();

  Future<List<PermissionRequestModel>> getPermissionsByDateRange(
    String startDate,
    String endDate,
  ) => _dataSource.getPermissionsByDateRange(startDate, endDate);

  Future<PermissionRequestModel?> findExistingPermission(
    String employeeId,
    String date,
    String type,
  ) => _dataSource.findExistingPermission(employeeId, date, type);
}
