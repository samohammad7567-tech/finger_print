import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/holiday_model.dart';
import '../../data/repos/holidays_repo.dart';

class HolidaysState {
  final List<HolidayModel> holidays;
  final bool isLoading;
  final bool isSaving;

  /// Localization keys, never sentences — the screen translates them.
  final String? errorKey;
  final String? successKey;

  const HolidaysState({
    this.holidays = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.errorKey,
    this.successKey,
  });

  bool get isEmpty => !isLoading && holidays.isEmpty;

  /// How many days off the calendar accounts for altogether — what the screen
  /// shows so an admin can tell at a glance whether a year looks complete.
  int get totalDays =>
      holidays.fold(0, (sum, holiday) => sum + holiday.dayCount);

  HolidaysState copyWith({
    List<HolidayModel>? holidays,
    bool? isLoading,
    bool? isSaving,
    String? errorKey,
    String? successKey,
  }) => HolidaysState(
    holidays: holidays ?? this.holidays,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    // Feedback is spent once shown, so it is never carried forward by a
    // copy that did not ask for it.
    errorKey: errorKey,
    successKey: successKey,
  );
}

/// The holiday calendar an admin maintains.
///
/// Every report that judges a month reads what this saves, so a date added
/// here stops counting against everybody the next time a report is opened.
class HolidaysCubit extends Cubit<HolidaysState> {
  final HolidaysRepo _repo;

  HolidaysCubit(this._repo) : super(const HolidaysState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      emit(
        state.copyWith(holidays: await _repo.getHolidays(), isLoading: false),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, errorKey: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(isLoading: false, errorKey: LangKeys.errorLoadFailed),
      );
    }
  }

  Future<String?> add(HolidayModel holiday) =>
      _write(() => _repo.createHoliday(holiday), LangKeys.holidayAdded);

  Future<String?> edit(HolidayModel holiday) =>
      _write(() => _repo.updateHoliday(holiday), LangKeys.holidayUpdated);

  Future<void> remove(HolidayModel holiday) async {
    await _write(() async {
      await _repo.deleteHoliday(holiday.id);
      return null;
    }, LangKeys.holidayDeleted);
  }

  /// One write, then a reload — the list is rebuilt from the database rather
  /// than patched in memory, so the ordering by date stays right.
  Future<String?> _write(
    Future<HolidayModel?> Function() action,
    String successKey,
  ) async {
    if (state.isSaving) return null;
    emit(state.copyWith(isSaving: true));

    try {
      final result = await action();
      emit(
        state.copyWith(
          holidays: await _repo.getHolidays(),
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
