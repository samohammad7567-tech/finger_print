import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../data/models/permission_request_model.dart';
import '../../data/repos/permissions_repo.dart';
import 'permissions_state.dart';

class PermissionsCubit extends Cubit<PermissionsState> {
  final PermissionsRepo _permRepo;
  final AttendanceRepo _attendanceRepo;

  PermissionsCubit(this._permRepo, this._attendanceRepo)
    : super(const PermissionsState());

  Future<void> load({bool openForm = false}) async {
    try {
      emit(state.copyWith(isLoading: true));
      final results = await Future.wait([
        _permRepo.getPermissions(),
        _attendanceRepo.getEmployees(),
      ]);
      emit(
        state.copyWith(
          permissions: results[0] as List<PermissionRequestModel>,
          employees: results[1] as List<EmployeeModel>,
          isLoading: false,
          showForm: openForm,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorLoadFailed));
    }
  }

  void setSearch(String value) => emit(state.copyWith(search: value));

  void toggleForm(bool show) => emit(state.copyWith(showForm: show));

  Future<void> savePermission({
    required String employeeId,
    required String employeeName,
    required String permissionType,
    required String date,
    String? reason,
    String? approvedBy,
  }) async {
    try {
      emit(state.copyWith(isSaving: true));

      final existing = await _permRepo.findExistingPermission(
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

      final perm = await _permRepo.createPermission(
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

  void clearError() => emit(state.copyWith(clearError: true));
}
