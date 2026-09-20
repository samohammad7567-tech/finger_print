/// The signed-in user as the API returns it under `user`.
class GuardModel {
  final String uid;
  final String name;
  final String email;
  final String role;

  const GuardModel({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'guard',
  });

  factory GuardModel.fromJson(Map<String, dynamic> json) => GuardModel(
    uid: json['uid'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'guard',
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'email': email,
    'role': role,
  };

  bool get isAdmin => role == 'admin';

  /// Falls back to the local part of the email when no display name was set.
  String get displayName =>
      name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : '');
}

/// A successful `/auth/login` or `/auth/register` response.
class AuthSessionModel {
  final String token;
  final DateTime? expiresAt;
  final GuardModel user;

  const AuthSessionModel({
    required this.token,
    required this.user,
    this.expiresAt,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) =>
      AuthSessionModel(
        token: json['token'] as String? ?? '',
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
        user: GuardModel.fromJson(
          (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}
