import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/models/attendance_record_model.dart';

class CheckInState {
  final String mode;
  final String search;
  final List<EmployeeModel> allEmployees;
  final EmployeeModel? selected;
  final String time;
  final String notes;
  final bool isLoading;
  final bool isSuccess;
  final Map<String, AttendanceRecordModel> todayRecords;
  final Set<String> todayVacationIds;
  final String? errorMessage;

  const CheckInState({
    this.mode = 'checkin',
    this.search = '',
    this.allEmployees = const [],
    this.selected,
    this.time = '',
    this.notes = '',
    this.isLoading = false,
    this.isSuccess = false,
    this.todayRecords = const {},
    this.todayVacationIds = const {},
    this.errorMessage,
  });

  List<EmployeeModel> get filteredEmployees {
    if (search.length <= 1) return allEmployees;
    final q = search.toLowerCase();
    return allEmployees
        .where(
          (e) =>
              e.fullName.toLowerCase().contains(q) ||
              (e.employeeId?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  String? employeeDisabledReason(String employeeId) {
    final record = todayRecords[employeeId];
    final hasVacation = todayVacationIds.contains(employeeId);

    switch (mode) {
      case 'checkin':
        if (hasVacation) return 'on_leave';
        if (record?.status == 'absent') return 'marked_absent';
        if (record?.status == 'travel_permission') return 'has_permission';
        if (record?.checkInTime != null) return 'already_checked_in';
        return null;
      case 'checkout':
        if (hasVacation) return 'on_leave';
        if (record?.status == 'absent') return 'marked_absent';
        if (record?.status == 'travel_permission') return 'has_permission';
        if (record?.checkOutTime != null) return 'already_checked_out';
        return null;
      case 'absent':
        if (hasVacation) return 'on_leave';
        if (record != null) return 'already_recorded';
        return null;
      default:
        if (hasVacation) return 'on_leave';
        if (record?.status == 'travel_permission') return 'already_recorded';
        if (record?.status == 'absent') return 'marked_absent';
        return null;
    }
  }

  CheckInState copyWith({
    String? mode,
    String? search,
    List<EmployeeModel>? allEmployees,
    EmployeeModel? selected,
    String? time,
    String? notes,
    bool? isLoading,
    bool? isSuccess,
    Map<String, AttendanceRecordModel>? todayRecords,
    Set<String>? todayVacationIds,
    String? errorMessage,
    bool clearSelected = false,
    bool clearError = false,
  }) => CheckInState(
    mode: mode ?? this.mode,
    search: search ?? this.search,
    allEmployees: allEmployees ?? this.allEmployees,
    selected: clearSelected ? null : (selected ?? this.selected),
    time: time ?? this.time,
    notes: notes ?? this.notes,
    isLoading: isLoading ?? this.isLoading,
    isSuccess: isSuccess ?? this.isSuccess,
    todayRecords: todayRecords ?? this.todayRecords,
    todayVacationIds: todayVacationIds ?? this.todayVacationIds,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}
