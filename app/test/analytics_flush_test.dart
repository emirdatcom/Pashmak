import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pashmak_app/core/analytics/analytics_event.dart';
import 'package:pashmak_app/core/analytics/analytics_flusher.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/auth/token_store.dart';

import 'helpers.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 8);
  late ApiHarness h;
  late QueueAnalytics analytics;
  late AnalyticsFlusher flusher;

  setUp(() async {
    h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 1)), refresh: 'r', userId: 'u1'));
    analytics = QueueAnalytics(h.db, h.clock, sessionId: () => 's1', commonProps: () => {'app_version': '1.0.0', 'market': 'bazaar', 'is_premium': false});
    flusher = AnalyticsFlusher(h.db, h.api, h.clock);
    await analytics.track(AnalyticsEvent.appOpened, {'source': 'launcher'});
    await analytics.track(AnalyticsEvent.habitCompleted, {'mood_level': 2, 'source': 'app'}); // forbidden prop is dropped
  });

  test('a successful flush sends the documented body and empties the queue', () async {
    Map<String, dynamic>? sent;
    h.mock.onPost('/v1/events', (s) {
      s.reply(200, {'accepted': 2, 'rejected': 0, 'rejected_reasons': <String, dynamic>{}});
    }, data: Matchers.any);
    h.api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, handler) {
      if (o.path == '/v1/events') sent = o.data as Map<String, dynamic>;
      handler.next(o);
    }));
    expect(await flusher.flush(), 2);
    expect(await flusher.pending(), 0);
    final events = (sent!['events'] as List).cast<Map<String, dynamic>>();
    expect(events.map((e) => e['name']), ['app_opened', 'habit_completed']);
    expect(events.first.keys.toSet(), {'event_id', 'name', 'ts', 'session_id', 'props'});
    expect(events.first['props'], containsPair('app_version', '1.0.0'));
    expect(events.last['props'].toString(), isNot(contains('mood_level')));
    expect(sent!['sent_at'], isA<String>());
  });

  test('network errors keep the queue; a later flush delivers it', () async {
    h.mock.onPost('/v1/events', (s) => s.throws(0, DioException.connectionError(requestOptions: RequestOptions(path: '/v1/events'), reason: 'offline')), data: Matchers.any);
    expect(await flusher.flush(), 0);
    expect(await flusher.pending(), 2);
    h.mock.reset();
    h.mock.onPost('/v1/events', (s) => s.reply(200, {'accepted': 2, 'rejected': 0, 'rejected_reasons': <String, dynamic>{}}), data: Matchers.any);
    expect(await flusher.flush(), 2);
    expect(await flusher.pending(), 0);
  });

  test('a batch the server refuses as invalid is dropped, not retried forever', () async {
    h.mock.onPost('/v1/events', (s) => s.reply(400, {'error': {'code': 'INVALID_INPUT', 'message': 'x', 'request_id': 'q'}}), data: Matchers.any);
    await flusher.flush();
    expect(await flusher.pending(), 0);
  });

  test('analytics opt-out clears the queue and sends nothing', () async {
    await h.db.setSetting('analytics_opt_out', 'true');
    expect(await flusher.flush(), 0);
    expect(await flusher.pending(), 0);
  });
}
