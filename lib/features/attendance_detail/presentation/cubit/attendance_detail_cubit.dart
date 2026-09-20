import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import 'attendance_detail_state.dart';

class AttendanceDetailCubit extends Cubit<AttendanceDetailState> {
  final AttendanceRepo _repo;

  AttendanceDetailCubit(this._repo) : super(const AttendanceDetailState());

  Future<void> load(String employeeId) async {
    try {
      final results = await Future.wait([
        _repo.getEmployeeById(employeeId),
        _repo.getRecordsByEmployee(employeeId),
      ]);
      emit(
        state.copyWith(
          employee: results[0] as EmployeeModel?,
          records: results[1] as List<AttendanceRecordModel>,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorLoadFailed));
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
