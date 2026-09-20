import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';

class AdminDashboardState {
  final int totalEmployees;
  final int present;
  final int absent;
  final int late;
  final int earlyLeave;
  final int totalRecords;
  final bool isLoading;
  final String? error;

  const AdminDashboardState({
    this.totalEmployees = 0,
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.earlyLeave = 0,
    this.totalRecords = 0,
    this.isLoading = true,
    this.error,
  });

  AdminDashboardState copyWith({
    int? totalEmployees,
    int? present,
    int? absent,
    int? late,
    int? earlyLeave,
    int? totalRecords,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => AdminDashboardState(
    totalEmployees: totalEmployees ?? this.totalEmployees,
    present: present ?? this.present,
    absent: absent ?? this.absent,
    late: late ?? this.late,
    earlyLeave: earlyLeave ?? this.earlyLeave,
    totalRecords: totalRecords ?? this.totalRecords,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );

  int get unregistered =>
      (totalEmployees - totalRecords).clamp(0, totalEmployees);
  int get attendanceRate => totalEmployees > 0
      ? ((present + late + earlyLeave) * 100 ~/ totalEmployees)
      : 0;
}

class AdminDashboardCubit extends Cubit<AdminDashboardState> {
  final AttendanceRepo _repo;

  AdminDashboardCubit(this._repo) : super(const AdminDashboardState());

  Future<void> load() async {
    try {
      emit(state.copyWith(isLoading: true));
      final today = getTodayDate();
      final results = await Future.wait([
        _repo.getRecordsByDate(today),
        _repo.getEmployees(),
      ]);
      final records = results[0] as List<AttendanceRecordModel>;
      final employees = results[1] as List<EmployeeModel>;

      emit(
        state.copyWith(
          totalEmployees: employees.length,
          present: records.where((r) => r.status == 'present').length,
          absent: records.where((r) => r.status == 'absent').length,
          late: records.where((r) => r.status == 'late').length,
          earlyLeave: records
              .where((r) => r.isEarlyLeave || r.status == 'early_leave')
              .length,
          totalRecords: records.length,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorLoadFailed));
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
