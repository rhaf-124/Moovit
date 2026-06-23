class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String role;
  final String userId;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.role,
    required this.userId,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        tokenType: json['token_type'] as String,
        role: json['role'] as String,
        userId: json['user_id'] as String,
      );
}
