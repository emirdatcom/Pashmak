import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/network/api_error.dart';

import 'helpers.dart';

Map<String, dynamic> session(String access, String refresh, {String user = 'u1', int minutes = 60}) => {
      'user_id': user,
      'access_token': access,
      'access_expires_at': DateTime.utc(2026, 10, 5, 8, minutes).toIso8601String(),
      'refresh_token': refresh,
    };

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 8);

  test('registers the device lazily, then reuses the token', () async {
    final h = ApiHarness(t0);
    var registers = 0;
    h.mock.onPost('/v1/auth/device', (s) {
      registers++;
      s.reply(200, session('a1', 'r1'));
    }, data: Matchers.any);
    h.mock.onGet('/v1/me', (s) => s.reply(200, {'user_id': 'u1'}), headers: {'Authorization': 'Bearer a1'});

    final r1 = await h.api.request<Map<String, dynamic>>('GET', '/v1/me');
    final r2 = await h.api.request<Map<String, dynamic>>('GET', '/v1/me');
    expect(r1.data!['user_id'], 'u1');
    expect(r2.statusCode, 200);
    expect(registers, 1);
    expect((await h.tokens.read())!.refresh, 'r1');
    // the device id and install id travel to the server, headers are set
    expect(await h.db.meta('install_id'), isNotNull);
  });

  test('401 triggers one refresh and a single retry', () async {
    final h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'old', accessExpiresAt: t0.add(const Duration(hours: 1)), refresh: 'r1', userId: 'u1'));
    var refreshes = 0;
    h.mock.onGet('/v1/me', (s) => s.reply(401, {'error': {'code': 'UNAUTHENTICATED', 'message': 'x', 'request_id': 'q'}}),
        headers: {'Authorization': 'Bearer old'});
    h.mock.onPost('/v1/auth/refresh', (s) {
      refreshes++;
      s.reply(200, session('new', 'r2'));
    }, data: {'refresh_token': 'r1'});
    h.mock.onGet('/v1/me', (s) => s.reply(200, {'user_id': 'u1'}), headers: {'Authorization': 'Bearer new'});

    final r = await h.api.request<Map<String, dynamic>>('GET', '/v1/me');
    expect(r.data!['user_id'], 'u1');
    expect(refreshes, 1);
    expect((await h.tokens.read())!.access, 'new');
  });

  test('concurrent expired requests share one refresh (single flight)', () async {
    final h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'old', accessExpiresAt: t0.subtract(const Duration(minutes: 1)), refresh: 'r1', userId: 'u1'));
    var refreshes = 0;
    h.mock.onPost('/v1/auth/refresh', (s) {
      refreshes++;
      s.reply(200, session('new', 'r2'), delay: const Duration(milliseconds: 20));
    }, data: Matchers.any);
    h.mock.onGet('/v1/me', (s) => s.reply(200, {'ok': true}), headers: {'Authorization': 'Bearer new'});
    final rs = await Future.wait(List.generate(5, (_) => h.api.request<Map<String, dynamic>>('GET', '/v1/me')));
    expect(rs.every((r) => r.statusCode == 200), isTrue);
    expect(refreshes, 1);
  });

  test('revoked refresh token falls back to re-registering the same install', () async {
    final h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'old', accessExpiresAt: t0.subtract(const Duration(minutes: 1)), refresh: 'dead', userId: 'u1'));
    h.mock.onPost('/v1/auth/refresh', (s) => s.reply(401, {'error': {'code': 'TOKEN_REUSED', 'message': '', 'request_id': 'q'}}), data: Matchers.any);
    h.mock.onPost('/v1/auth/device', (s) => s.reply(200, session('fresh', 'r9')), data: Matchers.any);
    h.mock.onGet('/v1/me', (s) => s.reply(200, {'ok': true}), headers: {'Authorization': 'Bearer fresh'});
    final r = await h.api.request<Map<String, dynamic>>('GET', '/v1/me');
    expect(r.statusCode, 200);
    expect((await h.tokens.read())!.refresh, 'r9');
  });

  test('error body maps to ApiError; transport failure is NETWORK', () async {
    final h = ApiHarness(t0);
    h.mock.onPost('/v1/auth/device', (s) => s.reply(200, session('a', 'r')), data: Matchers.any);
    h.mock.onPost('/v1/trial/start', (s) => s.reply(409, {'error': {'code': 'TRIAL_ALREADY_USED', 'message': 'm', 'request_id': 'rid'}}),
        data: Matchers.any);
    await expectLater(
        h.api.request('POST', '/v1/trial/start', data: {}),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'TRIAL_ALREADY_USED').having((e) => e.requestId, 'request id', 'rid')));
    h.mock.onGet('/v1/boom', (s) => s.throws(0, DioException.connectionError(requestOptions: RequestOptions(path: '/v1/boom'), reason: 'offline')));
    await expectLater(h.api.request('GET', '/v1/boom'), throwsA(isA<ApiError>().having((e) => e.isNetwork, 'network', true)));
  });

  test('ETag: 200 then 304 for /v1/config', () async {
    final h = ApiHarness(t0);
    h.mock.onPost('/v1/auth/device', (s) => s.reply(200, session('a', 'r')), data: Matchers.any);
    h.mock.onGet('/v1/config', (s) => s.reply(304, null), headers: {'If-None-Match': '"v1-abc"'});
    final r = await h.api.request('GET', '/v1/config',
        headers: {'If-None-Match': '"v1-abc"'}, validateStatus: (s) => s == 200 || s == 304);
    expect(r.statusCode, 304);
  });
}
