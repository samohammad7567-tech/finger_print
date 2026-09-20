import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/work_schedule.dart';
import '../../data/models/shift_model.dart';
import '../../data/repos/shifts_repo.dart';

class ShiftsState {
  final List<ShiftModel> shifts;

  /// The company default hours. Shown beside the list as the shift everybody
  /// without one is on, and used by the form to preview the overtime window a
  /// new shift will inherit.
  final WorkSchedule companyDefault;

  final bool isLoading;
  final bool isSaving;

  /// Localization keys, never sentences — the screen translates them.
  final String? errorKey;
  final String? successKey;

  const ShiftsState({
    this.shifts = const [],
    this.companyDefault = const WorkSchedule(),
    this.isLoading = true,
    this.isSaving = false,
    this.errorKey,
    this.successKey,
  });

  bool get isEmpty => !isLoading && shifts.isEmpty;

  ShiftsState copyWith({
    List<ShiftModel>? shifts,
    WorkSchedule? companyDefault,
    bool? isLoading,
    bool? isSaving,
    String? errorKey,
    String? successKey,
  }) => ShiftsState(
    shifts: shifts ?? this.shifts,
    companyDefault: companyDefault ?? this.companyDefault,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    // Feedback is spent once shown, so it is never carried forward by a
    // copy that did not ask for it.
    errorKey: errorKey,
    successKey: successKey,
  );
}

/// The shift list an admin maintains, and the source of the choices the
/// employee form offers.
class ShiftsCubit extends Cubit<ShiftsState> {
  final ShiftsRepo _repo;

  ShiftsCubit(this._repo) : super(const ShiftsState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      // One read for both: the schedules carry the company default, which the
      // list shows as the hours anybody without a shift is on.
      final schedules = await _repo.getSchedules();
      emit(
        state.copyWith(
          shifts: await _repo.getShifts(),
          companyDefault: schedules.companyDefault,
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, errorKey: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(isLoading: false, errorKey: LangKeys.errorLoadFailed),
      );
    }
  }

  /// Returns the id that was stored, so a caller mid-way through another form —
  /// the employee sheet — can select the shift it just created. Null when the
  /// shift was refused.
  Future<String?> add(ShiftModel shift) =>
      _write(() => _repo.createShift(shift), LangKeys.shiftAdded);

  Future<String?> edit(ShiftModel shift) =>
      _write(() => _repo.updateShift(shift), LangKeys.shiftUpdated);

  /// The employees on it go back to the company default rather than being
  /// blocked — [ShiftModel.inUse] is what the confirm dialog warns with.
  Future<void> remove(ShiftModel shift) async {
    await _write(() async {
      await _repo.deleteShift(shift.id);
      return null;
    }, LangKeys.shiftDeleted);
  }

  /// One write, then a reload. The list is rebuilt from the database rather
  /// than patched in memory, because a delete moves employees off a shift and
  /// the counts shift with it.
  Future<String?> _write(
    Future<ShiftModel?> Function() action,
    String successKey,
  ) async {
    if (state.isSaving) return null;
    emit(state.copyWith(isSaving: true));

    try {
      final result = await action();
      emit(
        state.copyWith(
          shifts: await _repo.getShifts(),
          isLoading: false,
          isSaving: false,
          successKey: successKey,
        ),
      );
      return result?.id;
    } on ApiException catch (e) {
      emit(state.copyWith(isSaving: false, errorKey: e.errorKey));
      return null;
    } catch (_) {
      emit(state.copyWith(isSaving: false, errorKey: LangKeys.errorSaveFailed));
      return null;
    }
  }
}
