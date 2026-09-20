import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';

class DayStats {
  final String date;
  final int present;
  final int late;
  final int absent;
  const DayStats({
    required this.date,
    this.present = 0,
    this.late = 0,
    this.absent = 0,
  });
  int get total => present + late + absent;
}

class DeptStat {
  final String department;
  final int rate;
  const DeptStat({required this.department, required this.rate});
}

class AdminReportsState {
  final List<DayStats> last7Days;
  final List<DeptStat> deptStats;
  final bool isLoading;
  final String? error;

  const AdminReportsState({
    this.last7Days = const [],
    this.deptStats = const [],
    this.isLoading = true,
    this.error,
  });

  AdminReportsState copyWith({
    List<DayStats>? last7Days,
    List<DeptStat>? deptStats,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => AdminReportsState(
    last7Days: last7Days ?? this.last7Days,
    deptStats: deptStats ?? this.deptStats,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class AdminReportsCubit extends Cubit<AdminReportsState> {
  final AttendanceRepo _repo;

  AdminReportsCubit(this._repo) : super(const AdminReportsState());

  Future<void> load() async {
    try {
      emit(state.copyWith(isLoading: true));

      final startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now().subtract(const Duration(days: 6)));
      final endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final results = await Future.wait([
        _repo.getRecordsByDateRange(startDate, endDate),
        _repo.getEmployees(),
      ]);
      final records = results[0] as List<AttendanceRecordModel>;
      final employees = results[1] as List<EmployeeModel>;

      final employeeDeptMap = <String, String>{};
      for (final emp in employees) {
        employeeDeptMap[emp.id] = emp.department;
      }

      final last7 = List.generate(7, (i) {
        final d = DateTime.now().subtract(Duration(days: 6 - i));
        return DateFormat('yyyy-MM-dd').format(d);
      });

      final dayStats = last7.map((date) {
        final dayRecs = records.where((r) => r.date == date);
        return DayStats(
          date: date.substring(5),
          present: dayRecs
              .where((r) => r.status == 'present' || r.status == 'late')
              .length,
          late: dayRecs.where((r) => r.status == 'late').length,
          absent: dayRecs.where((r) => r.status == 'absent').length,
        );
      }).toList();

      final deptMap = <String, (int present, int total)>{};
      for (final r in records) {
        final dept = employeeDeptMap[r.employeeId] ?? 'Unknown';
        final current = deptMap[dept] ?? (0, 0);
        final isPresent = r.status == 'present' || r.status == 'late';
        deptMap[dept] = (current.$1 + (isPresent ? 1 : 0), current.$2 + 1);
      }
      final deptStats =
          deptMap.entries
              .map(
                (e) => DeptStat(
                  department: e.key,
                  rate: e.value.$2 > 0 ? (e.value.$1 * 100 ~/ e.value.$2) : 0,
                ),
              )
              .toList()
            ..sort((a, b) => b.rate.compareTo(a.rate));

      emit(
        state.copyWith(
          last7Days: dayStats,
          deptStats: deptStats.take(10).toList(),
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorLoadFailed));
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
