import 'package:dio/dio.dart';

import '../models/auth_response.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  /// Registers a client account. The backend responds with a message and the
  /// email a 6-digit verification code was sent to (no tokens yet).
  Future<String> register({
    required String phone,
    required String email,
    required String fullName,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'phone': phone,
        'email': email,
        'full_name': fullName,
        'password': password,
      },
    );
    return response.data!['email'] as String;
  }

  Future<void> verifyEmail(String email, String code) async {
    await _dio.post<void>(
      '/auth/verify-email',
      data: {'email': email, 'code': code},
    );
  }

  Future<void> resendVerificationCode(String email) async {
    await _dio.post<void>(
      '/auth/resend-verification',
      data: {'email': email},
    );
  }

  Future<AuthResponse> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'identifier': identifier, 'password': password},
    );
    return AuthResponse.fromJson(response.data!);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<void>(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
    );
  }

  Future<UserModel> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    return UserModel.fromJson(response.data!);
  }

  Future<AuthResponse> acceptInvite({
    required String inviteToken,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/accept-invite',
      data: {
        'invite_token': inviteToken,
        'password': password,
      },
    );
    return AuthResponse.fromJson(response.data!);
  }

  Future<UserModel> uploadProfilePicture(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/me/profile-picture',
      data: formData,
    );
    return UserModel.fromJson(response.data!);
  }

  Future<Map<String, dynamic>> getStats() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/auth/me/stats');
    return response.data!;
  }

  Future<void> requestPasswordReset(String email) async {
    await _dio.post<void>(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<String> verifyResetOtp(String email, String code) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/verify-reset-otp',
      data: {'email': email, 'code': code},
    );
    return response.data!['reset_token'] as String;
  }

  Future<void> resetPassword(String resetToken, String newPassword) async {
    await _dio.post<void>(
      '/auth/reset-password',
      data: {'reset_token': resetToken, 'new_password': newPassword},
    );
  }

  Future<void> registerFcmToken(String token) async {
    await _dio.post<void>(
      '/auth/fcm-token',
      data: {'token': token},
    );
  }

  Future<void> clearFcmToken() async {
    await _dio.delete<void>('/auth/fcm-token');
  }
}
