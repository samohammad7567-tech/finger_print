import '../../../attendance/data/models/employee_model.dart';
import '../../data/models/permission_request_model.dart';

class PermissionsState {
  final List<PermissionRequestModel> permissions;
  final List<EmployeeModel> employees;
  final bool isLoading;
  final String search;
  final bool showForm;
  final bool isSaving;
  final String? error;

  const PermissionsState({
    this.permissions = const [],
    this.employees = const [],
    this.isLoading = true,
    this.search = '',
    this.showForm = false,
    this.isSaving = false,
    this.error,
  });

  List<PermissionRequestModel> get filtered {
    if (search.isEmpty) return permissions;
    return permissions
        .where(
          (p) =>
              p.employeeName?.toLowerCase().contains(search.toLowerCase()) ??
              false,
        )
        .toList();
  }

  PermissionsState copyWith({
    List<PermissionRequestModel>? permissions,
    List<EmployeeModel>? employees,
    bool? isLoading,
    String? search,
    bool? showForm,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) => PermissionsState(
    permissions: permissions ?? this.permissions,
    employees: employees ?? this.employees,
    isLoading: isLoading ?? this.isLoading,
    search: search ?? this.search,
    showForm: showForm ?? this.showForm,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
  );
}
