import '../../../attendance/data/models/attendance_record_model.dart';

class DashboardState {
  final List<AttendanceRecordModel> records;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.records = const [],
    this.isLoading = true,
    this.error,
  });

  int get present => records.where((r) => r.status == 'present').length;
  int get late => records.where((r) => r.status == 'late').length;
  int get absent => records.where((r) => r.status == 'absent').length;
  int get earlyLeave =>
      records.where((r) => r.isEarlyLeave || r.status == 'early_leave').length;

  DashboardState copyWith({
    List<AttendanceRecordModel>? records,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => DashboardState(
    records: records ?? this.records,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}
