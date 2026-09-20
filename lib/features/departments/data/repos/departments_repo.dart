import '../data_source/departments_local_data_source.dart';
import '../models/department_model.dart';

/// Thin delegation over the departments table.
class DepartmentsRepo {
  final DepartmentsLocalDataSource _dataSource;

  DepartmentsRepo(this._dataSource);

  Future<List<DepartmentModel>> getDepartments() =>
      _dataSource.getDepartments();

  Future<DepartmentModel> createDepartment(String name) =>
      _dataSource.createDepartment(name);

  Future<DepartmentModel> renameDepartment(
    DepartmentModel department,
    String name,
  ) => _dataSource.renameDepartment(department, name);

  Future<void> deleteDepartment(DepartmentModel department) =>
      _dataSource.deleteDepartment(department);
}
