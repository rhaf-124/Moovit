import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/notifications/fcm_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository, this._storage) : super(const AuthInitial());

  StreamSubscription<String>? _fcmRefreshSub;

  final AuthRepository _repository;
  final TokenStorage _storage;

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    emit(const AuthLoading());
    try {
      await _repository.login(identifier: identifier, password: password);
      final user = await _repository.getMe();
      emit(AuthAuthenticated(user));
      await _registerFcmToken();
    } on DioException catch (e) {
      emit(AuthError(_parseDioError(e)));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> register({
    required String phone,
    required String email,
    required String fullName,
    required String password,
  }) async {
    emit(const AuthLoading());
    try {
      await _repository.register(
        phone: phone,
        email: email,
        fullName: fullName,
        password: password,
      );
      final user = await _repository.getMe();
      emit(AuthAuthenticated(user));
      await _registerFcmToken();
    } on DioException catch (e) {
      emit(AuthError(_parseDioError(e)));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> logout() async {
    emit(const AuthLoggingOut());
    _fcmRefreshSub?.cancel();
    _fcmRefreshSub = null;
    try {
      // Clear the FCM token on the server before logging out so no push
      // notifications are sent to this device after logout.
      await _repository.clearFcmToken();
    } catch (_) {}
    try {
      await _repository.logout();
    } catch (_) {
      await _storage.clearTokens();
    }
    emit(const AuthUnauthenticated());
  }

  Future<void> forceDeactivated() async {
    await _storage.clearTokens();
    emit(const AuthDeactivated());
  }

  Future<void> checkAuthStatus() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    emit(const AuthLoading());
    try {
      final user = await _repository.getMe();
      emit(AuthAuthenticated(user));
    } catch (_) {
      await _storage.clearTokens();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> uploadProfilePicture(String filePath) async {
    final user = await _repository.uploadProfilePicture(filePath);
    emit(AuthAuthenticated(user));
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _repository.getMe();
      emit(AuthAuthenticated(user));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _storage.clearTokens();
        emit(const AuthUnauthenticated());
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> acceptInvite({
    required String inviteToken,
    required String password,
  }) async {
    emit(const AuthLoading());
    try {
      await _repository.acceptInvite(
        inviteToken: inviteToken,
        password: password,
      );
      final user = await _repository.getMe();
      emit(AuthAuthenticated(user));
      await _registerFcmToken();
    } on DioException catch (e) {
      emit(AuthError(_parseDioError(e)));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Gets the current FCM token and registers it with the backend.
  /// Also subscribes to token refreshes so the backend stays in sync.
  Future<void> _registerFcmToken() async {
    try {
      final token = await FcmService.instance.getToken();
      if (token != null) {
        await _repository.registerFcmToken(token);
      }
      // Subscribe to future token rotations
      _fcmRefreshSub?.cancel();
      _fcmRefreshSub = FcmService.instance.onTokenRefresh.listen((newToken) {
        _repository.registerFcmToken(newToken).ignore();
      });
    } catch (_) {
      // FCM registration failure must never block login
    }
  }

  String _parseDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) return first['msg']?.toString() ?? 'Validation error';
      }
    }
    return e.message ?? 'Something went wrong';
  }
}
