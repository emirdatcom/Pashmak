import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/logger.dart';
import 'package:pashmak_app/core/outbox/outbox_worker.dart';
import 'package:pashmak_app/features/support/data/support_api.dart';
import 'package:pashmak_app/features/support/data/support_repository.dart';
import 'package:pashmak_app/features/support/data/support_socket.dart';
import 'package:pashmak_app/features/support/domain/support_models.dart';
import 'package:pashmak_app/features/support/domain/support_poll.dart';

import 'helpers.dart';

Map<String, dynamic> msg(String id, String sender, String body, {String? client, String? read, String? op, String at = '2026-10-05T08:00:00Z'}) =>
    {'id': id, 'sender': sender, 'body': body, 'created_at': at, 'read_at': read, 'operator_display_name': ?op, 'client_msg_id': ?client};

DioException offline() => DioException.connectionError(requestOptions: RequestOptions(path: '/x'), reason: 'offline');

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 8);
  late ApiHarness h;
  late SupportRepository repo;
  late OutboxWorker outbox;

  setUp(() async {
    h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 5)), refresh: 'r', userId: 'u1'));
    late SupportRepository r;
    outbox = OutboxWorker(h.db, h.clock, {SupportRepository.kind: (p) => r.handlers[SupportRepository.kind]!(p)});
    r = repo = SupportRepository(h.db, SupportApi(h.api), h.clock, const NoopAnalytics(), enqueue: (k, p) async {
      await outbox.enqueue(k, p);
    });
  });

  Future<List<String>> bodies() async => (await h.db.select(h.db.supportMessagesCache).get()).map((m) => '${m.sender}:${m.body}:${m.status}').toList();

  group('sending', () {
    test('online: stored locally first, then marked sent with the server id', () async {
      Map<String, dynamic>? sent;
      h.mock.onPost('/v1/support/messages', (s) {
        s.reply(200, msg('srv-1', 'user', 'سلام', client: 'will-be-replaced'));
      }, data: Matchers.any);
      h.api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, hd) {
        if (o.path == '/v1/support/messages') sent = o.data as Map<String, dynamic>;
        hd.next(o);
      }));
      final r = await repo.send('  سلام  ');
      expect(r.outcome, SendOutcome.sent);
      expect(sent!['body'], 'سلام', reason: 'trimmed');
      expect(sent!['include_device_meta'], false);
      expect(const UuidLike().matches(sent!['client_msg_id'] as String), isTrue);
      final rows = await h.db.select(h.db.supportMessagesCache).get();
      expect((rows.single.id, rows.single.status), ('srv-1', 'sent'));
      expect(await repo.lastUserMessageAt(), isNotNull);
    });

    test('offline: the message waits in the outbox and is delivered exactly once with the same client id', () async {
      final ids = <String>[];
      h.mock.onPost('/v1/support/messages', (s) => s.throws(0, offline()), data: Matchers.any);
      final r = await repo.send('پیام آفلاین');
      expect(r.outcome, SendOutcome.queued);
      expect(await bodies(), ['user:پیام آفلاین:sending']);
      expect(await outbox.pending(), 1);

      h.mock.reset();
      h.mock.onPost('/v1/support/messages', (s) => s.reply(200, msg('srv-9', 'user', 'پیام آفلاین')), data: Matchers.any);
      h.api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, hd) {
        if (o.path == '/v1/support/messages') ids.add((o.data as Map)['client_msg_id'] as String);
        hd.next(o);
      }));
      h.clock.advance(const Duration(minutes: 10));
      await outbox.runDue();
      expect(await outbox.pending(), 0);
      expect(await bodies(), ['user:پیام آفلاین:sent']);
      expect(ids, hasLength(1));
      final queued = (await h.db.select(h.db.supportMessagesCache).get()).single;
      expect(queued.id, 'srv-9');
    });

    test('permanent errors mark the message failed; retry sends it again with the same client id', () async {
      h.mock.onPost('/v1/support/messages',
          (s) => s.reply(503, {'error': {'code': 'SUPPORT_DISABLED', 'message': 'x', 'request_id': 'q'}}), data: Matchers.any);
      final r = await repo.send('x');
      expect((r.outcome, r.failure), (SendOutcome.failed, SupportFailure.disabled));
      expect(await bodies(), ['user:x:failed']);
      expect(await outbox.pending(), 0);

      h.mock.reset();
      h.mock.onPost('/v1/support/messages', (s) => s.reply(200, msg('srv-2', 'user', 'x')), data: Matchers.any);
      final local = (await h.db.select(h.db.supportMessagesCache).get()).single.id;
      expect((await repo.retry(local)).outcome, SendOutcome.sent);
      expect(await bodies(), ['user:x:sent']);
    });

    test('rate limiting is reported kindly, not retried blindly', () async {
      h.mock.onPost('/v1/support/messages',
          (s) => s.reply(429, {'error': {'code': 'RATE_LIMITED', 'message': 'x', 'request_id': 'q'}}), data: Matchers.any);
      final r = await repo.send('x');
      expect(r.failure == SupportFailure.rateLimited || r.outcome == SendOutcome.queued, isTrue);
    });
  });

  group('syncing', () {
    test('merges history in order, matches our own message by client id and never duplicates', () async {
      h.mock.onPost('/v1/support/messages', (s) => s.throws(0, offline()), data: Matchers.any);
      await repo.send('سؤال من');
      final clientId = (await h.db.select(h.db.supportMessagesCache).get()).single.clientMsgId!;
      h.mock.onGet('/v1/support/messages', (s) => s.reply(200, {
            'messages': [
              msg('m1', 'user', 'سؤال من', client: clientId, at: '2026-10-05T08:00:01Z'),
              msg('m2', 'operator', 'جواب ما', op: 'سارا', at: '2026-10-05T08:05:00Z'),
            ],
            'has_more': false,
          }), queryParameters: {'limit': 50});
      h.mock.onGet('/v1/support/messages', (s) => s.reply(200, {'messages': <dynamic>[], 'has_more': false}), queryParameters: {'after': 'm2', 'limit': 50});
      expect(await repo.sync(), 1);
      expect(await repo.sync(), 0, reason: 'a second sync adds nothing');
      final rows = await (h.db.select(h.db.supportMessagesCache)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
      expect(rows.map((r) => '${r.sender}:${r.status}'), ['user:sent', 'operator:sent']);
      expect(rows.last.operatorName, 'سارا');
    });

    test('markAllRead tells the server the newest operator message id and clears the badge', () async {
      h.mock.onGet('/v1/support/messages', (s) => s.reply(200, {'messages': [msg('m7', 'operator', 'سلام', op: 'سارا')], 'has_more': false}), queryParameters: {'limit': 50});
      String? upTo;
      h.mock.onPost('/v1/support/read', (s) {
        s.reply(204, null);
      }, data: Matchers.any);
      h.api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, hd) {
        if (o.path == '/v1/support/read') upTo = (o.data as Map)['up_to_message_id'] as String;
        hd.next(o);
      }));
      await repo.sync();
      expect(await repo.unread(), 0);
      await repo.markAllRead();
      expect(upTo, 'm7');
      expect((await h.db.select(h.db.supportMessagesCache).getSingle()).status, 'read');
    });

    test('background poll reports only a rise in unread replies', () async {
      Map<String, dynamic> info(int n) => {'status': 'waiting_user', 'unread_count': n, 'online': true};
      h.mock.onGet('/v1/support/conversation', (s) => s.reply(200, info(0)));
      expect(await repo.pollForReplies(), isFalse);
      h.mock.reset();
      h.mock.onGet('/v1/support/conversation', (s) => s.reply(200, info(1)));
      expect(await repo.pollForReplies(), isTrue);
      expect(await repo.pollForReplies(), isFalse, reason: 'the same unread reply must not notify twice');
      expect(await repo.unread(), 1);
    });
  });

  test('deleting the conversation clears the server copy, the cache and queued sends', () async {
    h.mock.onPost('/v1/support/messages', (s) => s.throws(0, offline()), data: Matchers.any);
    await repo.send('پیام');
    expect(await outbox.pending(), 1);
    h.mock.onDelete('/v1/support/conversation', (s) => s.reply(204, null));
    await repo.deleteConversation();
    expect(await h.db.select(h.db.supportMessagesCache).get(), isEmpty);
    expect(await outbox.pending(), 0);
  });

  test('message text never reaches the app log (failure paths included)', () async {
    AppLogger.reset();
    h.mock.onPost('/v1/support/messages', (s) => s.throws(0, offline()), data: Matchers.any);
    await repo.send('متن-فوق-محرمانه-۱۲۳');
    h.mock.reset();
    h.mock.onPost('/v1/support/messages', (s) => s.reply(503, {'error': {'code': 'SUPPORT_DISABLED', 'message': 'متن-فوق-محرمانه-۱۲۳', 'request_id': 'q'}}), data: Matchers.any);
    h.clock.advance(const Duration(hours: 1));
    await outbox.runDue();
    expect(jsonEncode(AppLogger.recentErrors), isNot(contains('محرمانه')));
    final row = await h.db.select(h.db.outbox).get();
    expect(row.map((r) => r.lastError ?? ''), everyElement(isNot(contains('محرمانه'))));
  });

  group('SupportPollSchedule (no push service, D-9)', () {
    const s = SupportPollSchedule();
    final last = DateTime.utc(2026, 10, 5, 8);
    test('30 min for the first 24 h, then 6 h until 7 days, then stop', () {
      expect(s.nextDelay(lastUserMessageAt: last, now: last.add(const Duration(minutes: 5))), const Duration(minutes: 30));
      expect(s.nextDelay(lastUserMessageAt: last, now: last.add(const Duration(hours: 23, minutes: 59))), const Duration(minutes: 30));
      expect(s.nextDelay(lastUserMessageAt: last, now: last.add(const Duration(hours: 24))), const Duration(hours: 6));
      expect(s.nextDelay(lastUserMessageAt: last, now: last.add(const Duration(days: 6, hours: 23))), const Duration(hours: 6));
      expect(s.nextDelay(lastUserMessageAt: last, now: last.add(const Duration(days: 7))), isNull);
    });
  });

  group('SupportSocket', () {
    test('auth frame first, ping, events, reconnect with backoff and polling fallback after 3 failures', () async {
      final delays = <Duration>[];
      var polls = 0;
      var attempts = 0;
      final conns = <_FakeConn>[];
      final socket = SupportSocket(
        baseUri: Uri.parse('wss://x/v1/support/ws'),
        tokenProvider: () async => 'tok',
        onPoll: () async => polls++,
        connector: (uri) async {
          attempts++;
          if (attempts <= 3) throw StateError('blocked'); // WS blocked by the network
          final c = _FakeConn();
          conns.add(c);
          return c;
        },
        delay: (d) async {
          delays.add(d);
          await Future<void>.delayed(Duration.zero);
        },
        pingInterval: const Duration(milliseconds: 20),
        pollInterval: const Duration(seconds: 10),
      );
      final states = <SocketState>[];
      socket.stateChanges.listen(states.add);
      final events = <SocketEvent>[];
      socket.events.listen(events.add);
      socket.start();
      await _until(() => conns.isNotEmpty);
      // three failures: 1 s, 2 s, then polling every 10 s
      expect(delays.take(2), const [Duration(seconds: 1), Duration(seconds: 2)]);
      expect(states, contains(SocketState.polling));
      expect(polls, greaterThanOrEqualTo(1));
      final c = conns.single;
      expect(jsonDecode(c.sent.first), {'type': 'auth', 'token': 'tok'}, reason: 'the token goes in the first frame');
      c.push('{"type":"ready"}');
      await _until(() => socket.state == SocketState.live);
      c.push('{"type":"message.new","message":{"id":"1"}}');
      c.push('not json');
      await _until(() => events.isNotEmpty);
      expect(events.single.type, 'message.new');
      await _until(() => c.sent.any((s) => s.contains('"ping"')));
      // a dropped connection reconnects
      await c.drop();
      await _until(() => conns.length >= 2);
      await socket.dispose();
    });

    test('an unauthenticated session (no token) never connects', () async {
      var connected = false;
      final socket = SupportSocket(
        baseUri: Uri.parse('wss://x'),
        tokenProvider: () async => null,
        onPoll: () async {},
        connector: (u) async {
          connected = true;
          return _FakeConn();
        },
        delay: (d) => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      socket.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await socket.dispose();
      expect(connected, isFalse);
    });
  });
}

class UuidLike {
  const UuidLike();
  bool matches(String s) => RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(s);
}

class _FakeConn implements SocketConnection {
  final _in = StreamController<String>();
  final sent = <String>[];
  @override
  Stream<String> get messages => _in.stream;
  @override
  void send(String text) => sent.add(text);
  void push(String s) => _in.add(s);
  Future<void> drop() => _in.close();
  @override
  Future<void> close() async {
    if (!_in.isClosed) await _in.close();
  }
}

Future<void> _until(bool Function() cond, {Duration timeout = const Duration(seconds: 3)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('condition not met in time');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
