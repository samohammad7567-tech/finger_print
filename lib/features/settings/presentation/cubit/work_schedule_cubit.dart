import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/work_schedule.dart';
import '../../data/repos/settings_repo.dart';

class WorkScheduleState {
  /// What is on the form, saved or not.
  final WorkSchedule schedule;

  /// True once the form differs from what is stored.
  final bool isDirty;

  final String? error;
  final String? message;

  const WorkScheduleState({
    this.schedule = const WorkSchedule(),
    this.isDirty = false,
    this.error,
    this.message,
  });

  bool get canSave => isDirty && schedule.isValid;

  WorkScheduleState copyWith({
    WorkSchedule? schedule,
    bool? isDirty,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) => WorkScheduleState(
    schedule: schedule ?? this.schedule,
    isDirty: isDirty ?? this.isDirty,
    error: clearError ? null : (error ?? this.error),
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// The admin's working hours: what counts as late, as an early leave, and as
/// overtime. Everything that judges a punch reads what this saves.
class WorkScheduleCubit extends Cubit<WorkScheduleState> {
  final SettingsRepo _repo;

  WorkScheduleCubit(this._repo) : super(const WorkScheduleState());

  void load() => emit(WorkScheduleState(schedule: _repo.getWorkSchedule()));

  void setWorkStart(String time) =>
      _edit(state.schedule.copyWith(workStart: time));
  void setWorkEnd(String time) => _edit(state.schedule.copyWith(workEnd: time));
  void setOvertimeStart(String time) =>
      _edit(state.schedule.copyWith(overtimeStart: time));
  void setOvertimeEnd(String time) =>
      _edit(state.schedule.copyWith(overtimeEnd: time));

  /// The days nobody on the default hours works. Every shift created after
  /// this inherits them as its starting point.
  void setRestDays(Set<int> days) =>
      _edit(state.schedule.copyWith(restDays: days));

  void _edit(WorkSchedule schedule) => emit(
    state.copyWith(
      schedule: schedule,
      isDirty: true,
      clearError: true,
      clearMessage: true,
    ),
  );

  Future<void> save() async {
    // Hours that cannot be worked would quietly turn every day into an early
    // leave, so they are refused rather than stored.
    if (!state.schedule.isValid) {
      emit(state.copyWith(error: LangKeys.scheduleInvalid));
      return;
    }

    try {
      await _repo.setWorkSchedule(state.schedule);
      emit(
        state.copyWith(
          isDirty: false,
          message: LangKeys.scheduleSaved,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(state.copyWith(error: LangKeys.errorSaveFailed));
    }
  }
}
