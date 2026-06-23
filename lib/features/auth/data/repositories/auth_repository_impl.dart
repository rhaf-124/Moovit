import '../../../../core/storage/token_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;

  @override
  Future<AuthResponse> login({
    required String identifier,
    required String password,
  }) async {
    final result = await _remote.login(
      identifier: identifier,
      password: password,
    );
    await _storage.saveTokens(
      access: result.accessToken,
      refresh: result.refreshToken,
    );
    return result;
  }

  @override
  Future<AuthResponse> register({
    required String phone,
    required String email,
    required String fullName,
    required String password,
  }) async {
    final result = await _remote.register(
      phone: phone,
      email: email,
      fullName: fullName,
      password: password,
    );
    await _storage.saveTokens(
      access: result.accessToken,
      refresh: result.refreshToken,
    );
    return result;
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken != null) {
      await _remote.logout(refreshToken);
    }
    await _storage.clearTokens();
  }

  @override
  Future<UserModel> getMe() => _remote.getMe();

  @override
  Future<AuthResponse> acceptInvite({
    required String inviteToken,
    required String password,
  }) async {
    final result = await _remote.acceptInvite(
      inviteToken: inviteToken,
      password: password,
    );
    await _storage.saveTokens(
      access: result.accessToken,
      refresh: result.refreshToken,
    );
    return result;
  }

  @override
  Future<UserModel> uploadProfilePicture(String filePath) =>
      _remote.uploadProfilePicture(filePath);

  @override
  Future<Map<String, dynamic>> getStats() => _remote.getStats();

  @override
  Future<void> requestPasswordReset(String email) =>
      _remote.requestPasswordReset(email);

  @override
  Future<String> verifyResetOtp(String email, String code) =>
      _remote.verifyResetOtp(email, code);

  @override
  Future<void> resetPassword(String resetToken, String newPassword) =>
      _remote.resetPassword(resetToken, newPassword);

  @override
  Future<void> registerFcmToken(String token) =>
      _remote.registerFcmToken(token);

  @override
  Future<void> clearFcmToken() => _remote.clearFcmToken();
}
