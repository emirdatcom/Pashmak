/// Error returned by the backend (docs/10 §6.3) or a transport failure (`code == 'NETWORK'`).
class ApiError implements Exception {
  ApiError({required this.code, this.message = '', this.status, this.requestId});

  final String code;
  final String message;
  final int? status;
  final String? requestId;

  bool get isNetwork => code == 'NETWORK';
  bool get isRetryable => isNetwork || (status != null && status! >= 500) || code == 'RATE_LIMITED';

  factory ApiError.fromBody(int? status, Object? body) {
    if (body is Map && body['error'] is Map) {
      final e = body['error'] as Map;
      return ApiError(
        code: '${e['code'] ?? 'UNKNOWN'}',
        message: '${e['message'] ?? ''}',
        status: status,
        requestId: e['request_id'] as String?,
      );
    }
    return ApiError(code: 'UNKNOWN', status: status);
  }

  @override
  String toString() => 'ApiError($code, status=$status, request=$requestId)';
}
