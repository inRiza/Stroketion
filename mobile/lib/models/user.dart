class User {
  const User({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
  });

  final String id;
  final String email;
  final String role;
  final String? fullName;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      fullName: json['full_name'] as String?,
    );
  }
}

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final User user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['access_token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
