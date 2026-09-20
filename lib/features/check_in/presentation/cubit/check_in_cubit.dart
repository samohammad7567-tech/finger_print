import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../admin/data/models/admin_notification_model.dart';
import '../../../admin/data/repos/admin_notifications_repo.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../permissions/data/repos/permissions_repo.dart';
import '../../../shifts/data/repos/shifts_repo.dart';
import 'check_in_state.dart';

class CheckInCubit extends Cubit<CheckInState> {
  final AttendanceRepo _repo;
  final PermissionsRepo _permissionsRepo;
  final AdminNotificationsRepo _adminNotificationsRepo;

  /// Supplies the working day this employee is judged by. A guard scanning
  /// somebody in has to be told they are late by their own shift's start, not
  /// by the company's — which is all the settings repo used to be read for
  /// here, so it is no longer a dependency.
  final ShiftsRepo _shiftsRepo;

  CheckInCubit(
    this._repo,
    this._permissionsRepo,
    this._adminNotificationsRepo,
    this._shiftsRepo,
  ) : super(const CheckInState());

  bool _isInitialized = false;

  Future<void> init(String mode) async {
    if (_isInitialized) {
      emit(state.copyWith(mode: mode));
      return;
    }
    try {
      _isInitialized = true;
      final employees = await _repo.getEmployees();
      final today = getTodayDate();
      final records = await _repo.getRecordsByDate(today);
      final permissions = await _permissionsRepo.getPermissionsByDate(today);

      final recordsMap = <String, AttendanceRecordModel>{};
      for (final r in records) {
        recordsMap[r.employeeId] = r;
      }

      final vacationIds = <String>{};
      for (final p in permissions) {
        if (p.permissionType == 'vacation') {
          vacationIds.add(p.employeeId);
        }
      }

      emit(
        state.copyWith(
          mode: mode,
          allEmployees: employees,
          todayRecords: recordsMap,
          todayVacationIds: vacationIds,
          time: getCurrentTime(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: LangKeys.errorLoadFailed));
    }
  }

  Future<void> _refreshTodayRecords() async {
    final today = getTodayDate();
    final records = await _repo.getRecordsByDate(today);
    final recordsMap = <String, AttendanceRecordModel>{};
    for (final r in records) {
      recordsMap[r.employeeId] = r;
    }
    emit(state.copyWith(todayRecords: recordsMap));
  }

  void setMode(String mode) {
    emit(state.copyWith(mode: mode, clearSelected: true, search: ''));
  }

  void setSearch(String value) {
    emit(state.copyWith(search: value));
  }

  void selectEmployee(EmployeeModel emp) {
    final reason = state.employeeDisabledReason(emp.id);
    if (reason != null) return;
    emit(state.copyWith(selected: emp));
  }

  void clearSelection() {
    emit(state.copyWith(clearSelected: true));
  }

  void clearError() => emit(state.copyWith(clearError: true));

  void setTime(String time) => emit(state.copyWith(time: time));

  void setNotes(String notes) => emit(state.copyWith(notes: notes));

  Future<void> submit(String? guardName) async {
    final selected = state.selected;
    if (selected == null) return;

    final reason = state.employeeDisabledReason(selected.id);
    if (reason != null) {
      emit(state.copyWith(errorMessage: reason));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final today = getTodayDate();
      final existing = await _repo.findRecord(selected.id, today);

      if (state.mode == 'checkout') {
        await _handleCheckout(selected, today, existing, guardName);
      } else {
        await _handleOtherModes(selected, today, existing, guardName);
      }

      emit(state.copyWith(isLoading: false, isSuccess: true));
      await Future.delayed(const Duration(seconds: 2));

      await _refreshTodayRecords();

      emit(
        state.copyWith(
          isSuccess: false,
          clearSelected: true,
          search: '',
          notes: '',
          time: getCurrentTime(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: LangKeys.errorSaveFailed,
        ),
      );
    }
  }

  Future<void> _handleCheckout(
    EmployeeModel employee,
    String today,
    AttendanceRecordModel? existing,
    String? guardName,
  ) async {
    final schedules = await _shiftsRepo.getSchedules();
    final earlyLeave = isEarlyCheckout(
      state.time,
      hasHousing: employee.hasHousing,
      hasTravelPermission: employee.hasTravelPermission,
      schedule: schedules.of(employee),
    );

    if (existing != null) {
      final updates = <String, dynamic>{
        'check_out_time': state.time,
        'is_early_leave': earlyLeave,
      };
      if (state.notes.isNotEmpty) updates['notes'] = state.notes;
      await _repo.updateRecord(existing.id, updates);
    } else {
      await _repo.createRecord(
        AttendanceRecordModel(
          id: '',
          employeeId: employee.id,
          employeeName: employee.fullName,
          date: today,
          status: 'present',
          checkOutTime: state.time,
          guardName: guardName,
          notes: state.notes.isNotEmpty ? state.notes : null,
          isEarlyLeave: earlyLeave,
        ),
      );
    }

    if (earlyLeave) {
      await _checkEarlyLeaveThreshold(employee);
    }
  }

  Future<void> _handleOtherModes(
    EmployeeModel employee,
    String today,
    AttendanceRecordModel? existing,
    String? guardName,
  ) async {
    String status;
    switch (state.mode) {
      case 'checkin':
        // Their shift decides what counts as late here. Housing and travel
        // then move the end of this person's day, and that is the line an
        // arrival is judged absent against.
        final schedules = await _shiftsRepo.getSchedules();
        status = computeCheckInStatus(
          state.time,
          hasHousing: employee.hasHousing,
          hasTravelPermission: employee.hasTravelPermission,
          schedule: schedules.of(employee),
        );
      case 'absent':
        status = 'absent';
      default:
        status = 'travel_permission';
    }

    if (existing != null) {
      final updates = <String, dynamic>{'status': status};
      if (state.mode == 'checkin') updates['check_in_time'] = state.time;
      if (state.notes.isNotEmpty) updates['notes'] = state.notes;
      await _repo.updateRecord(existing.id, updates);
    } else {
      await _repo.createRecord(
        AttendanceRecordModel(
          id: '',
          employeeId: employee.id,
          employeeName: employee.fullName,
          date: today,
          status: status,
          checkInTime: state.mode == 'checkin' ? state.time : null,
          guardName: guardName,
          notes: state.notes.isNotEmpty ? state.notes : null,
        ),
      );
    }
  }

  Future<void> _checkEarlyLeaveThreshold(EmployeeModel employee) async {
    final now = DateTime.now();
    final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final alreadyNotified = await _adminNotificationsRepo
        .hasNotificationForEmployeeMonth(employee.id, yearMonth);
    if (alreadyNotified) return;

    final count = await _repo.countMonthlyEarlyLeaves(employee.id, yearMonth);
    if (count > 3) {
      await _adminNotificationsRepo.createNotification(
        AdminNotificationModel(
          id: '',
          type: 'early_leave_threshold',
          employeeId: employee.id,
          employeeName: employee.fullName,
          message: 'early_leave_threshold_msg',
          date: getTodayDate(),
          earlyLeaveCount: count,
        ),
      );
    }
  }
}
