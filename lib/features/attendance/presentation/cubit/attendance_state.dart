import '../../data/models/attendance_record_model.dart';
import '../../data/models/employee_model.dart';

class AttendanceState {
  final List<EmployeeModel> employees;
  final List<AttendanceRecordModel> records;
  final bool isLoading;
  final String search;
  final String activeFilter;
  final String? error;

  const AttendanceState({
    this.employees = const [],
    this.records = const [],
    this.isLoading = true,
    this.search = '',
    this.activeFilter = 'all',
    this.error,
  });

  List<MergedEmployee> get filtered {
    final merged = employees.map((emp) {
      final rec = records.cast<AttendanceRecordModel?>().firstWhere(
        (r) => r!.employeeId == emp.id,
        orElse: () => null,
      );
      return MergedEmployee(emp, rec);
    }).toList();

    return merged.where((e) {
      final matchSearch =
          search.isEmpty ||
          e.employee.fullName.toLowerCase().contains(search.toLowerCase()) ||
          (e.employee.employeeId?.toLowerCase().contains(
                search.toLowerCase(),
              ) ??
              false);
      final status = e.record?.status ?? 'pending';
      final matchFilter =
          activeFilter == 'all' ||
          (activeFilter == 'early_leave'
              ? (e.record?.isEarlyLeave == true ||
                    e.record?.status == 'early_leave')
              : status == activeFilter);
      return matchSearch && matchFilter;
    }).toList();
  }

  AttendanceState copyWith({
    List<EmployeeModel>? employees,
    List<AttendanceRecordModel>? records,
    bool? isLoading,
    String? search,
    String? activeFilter,
    String? error,
    bool clearError = false,
  }) => AttendanceState(
    employees: employees ?? this.employees,
    records: records ?? this.records,
    isLoading: isLoading ?? this.isLoading,
    search: search ?? this.search,
    activeFilter: activeFilter ?? this.activeFilter,
    error: clearError ? null : (error ?? this.error),
  );
}

class MergedEmployee {
  final EmployeeModel employee;
  final AttendanceRecordModel? record;
  const MergedEmployee(this.employee, this.record);
}
