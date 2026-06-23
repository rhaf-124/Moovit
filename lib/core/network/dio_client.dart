import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class DioClient {
  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(_AuthInterceptor(_tokenStorage, dio, _onDeactivated));
  }

  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;
  final TokenStorage _tokenStorage = TokenStorage();

  // Fires whenever the server tells us the account is deactivated.
  // main.dart listens to this and triggers AuthCubit.forceDeactivated().
  static final StreamController<void> _deactivatedCtrl =
      StreamController.broadcast();
  static Stream<void> get onAccountDeactivated => _deactivatedCtrl.stream;

  static void _onDeactivated() => _deactivatedCtrl.add(null);
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._storage, this._dio, this._onDeactivated);

  final TokenStorage _storage;
  final Dio _dio;
  final void Function() _onDeactivated;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!options.path.contains('/auth/refresh')) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  bool _isInactiveDetail(DioException e) {
    final detail = (e.response?.data as Map?)?['detail'];
    if (detail is String) {
      final lower = detail.toLowerCase();
      return lower.contains('inactive') || lower.contains('deactivated');
    }
    return false;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isRetry = err.requestOptions.extra['_retry'] == true;
    final isAuthPath = err.requestOptions.path.contains('/auth/');

    if (err.response?.statusCode == 401 && !isRetry && !isAuthPath) {
      // Account deactivated — skip refresh, signal the app immediately.
      if (_isInactiveDetail(err)) {
        await _storage.clearTokens();
        _onDeactivated();
        return handler.next(err);
      }

      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
        try {
          // Use a fresh Dio to avoid triggering this interceptor again
          final tokenDio = Dio(
            BaseOptions(baseUrl: ApiConstants.baseUrl),
          );
          final res = await tokenDio.post<Map<String, dynamic>>(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
          );
          final data = res.data!;
          final newAccessToken = data['access_token'] as String;

          // If the backend rotates the refresh token, save the new one too.
          // This keeps users logged in for as long as possible.
          final newRefreshToken = data['refresh_token'] as String?;
          if (newRefreshToken != null) {
            await _storage.saveTokens(
              access: newAccessToken,
              refresh: newRefreshToken,
            );
          } else {
            await _storage.saveAccessToken(newAccessToken);
          }

          // Retry original request with new access token
          final opts = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newAccessToken'
            ..extra['_retry'] = true;
          final retryRes = await _dio.fetch<dynamic>(opts);
          return handler.resolve(retryRes);
        } catch (e) {
          await _storage.clearTokens();
          // Refresh itself returned 401 "inactive" — fire deactivated signal.
          if (e is DioException && e.response?.statusCode == 401 &&
              _isInactiveDetail(e)) {
            _onDeactivated();
          }
        }
      }
    }
    handler.next(err);
  }
}
