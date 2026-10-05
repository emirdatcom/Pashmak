import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/device_identity.dart';
import '../auth/token_store.dart';
import '../time/clock.dart';
import 'api_error.dart';

/// Static client facts sent as headers on every request (docs/10 §6).
class ClientInfo {
  const ClientInfo({required this.appVersion, required this.market});
  final String appVersion;
  final String market; // bazaar | myket
}

const _noAuth = 'noAuth';

/// Dio wrapper: base headers, lazy device registration, token refresh with a single-flight lock,
/// one retry after 401, and error mapping to [ApiError].
class ApiClient {
  ApiClient({
    required String baseUrl,
    required ClientInfo info,
    required DeviceIdentity identity,
    required TokenStore tokens,
    required Clock clock,
    Duration timeout = const Duration(seconds: 10),
  })  : _identity = identity,
        _tokens = tokens,
        _clock = clock,
        _info = info {
    BaseOptions opts() => BaseOptions(baseUrl: baseUrl, connectTimeout: timeout, receiveTimeout: timeout, sendTimeout: timeout,
        headers: {'Accept-Language': 'fa', 'X-App-Version': info.appVersion, 'X-Market': info.market});
    dio = Dio(opts());
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  late final Dio dio;
  final DeviceIdentity _identity;
  final TokenStore _tokens;
  final Clock _clock;
  final ClientInfo _info;
  Future<Tokens>? _inflight;

  Future<void> _onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    o.headers['X-Install-Id'] = await _identity.installId();
    if (o.extra[_noAuth] == true) return h.next(o);
    try {
      final t = await _validTokens();
      o.headers['Authorization'] = 'Bearer ${t.access}';
      h.next(o);
    } on ApiError catch (e) {
      h.reject(DioException(requestOptions: o, error: e));
    }
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final o = e.requestOptions;
    if (e.response?.statusCode == 401 && o.extra[_noAuth] != true && o.extra['retried'] != true) {
      try {
        await _renew(force: true);
        o.extra['retried'] = true;
        final t = (await _tokens.read())!;
        o.headers['Authorization'] = 'Bearer ${t.access}';
        return h.resolve(await dio.fetch<dynamic>(o));
      } on ApiError catch (err) {
        return h.reject(DioException(requestOptions: o, error: err));
      } on DioException catch (err) {
        return h.reject(err);
      }
    }
    h.next(e);
  }

  Future<Tokens> _validTokens() async {
    final t = await _tokens.read();
    if (t != null && t.accessExpiresAt.isAfter(_clock.now().add(const Duration(seconds: 30)))) return t;
    return _renew(force: false);
  }

  /// Refreshes (or registers) once even when many requests need it at the same time.
  Future<Tokens> _renew({required bool force}) {
    return _inflight ??= _doRenew().whenComplete(() => _inflight = null);
  }

  Future<Tokens> _doRenew() async {
    final current = await _tokens.read();
    if (current != null) {
      try {
        return await _post('/v1/auth/refresh', {'refresh_token': current.refresh});
      } on ApiError catch (e) {
        if (e.code != 'TOKEN_INVALID' && e.code != 'TOKEN_REUSED') rethrow;
        await _tokens.clear(); // fall through to re-registration (same install_id => same user)
      }
    }
    return _post('/v1/auth/device', {
      'install_id': await _identity.installId(),
      'device_hash_raw': await _identity.deviceHashRaw(),
      'market': _info.market,
      'app_version': _info.appVersion,
      'os_version': 'android',
      'model': 'unknown',
    });
  }

  Future<Tokens> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await dio.post<Map<String, dynamic>>(path,
          data: body, options: Options(extra: {_noAuth: true}, headers: {'X-Install-Id': await _identity.installId()}));
      final m = r.data!;
      final t = Tokens(
        access: m['access_token'] as String,
        accessExpiresAt: DateTime.parse(m['access_expires_at'] as String),
        refresh: m['refresh_token'] as String,
        userId: m['user_id'] as String,
      );
      await _tokens.write(t);
      return t;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static ApiError _map(DioException e) {
    if (e.error is ApiError) return e.error as ApiError;
    final r = e.response;
    if (r != null) return ApiError.fromBody(r.statusCode, r.data);
    return ApiError(code: 'NETWORK', message: '${e.message ?? e.error}');
  }

  /// Authenticated JSON request. Throws [ApiError].
  Future<Response<T>> request<T>(String method, String path,
      {Object? data, Map<String, dynamic>? query, Map<String, dynamic>? headers, bool auth = true, ResponseType? responseType,
      bool Function(int?)? validateStatus}) async {
    try {
      return await dio.request<T>(path,
          data: data,
          queryParameters: query,
          options: Options(
              method: method,
              headers: headers,
              responseType: responseType,
              extra: {if (!auth) _noAuth: true},
              validateStatus: validateStatus));
    } on DioException catch (e) {
      throw _map(e);
    }
  }
}
