import 'dart:io';

import 'package:dio/dio.dart';

/// Converts any raw exception into a short, friendly message that a normal
/// user can understand.  Technical details (stack traces, type names, etc.)
/// are intentionally hidden.
String friendlyError(Object e) {
  // ── Dio / network errors ────────────────────────────────────────────────────
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server is taking too long to respond. '
            'Please check your internet connection and try again.';

      case DioExceptionType.connectionError:
        return 'Could not connect to the server. '
            'Make sure you have internet access and try again.';

      case DioExceptionType.cancel:
        return 'The request was cancelled. Please try again.';

      case DioExceptionType.badCertificate:
        return 'There is a security issue with the server connection. '
            'Please contact support if this keeps happening.';

      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          return 'You are not authorised to do that. '
              'Please log in again.';
        }
        if (status == 404) {
          return 'The requested information was not found. '
              'Please try again later.';
        }
        if (status != null && status >= 500) {
          return 'The server encountered a problem. '
              'Please try again in a few minutes.';
        }
        return 'Something went wrong with the server response. '
            'Please try again.';

      case DioExceptionType.unknown:
        break;
    }
  }

  // ── Dart socket / OS errors ─────────────────────────────────────────────────
  if (e is SocketException) {
    return 'No internet connection. '
        'Please check your Wi-Fi or mobile data and try again.';
  }

  // ── Dart type / cast errors (e.g. "Null is not a subtype of String") ────────
  final raw = e.toString();
  if (raw.contains('type') && raw.contains('subtype') ||
      raw.toLowerCase().contains('null') && raw.contains('cast') ||
      raw.toLowerCase().contains('type cast')) {
    return 'Some data from the server was missing or in an unexpected format. '
        'Please try again or contact support.';
  }

  // ── FormatException (bad JSON, etc.) ────────────────────────────────────────
  if (e is FormatException) {
    return 'The server returned an unexpected response. '
        'Please try again later.';
  }

  // ── Fallback ─────────────────────────────────────────────────────────────────
  return 'Something went wrong. Please try again.';
}
