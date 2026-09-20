import 'package:dio/dio.dart';

import '../localization/lang_keys.dart';
import 'api_exception.dart';

/// Turns anything the transport can fail with into one stable localization key.
///
/// This is the only place HTTP status codes and Dio error types are interpreted.
class ErrorMapper {
  ErrorMapper._();

  /// Keys the API itself returns in `{"error": "..."}`. Anything not listed here
  /// falls back to a status-based key, so a new server key can never surface as
  /// raw text in the UI.
  static const Set<String> _knownServerKeys = {
    LangKeys.errorInvalidCredentials,
    LangKeys.errorEmailInUse,
    LangKeys.errorInvalidEmail,
    LangKeys.errorWeakPassword,
    LangKeys.errorUserNotFound,
    LangKeys.errorWrongPassword,
    LangKeys.errorUnauthorized,
    LangKeys.errorAccountDisabled,
    LangKeys.errorNotFound,
    LangKeys.errorEmployeeNotFound,
    LangKeys.errorDuplicateRecord,
    LangKeys.errorDuplicatePermission,
    LangKeys.errorDuplicateEmployeeNumber,
    LangKeys.errorInvalidRequest,
    LangKeys.errorInvalidResetToken,
    LangKeys.errorServer,
    LangKeys.vacationLimitError,
  };

  static ApiException fromDio(DioException error) {
    return switch (error.type) {
      DioExceptionType.badResponse => _fromResponse(error.response),
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(
        LangKeys.errorTimeout,
      ),
      DioExceptionType.connectionError || DioExceptionType.badCertificate =>
        const ApiException(LangKeys.errorNetwork),
      DioExceptionType.cancel => const ApiException(LangKeys.errorUnknown),
      _ => const ApiException(LangKeys.errorNetwork),
    };
  }

  static ApiException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final data = response?.data;

    String? serverKey;
    String? detail;
    if (data is Map) {
      final raw = data['error'];
      if (raw is String && _knownServerKeys.contains(raw)) serverKey = raw;
      final message = data['message'];
      if (message is String) detail = message;
    }

    return ApiException(
      serverKey ?? _fromStatus(status),
      statusCode: status,
      detail: detail,
    );
  }

  static String _fromStatus(int? status) {
    if (status == null) return LangKeys.errorUnknown;
    if (status == 401) return LangKeys.errorUnauthorized;
    if (status == 403) return LangKeys.errorForbidden;
    if (status == 404) return LangKeys.errorNotFound;
    if (status == 409) return LangKeys.errorConflict;
    if (status >= 500) return LangKeys.errorServer;
    if (status >= 400) return LangKeys.errorInvalidRequest;
    return LangKeys.errorUnknown;
  }

  /// Wraps anything a data source can throw, so callers only ever see [ApiException].
  static ApiException from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) return fromDio(error);
    return ApiException(LangKeys.errorUnknown, detail: error.toString());
  }
}
