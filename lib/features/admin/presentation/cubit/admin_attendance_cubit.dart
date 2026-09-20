import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../attendance/data/models/attendance_day_totals.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../permissions/data/models/permission_request_model.dart';
import '../../../permissions/data/repos/permissions_repo.dart';
import '../../../holidays/data/repos/holidays_repo.dart';
import '../../../shifts/data/repos/shifts_repo.dart';
import '../../data/data_source/monthly_report_pdf_data_source.dart';
import '../../data/repos/monthly_report_pdf_repo.dart';

class EmployeeMonthlySummary {
  final EmployeeModel employee;
  final int presentDays;
  final int lateTimes;
  final int earlyLeaveTimes;
  final int totalLateMinutes;
  final int absentDays;
  final int permissionDays;

  /// Overtime earned across the month, inside the window the admin set.
  ///
  /// A day somebody only turned up for after hours is an absence and still
  /// contributes here: the day was missed, the extra hours were worked.
  final int totalOvertimeMinutes;

  const EmployeeMonthlySummary({
    required this.employee,
    this.presentDays = 0,
    this.lateTimes = 0,
    this.earlyLeaveTimes = 0,
    this.totalLateMinutes = 0,
    this.absentDays = 0,
    this.permissionDays = 0,
    this.totalOvertimeMinutes = 0,
  });

  String get lateHoursFormatted => formatMinutes(totalLateMinutes);

  String get overtimeFormatted => formatMinutes(totalOvertimeMinutes);

  static String formatMinutes(int minutes) =>
      '${minutes ~/ 60}h ${minutes % 60}m';
}

class AdminAttendanceState {
  final bool isMonthlyView;
  final DateTime selectedDate;
  final List<EmployeeModel> employees;
  final List<AttendanceRecordModel> records;
  final List<PermissionRequestModel> permissions;
  final List<EmployeeMonthlySummary> monthlySummaries;
  final bool isLoading;

  /// A PDF is being written. Its own flag so the button can say so while the
  /// table stays on screen.
  final bool isExportingPdf;

  final String search;
  final String? error;

  /// A one-shot success key the screen shows as a toast, then drops.
  final String? message;

  const AdminAttendanceState({
    this.isMonthlyView = false,
    required this.selectedDate,
    this.employees = const [],
    this.records = const [],
    this.permissions = const [],
    this.monthlySummaries = const [],
    this.isLoading = true,
    this.isExportingPdf = false,
    this.search = '',
    this.error,
    this.message,
  });

  AdminAttendanceState copyWith({
    bool? isMonthlyView,
    DateTime? selectedDate,
    List<EmployeeModel>? employees,
    List<AttendanceRecordModel>? records,
    List<PermissionRequestModel>? permissions,
    List<EmployeeMonthlySummary>? monthlySummaries,
    bool? isLoading,
    bool? isExportingPdf,
    String? search,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return AdminAttendanceState(
      isMonthlyView: isMonthlyView ?? this.isMonthlyView,
      selectedDate: selectedDate ?? this.selectedDate,
      employees: employees ?? this.employees,
      records: records ?? this.records,
      permissions: permissions ?? this.permissions,
      monthlySummaries: monthlySummaries ?? this.monthlySummaries,
      isLoading: isLoading ?? this.isLoading,
      isExportingPdf: isExportingPdf ?? this.isExportingPdf,
      search: search ?? this.search,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  String get dateStr => DateFormat('yyyy-MM-dd').format(selectedDate);
  String get monthStr => DateFormat('yyyy-MM').format(selectedDate);

  List<EmployeeDayRow> get dailyRows {
    final q = search.toLowerCase();
    return employees
        .where((e) {
          if (q.isEmpty) return true;
          return e.fullName.toLowerCase().contains(q) ||
              (e.employeeId?.toLowerCase().contains(q) ?? false);
        })
        .map((emp) {
          final rec = records.cast<AttendanceRecordModel?>().firstWhere(
            (r) => r!.employeeId == emp.id,
            orElse: () => null,
          );
          final perm = permissions.cast<PermissionRequestModel?>().firstWhere(
            (p) => p!.employeeId == emp.id,
            orElse: () => null,
          );
          return EmployeeDayRow(employee: emp, record: rec, permission: perm);
        })
        .toList();
  }

  List<EmployeeMonthlySummary> get filteredSummaries {
    if (search.isEmpty) return monthlySummaries;
    final q = search.toLowerCase();
    return monthlySummaries
        .where(
          (s) =>
              s.employee.fullName.toLowerCase().contains(q) ||
              (s.employee.employeeId?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }
}

class EmployeeDayRow {
  final EmployeeModel employee;
  final AttendanceRecordModel? record;
  final PermissionRequestModel? permission;
  const EmployeeDayRow({required this.employee, this.record, this.permission});
}

class AdminAttendanceCubit extends Cubit<AdminAttendanceState> {
  final AttendanceRepo _repo;
  final PermissionsRepo _permissionsRepo;

  /// Supplies each employee's working day, and the company default behind it.
  /// It replaced a plain settings read once a person's hours stopped being the
  /// whole company's.
  final ShiftsRepo _shiftsRepo;

  /// Which of the month's dates anybody was expected to work. Without it a
  /// rest day would be counted against everybody who did not scan on it.
  final HolidaysRepo _holidaysRepo;

  final MonthlyReportPdfRepo _pdf;

  AdminAttendanceCubit(
    this._repo,
    this._permissionsRepo,
    this._shiftsRepo,
    this._holidaysRepo,
    this._pdf,
  ) : super(AdminAttendanceState(selectedDate: DateTime.now()));

  Future<void> loadDay([DateTime? date]) async {
    final d = date ?? state.selectedDate;
    emit(
      state.copyWith(selectedDate: d, isMonthlyView: false, isLoading: true),
    );

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final results = await Future.wait([
        _repo.getEmployees(),
        _repo.getRecordsByDate(dateStr),
        _permissionsRepo.getPermissionsByDate(dateStr),
      ]);

      emit(
        state.copyWith(
          selectedDate: d,
          isMonthlyView: false,
          employees: results[0] as List<EmployeeModel>,
          records: results[1] as List<AttendanceRecordModel>,
          permissions: results[2] as List<PermissionRequestModel>,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          selectedDate: d,
          isMonthlyView: false,
          isLoading: false,
          error: LangKeys.errorLoadFailed,
        ),
      );
    }
  }

  Future<void> loadMonth([DateTime? date]) async {
    final d = date ?? state.selectedDate;
    emit(state.copyWith(selectedDate: d, isMonthlyView: true, isLoading: true));

    try {
      final startDate = '${d.year}-${d.month.toString().padLeft(2, '0')}-01';
      final daysInMonth = DateTime(d.year, d.month + 1, 0).day;
      final endDate =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${daysInMonth.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        _repo.getEmployees(),
        _repo.getRecordsByDateRange(startDate, endDate),
        _permissionsRepo.getPermissionsByDateRange(startDate, endDate),
      ]);

      final employees = results[0] as List<EmployeeModel>;
      final allRecords = results[1] as List<AttendanceRecordModel>;
      final allPermissions = results[2] as List<PermissionRequestModel>;

      // Read once for the whole month rather than per employee: the figures
      // below must all come from one reading of the shifts, or a shift edited
      // mid-loop would leave half the month judged by the old hours.
      final schedules = await _shiftsRepo.getSchedules();
      final calendar = await _holidaysRepo.getCalendar();

      final summaries = employees.map((emp) {
        final empRecords = allRecords
            .where((r) => r.employeeId == emp.id)
            .toList();
        final empPerms = allPermissions
            .where((p) => p.employeeId == emp.id)
            .toList();

        int lateTimes = 0;
        int earlyLeaveTimes = 0;
        int totalLateMinutes = 0;
        int absentDays = 0;
        int presentDays = 0;
        int totalOvertimeMinutes = 0;

        // This employee's own working day — their shift's, or the company
        // default when they are on none.
        final schedule = schedules.of(emp);

        for (final r in empRecords) {
          // One reading of the day for all of it. The status comes from here
          // rather than the column, so a day whose times say the working day
          // was missed counts as an absence straight away — without waiting
          // for a re-sync to rewrite the row.
          final totals = AttendanceDayTotals.forEmployee(
            record: r,
            employee: emp,
            schedule: schedule,
            dayKind: calendar.kindOfDate(r.date, schedule),
          );
          final status = totals.status;

          // A rest day or a holiday counts towards none of the month's
          // figures. Somebody who came in on a Friday is not late for it, and
          // somebody who did not is not absent.
          if (!isWorkingDay(totals.dayKind)) {
            totalOvertimeMinutes += totals.overtime?.inMinutes ?? 0;
            continue;
          }

          if (status == 'absent') {
            absentDays++;
          } else if (status == 'present' || status == 'late') {
            presentDays++;
          }
          if (status == 'late' && r.checkInTime != null) {
            final lateMins =
                timeToMinutes(r.checkInTime) - schedule.workStartMinutes;
            lateTimes++;
            if (lateMins > 0) totalLateMinutes += lateMins;
          }
          if (r.isEarlyLeave || status == 'early_leave') {
            earlyLeaveTimes++;
          }
          totalOvertimeMinutes += totals.overtime?.inMinutes ?? 0;
        }

        return EmployeeMonthlySummary(
          employee: emp,
          presentDays: presentDays,
          lateTimes: lateTimes,
          earlyLeaveTimes: earlyLeaveTimes,
          totalLateMinutes: totalLateMinutes,
          absentDays: absentDays,
          permissionDays: empPerms.length,
          totalOvertimeMinutes: totalOvertimeMinutes,
        );
      }).toList();

      emit(
        state.copyWith(
          selectedDate: d,
          isMonthlyView: true,
          employees: employees,
          records: allRecords,
          permissions: allPermissions,
          monthlySummaries: summaries,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          selectedDate: d,
          isMonthlyView: true,
          isLoading: false,
          error: LangKeys.errorLoadFailed,
        ),
      );
    }
  }

  /// Writes the month on screen to a PDF and hands it to the machine's viewer.
  ///
  /// There is nothing to choose first: it exports exactly the summaries the
  /// admin is looking at, search filter and all. [labels] arrive already
  /// translated, because the words on the page belong to the screen that asked
  /// for the file, not here.
  Future<void> exportMonthlyPdf({
    required MonthlyReportPdfLabels labels,
    required bool isArabic,
  }) async {
    final summaries = state.filteredSummaries;
    if (state.isExportingPdf || summaries.isEmpty) return;

    emit(
      state.copyWith(
        isExportingPdf: true,
        clearError: true,
        clearMessage: true,
      ),
    );

    try {
      final rows = summaries
          .map(
            (s) => MonthlyReportPdfRow(
              name: s.employee.fullName,
              department: s.employee.department,
              presentDays: '${s.presentDays}',
              lateTimes: '${s.lateTimes}',
              earlyLeave: '${s.earlyLeaveTimes}',
              absentDays: '${s.absentDays}',
              permissionDays: '${s.permissionDays}',
              lateHours: s.lateHoursFormatted,
              overtime: s.overtimeFormatted,
            ),
          )
          .toList();

      final lateMinutes = summaries.fold<int>(
        0,
        (sum, s) => sum + s.totalLateMinutes,
      );
      final overtimeMinutes = summaries.fold<int>(
        0,
        (sum, s) => sum + s.totalOvertimeMinutes,
      );

      final file = await _pdf.write(
        rows: rows,
        labels: labels,
        isArabic: isArabic,
        fileName: 'monthly-report-${state.monthStr}.pdf',
        totals: [
          '${labels.presentDays}: '
              '${summaries.fold<int>(0, (sum, s) => sum + s.presentDays)}',
          '${labels.lateTimes}: '
              '${summaries.fold<int>(0, (sum, s) => sum + s.lateTimes)}',
          '${labels.absentDays}: '
              '${summaries.fold<int>(0, (sum, s) => sum + s.absentDays)}',
          '${labels.lateHours}: '
              '${EmployeeMonthlySummary.formatMinutes(lateMinutes)}',
          '${labels.overtime}: '
              '${EmployeeMonthlySummary.formatMinutes(overtimeMinutes)}',
        ],
      );

      emit(
        state.copyWith(isExportingPdf: false, message: LangKeys.reportPdfSaved),
      );
      await _pdf.open(file.path);
      _clearMessage();
    } catch (_) {
      emit(
        state.copyWith(isExportingPdf: false, error: LangKeys.reportPdfFailed),
      );
    }
  }

  /// A one-shot banner: the UI shows it, then it clears itself so returning to
  /// the screen later does not replay a stale success message.
  void _clearMessage() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!isClosed && state.message != null) {
        emit(state.copyWith(clearMessage: true));
      }
    });
  }

  void setSearch(String value) {
    emit(state.copyWith(search: value));
  }

  void toggleView() {
    if (state.isMonthlyView) {
      loadDay();
    } else {
      loadMonth();
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));

  void clearMessage() => emit(state.copyWith(clearMessage: true));
}
