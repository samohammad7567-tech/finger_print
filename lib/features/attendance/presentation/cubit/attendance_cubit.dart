import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../data/models/attendance_record_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/repos/attendance_repo.dart';
import 'attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepo _repo;

  AttendanceCubit(this._repo) : super(const AttendanceState());

  Future<void> load() async {
    try {
      final today = getTodayDate();
      final results = await Future.wait([
        _repo.getEmployees(),
        _repo.getRecordsByDate(today),
      ]);
      emit(
        state.copyWith(
          employees: results[0] as List<EmployeeModel>,
          records: results[1] as List<AttendanceRecordModel>,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorLoadFailed));
    }
  }

  void setSearch(String value) => emit(state.copyWith(search: value));

  void setFilter(String value) => emit(state.copyWith(activeFilter: value));

  void clearError() => emit(state.copyWith(clearError: true));
}
