import '../data_source/auth_local_data_source.dart';
import '../models/guard_model.dart';

class AuthRepo {
  final AuthLocalDataSource _dataSource;

  AuthRepo(this._dataSource);

  GuardModel? get cachedUser => _dataSource.cachedUser;

  Future<GuardModel> signIn(String email, String password) =>
      _dataSource.signIn(email, password);

  Future<GuardModel> register(
    String email,
    String password, {
    String? displayName,
  }) => _dataSource.register(email, password, displayName: displayName);

  Future<GuardModel?> refreshCurrentUser() => _dataSource.refreshCurrentUser();

  Future<void> verifyPassword({
    required String userId,
    required String password,
  }) => _dataSource.verifyPassword(userId: userId, password: password);

  Future<void> sendPasswordResetEmail(String email) =>
      _dataSource.sendPasswordResetEmail(email);

  Future<void> signOut() => _dataSource.signOut();
}
