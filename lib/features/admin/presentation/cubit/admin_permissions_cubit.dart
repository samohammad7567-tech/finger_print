import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../permissions/data/models/permission_request_model.dart';
import '../../../permissions/data/repos/permissions_repo.dart';

class AdminPermissionsState {
  final List<PermissionRequestModel> permissions;
  final List<EmployeeModel> employees;
  final bool isLoading;
  final String filter;
  final bool showForm;
  final bool isSaving;
  final String? error;

  const AdminPermissionsState({
    this.permissions = const [],
    this.employees = const [],
    this.isLoading = true,
    this.filter = 'all',
    this.showForm = false,
    this.isSaving = false,
    this.error,
  });

  List<PermissionRequestModel> get filtered {
    if (filter == 'all') return permissions;
    return permissions.where((p) => p.status == filter).toList();
  }

  AdminPermissionsState copyWith({
    List<PermissionRequestModel>? permissions,
    List<EmployeeModel>? employees,
    bool? isLoading,
    String? filter,
    bool? showForm,
    bool? isSaving,
    String? error,
  }) => AdminPermissionsState(
    permissions: permissions ?? this.permissions,
    employees: employees ?? this.employees,
    isLoading: isLoading ?? this.isLoading,
    filter: filter ?? this.filter,
    showForm: showForm ?? this.showForm,
    isSaving: isSaving ?? this.isSaving,
    error: error,
  );
}

class AdminPermissionsCubit extends Cubit<AdminPermissionsState> {
  final PermissionsRepo _repo;
  final AttendanceRepo _attendanceRepo;

  AdminPermissionsCubit(this._repo, this._attendanceRepo)
    : super(const AdminPermissionsState());

  Future<void> load() async {
    try {
      emit(state.copyWith(isLoading: true));
      final results = await Future.wait([
        _repo.getAllPermissions(),
        _attendanceRepo.getEmployees(),
      ]);
      emit(
        state.copyWith(
          permissions: results[0] as List<PermissionRequestModel>,
          employees: results[1] as List<EmployeeModel>,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorLoadFailed));
    }
  }

  void setFilter(String value) => emit(state.copyWith(filter: value));

  void toggleForm(bool show) => emit(state.copyWith(showForm: show));

  Future<void> updateStatus(String id, String status) async {
    try {
      await _repo.updatePermissionStatus(id, status, 'Manager');
      await load();
    } catch (e) {
      emit(state.copyWith(error: LangKeys.errorSaveFailed));
    }
  }

  Future<void> savePermission({
    required String employeeId,
    required String employeeName,
    required String permissionType,
    required String date,
    String? reason,
    String? approvedBy,
  }) async {
    try {
      if (permissionType == 'vacation') {
        final yearMonth = date.substring(0, 7);
        final count = await _repo.countMonthlyVacations(employeeId, yearMonth);
        if (count >= 2) {
          emit(
            state.copyWith(showForm: true, error: LangKeys.vacationLimitError),
          );
          return;
        }
      }

      emit(state.copyWith(showForm: true, isSaving: true));

      final existing = await _repo.findExistingPermission(
        employeeId,
        date,
        permissionType,
      );
      if (existing != null) {
        emit(
          state.copyWith(
            isSaving: false,
            error: LangKeys.permissionAlreadyExists,
          ),
        );
        return;
      }

      final perm = await _repo.createPermission(
        PermissionRequestModel(
          id: '',
          employeeId: employeeId,
          employeeName: employeeName,
          permissionType: permissionType,
          date: date,
          reason: reason,
          approvedBy: approvedBy,
        ),
      );

      emit(
        state.copyWith(
          permissions: [perm, ...state.permissions],
          showForm: false,
          isSaving: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: LangKeys.errorSaveFailed));
    }
  }

  void clearError() => emit(state.copyWith(error: null));
}
