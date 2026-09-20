import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repos/settings_repo.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepo _repo;

  SettingsCubit(this._repo)
    : super(
        SettingsState(
          isDark: _repo.getIsDark(),
          isArabic: _repo.getIsArabic(),
          lateAlerts: _repo.getLateAlerts(),
          missingCheckoutAlerts: _repo.getMissingCheckoutAlerts(),
        ),
      );

  Future<void> toggleDark() async {
    final value = !state.isDark;
    await _repo.setIsDark(value);
    emit(state.copyWith(isDark: value));
  }

  Future<void> toggleArabic() async {
    final value = !state.isArabic;
    await _repo.setIsArabic(value);
    emit(state.copyWith(isArabic: value));
  }

  Future<void> toggleLateAlerts() async {
    final value = !state.lateAlerts;
    await _repo.setLateAlerts(value);
    emit(state.copyWith(lateAlerts: value));
  }

  Future<void> toggleMissingCheckoutAlerts() async {
    final value = !state.missingCheckoutAlerts;
    await _repo.setMissingCheckoutAlerts(value);
    emit(state.copyWith(missingCheckoutAlerts: value));
  }
}
