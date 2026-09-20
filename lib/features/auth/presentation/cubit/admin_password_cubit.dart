import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/repos/auth_repo.dart';

class AdminPasswordState {
  /// The password is being checked. Hashing is deliberately slow, so this is
  /// long enough to be worth showing.
  final bool isChecking;

  /// A localization key, never a sentence — the dialog translates it.
  final String? errorKey;

  const AdminPasswordState({this.isChecking = false, this.errorKey});

  AdminPasswordState copyWith({bool? isChecking, String? errorKey}) =>
      AdminPasswordState(
        isChecking: isChecking ?? this.isChecking,
        // Spent once shown: a second attempt starts without the first one's
        // complaint still on screen.
        errorKey: errorKey,
      );
}

/// Confirms that whoever is at the keyboard is still the account that signed
/// in, by asking for its password.
///
/// It never opens or changes a session — it answers one question and nothing
/// else. The account is read from the stored session rather than passed in, so
/// there is no way for a caller to ask about somebody else's password.
class AdminPasswordCubit extends Cubit<AdminPasswordState> {
  final AuthRepo _repo;

  AdminPasswordCubit(this._repo) : super(const AdminPasswordState());

  /// True only when the password matched the signed-in account.
  ///
  /// Every other outcome — no session, a disabled account, a database
  /// failure — is false. It guards something that cannot be undone, so
  /// anything short of a confirmed match has to read as a refusal.
  Future<bool> verify(String password) async {
    if (state.isChecking) return false;

    final userId = _repo.cachedUser?.uid;
    if (userId == null || userId.isEmpty) {
      emit(state.copyWith(errorKey: LangKeys.errorUserNotFound));
      return false;
    }

    emit(state.copyWith(isChecking: true));
    try {
      await _repo.verifyPassword(userId: userId, password: password);
      emit(state.copyWith(isChecking: false));
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(isChecking: false, errorKey: e.errorKey));
      return false;
    } catch (_) {
      emit(state.copyWith(isChecking: false, errorKey: LangKeys.errorUnknown));
      return false;
    }
  }
}
