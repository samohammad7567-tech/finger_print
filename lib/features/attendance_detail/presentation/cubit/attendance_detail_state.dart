import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../attendance/data/models/employee_model.dart';

class AttendanceDetailState {
  final EmployeeModel? employee;
  final List<AttendanceRecordModel> records;
  final bool isLoading;
  final String? error;

  const AttendanceDetailState({
    this.employee,
    this.records = const [],
    this.isLoading = true,
    this.error,
  });

  int get presentCount => records.where((r) => r.status == 'present').length;
  int get lateCount => records.where((r) => r.status == 'late').length;
  int get absentCount => records.where((r) => r.status == 'absent').length;
  int get earlyLeaveCount =>
      records.where((r) => r.isEarlyLeave || r.status == 'early_leave').length;
  int get totalDays => records.length;

  int get attendanceRate => totalDays > 0
      ? ((presentCount + lateCount + earlyLeaveCount) * 100 ~/ totalDays)
      : 0;

  AttendanceDetailState copyWith({
    EmployeeModel? employee,
    List<AttendanceRecordModel>? records,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => AttendanceDetailState(
    employee: employee ?? this.employee,
    records: records ?? this.records,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}
