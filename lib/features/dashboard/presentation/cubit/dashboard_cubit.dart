import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final AttendanceRepo _repo;

  DashboardCubit(this._repo) : super(const DashboardState());

  Future<void> load() async {
    try {
      final today = getTodayDate();
      final records = await _repo.getRecordsByDate(today);
      emit(
        state.copyWith(records: records, isLoading: false, clearError: true),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorLoadFailed));
    }
  }

  Future<void> refresh() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    await load();
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
