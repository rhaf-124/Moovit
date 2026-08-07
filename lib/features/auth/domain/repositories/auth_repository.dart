import '../../data/models/auth_response.dart';
import '../../data/models/user_model.dart';

abstract class AuthRepository {
  Future<AuthResponse> login({
    required String identifier,
    required String password,
  });

  /// Returns the email the verification code was sent to.
  Future<String> register({
    required String phone,
    required String email,
    required String fullName,
    required String password,
  });

  Future<void> verifyEmail(String email, String code);

  Future<void> resendVerificationCode(String email);

  Future<void> logout();

  Future<UserModel> getMe();

  Future<AuthResponse> acceptInvite({
    required String inviteToken,
    required String password,
  });

  Future<UserModel> uploadProfilePicture(String filePath);

  Future<Map<String, dynamic>> getStats();

  Future<void> requestPasswordReset(String email);

  Future<String> verifyResetOtp(String email, String code);

  Future<void> resetPassword(String resetToken, String newPassword);

  Future<void> registerFcmToken(String token);

  Future<void> clearFcmToken();
}
