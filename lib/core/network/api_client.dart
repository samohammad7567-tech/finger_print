import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'error_mapper.dart';

/// The single HTTP entry point for every data source.
///
/// It attaches the bearer token, normalises the response body, and converts any
/// failure into an [ApiException] carrying a localization key. Nothing above the
/// data layer ever sees a [DioException] or a status code.
class ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Called when the API rejects the stored token, so the app can sign out.
  void Function()? onUnauthorized;

  ApiClient(this._tokenStorage, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
              // Statuses are inspected here, not thrown on, so error bodies with
              // a stable key survive long enough to be mapped.
              validateStatus: (status) => status != null && status < 500,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokenStorage.token;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send(
    () => _dio.post<dynamic>(path, data: body, queryParameters: _clean(query)),
  );

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  /// Convenience for endpoints that return a JSON object.
  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final data = await get(path, query: query);
    return asObject(data);
  }

  /// Narrows a decoded body to a JSON object, or an empty map when it is not one.
  static Map<String, dynamic> asObject(dynamic data) =>
      data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

  /// Narrows a decoded body to a list of JSON objects.
  static List<Map<String, dynamic>> asObjectList(dynamic data) => data is List
      ? data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];

  /// Convenience for endpoints that return a JSON array of objects.
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final data = await get(path, query: query);
    return asObjectList(data);
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final status = response.statusCode ?? 0;

      if (status >= 200 && status < 300) {
        // 204 carries no body; callers treat null as "nothing found".
        return status == 204 ? null : response.data;
      }

      final failure = ErrorMapper.fromDio(
        DioException.badResponse(
          statusCode: status,
          requestOptions: response.requestOptions,
          response: response,
        ),
      );
      if (failure.isUnauthorized) onUnauthorized?.call();
      throw failure;
    } on DioException catch (e) {
      final failure = ErrorMapper.fromDio(e);
      if (failure.isUnauthorized) onUnauthorized?.call();
      throw failure;
    }
  }

  /// Drops null query values so an omitted filter is not sent as "null".
  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null) cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }
}
