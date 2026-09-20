import '../../data/models/guard_model.dart';

class AuthState {
  final GuardModel? user;
  final String role;
  final bool isLoading;
  final String? error;
  final bool passwordResetSent;

  const AuthState({
    this.user,
    this.role = 'guard',
    this.isLoading = false,
    this.error,
    this.passwordResetSent = false,
  });

  bool get isLoggedIn => user != null;
  bool get isAdmin => role == 'admin';

  String get displayName => user?.displayName ?? '';

  AuthState copyWith({
    GuardModel? user,
    String? role,
    bool? isLoading,
    String? error,
    bool? passwordResetSent,
    bool clearUser = false,
    bool clearError = false,
  }) => AuthState(
    user: clearUser ? null : (user ?? this.user),
    role: clearUser ? 'guard' : (role ?? this.role),
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    passwordResetSent: passwordResetSent ?? this.passwordResetSent,
  );
}
