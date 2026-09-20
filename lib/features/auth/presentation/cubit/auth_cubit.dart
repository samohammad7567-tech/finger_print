import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/repos/auth_repo.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo _repo;

  AuthCubit(this._repo) : super(const AuthState());

  /// Restores the session from storage before the first frame, then confirms it
  /// against the API. The cached user is emitted first so a returning user is
  /// not bounced to the login screen while the round trip is in flight.
  Future<void> loadInitialState() async {
    final cached = _repo.cachedUser;
    if (cached == null) return;

    emit(state.copyWith(user: cached, role: cached.role));

    try {
      final refreshed = await _repo.refreshCurrentUser();
      if (refreshed == null) {
        emit(const AuthState());
      } else {
        emit(state.copyWith(user: refreshed, role: refreshed.role));
      }
    } on ApiException {
      // Offline or server down — keep the cached session; requests that need
      // the network will surface their own error.
    }
  }

  Future<void> signIn(String email, String password) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repo.signIn(email, password);
      emit(state.copyWith(user: user, role: user.role, isLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorUnknown));
    }
  }

  Future<void> register(String email, String password) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repo.register(email, password);
      emit(state.copyWith(user: user, role: user.role, isLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorUnknown));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _repo.sendPasswordResetEmail(email);
      emit(state.copyWith(passwordResetSent: true));
      emit(state.copyWith(passwordResetSent: false));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(error: LangKeys.errorUnknown));
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    emit(const AuthState());
  }

  /// Called by the API client when the server rejects the stored token.
  void onSessionExpired() {
    if (!state.isLoggedIn) return;
    _repo.signOut();
    emit(const AuthState(error: LangKeys.errorUnauthorized));
  }
}
