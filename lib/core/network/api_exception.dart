/// A failed API call, already reduced to a localization key.
///
/// Data sources throw this; cubits put [errorKey] straight into state and the
/// UI translates it. No layer above the network re-interprets HTTP status codes.
class ApiException implements Exception {
  final String errorKey;
  final int? statusCode;
  final String? detail;

  const ApiException(this.errorKey, {this.statusCode, this.detail});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() =>
      'ApiException($errorKey, status: $statusCode, detail: $detail)';
}
