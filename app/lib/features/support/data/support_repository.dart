import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/network/api_error.dart';
import '../../../core/outbox/outbox_worker.dart';
import '../../../core/time/clock.dart';
import '../domain/support_models.dart';
import 'support_api.dart';

enum SendOutcome { sent, queued, failed }

class SendResult {
  const SendResult(this.outcome, {this.failure});
  final SendOutcome outcome;
  final SupportFailure? failure;
}

/// Local-first view of the support chat. The server is the source of truth: the cache only makes the screen
/// instant and lets unsent messages survive restarts (they wait in the outbox as `support_send`).
class SupportRepository {
  SupportRepository(this._db, this._api, this._clock, this._analytics, {required this.enqueue, this.deviceHeaders});

  final AppDatabase _db;
  final SupportApi _api;
  final Clock _clock;
  final AnalyticsService _analytics;

  /// Adds a `support_send` row to the outbox (the monetization service owns the worker).
  final Future<void> Function(String kind, Map<String, dynamic> payload) enqueue;

  /// os/model headers, read only when the user ticked the consent box.
  final Future<Map<String, String>> Function()? deviceHeaders;

  static const kind = 'support_send';
  static const _kUnreadSeen = 'support_unread_seen';
  static const _kLastUserMsg = 'support_last_user_msg_at';

  Map<String, OutboxHandler> get handlers => {kind: _sendHandler};

  Stream<List<SupportMessagesCacheData>> watchMessages() =>
      (_db.select(_db.supportMessagesCache)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Future<DateTime?> lastUserMessageAt() async {
    final v = int.tryParse(await _db.meta(_kLastUserMsg) ?? '');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  /// Unread replies the user has not opened yet (settings badge).
  Future<int> unread() async => int.tryParse(await _db.meta('support_unread') ?? '') ?? 0;

  // ---- sending -----------------------------------------------------------------------------------

  /// Stores the message locally first, then tries the server; offline → outbox.
  Future<SendResult> send(String body, {bool includeDeviceMeta = false}) async {
    final text = body.trim();
    final clientId = const Uuid().v4();
    final now = _clock.now().millisecondsSinceEpoch;
    await _db.into(_db.supportMessagesCache).insert(SupportMessagesCacheCompanion.insert(
        id: clientId, clientMsgId: Value(clientId), sender: 'user', body: text, createdAt: now, status: 'sending'));
    await _db.setMeta(_kLastUserMsg, '$now');
    return _deliver(clientId, text, includeDeviceMeta, queueIfOffline: true);
  }

  /// Retry of a failed message (same client id ⇒ the server stores it once).
  Future<SendResult> retry(String localId) async {
    final row = await (_db.select(_db.supportMessagesCache)..where((t) => t.id.equals(localId))).getSingleOrNull();
    if (row == null) return const SendResult(SendOutcome.failed);
    await (_db.update(_db.supportMessagesCache)..where((t) => t.id.equals(localId))).write(const SupportMessagesCacheCompanion(status: Value('sending')));
    return _deliver(row.clientMsgId ?? row.id, row.body, false, queueIfOffline: true);
  }

  Future<SendResult> _deliver(String clientId, String body, bool meta, {required bool queueIfOffline}) async {
    try {
      final remote = await _api.send(clientId, body, includeDeviceMeta: meta, metaHeaders: meta ? await (deviceHeaders?.call() ?? Future.value(const {})) : const {});
      await _markSent(clientId, remote);
      unawaited(_analytics.track(AnalyticsEvent.supportMessageSent, {'has_device_meta': meta}));
      return const SendResult(SendOutcome.sent);
    } on ApiError catch (e) {
      // SUPPORT_DISABLED is a 503 but not a transient fault: queueing would only hide the kill switch.
      if (e.isRetryable && e.code != 'SUPPORT_DISABLED') {
        if (queueIfOffline) await enqueue(kind, {'client_msg_id': clientId, 'body': body, 'include_device_meta': meta});
        return const SendResult(SendOutcome.queued, failure: SupportFailure.offline);
      }
      await _setStatus(clientId, 'failed');
      return SendResult(SendOutcome.failed, failure: supportFailureOf(e));
    }
  }

  Future<OutboxResult> _sendHandler(Map<String, dynamic> p) async {
    final clientId = p['client_msg_id'] as String;
    try {
      final meta = (p['include_device_meta'] as bool?) ?? false;
      final remote = await _api.send(clientId, p['body'] as String,
          includeDeviceMeta: meta, metaHeaders: meta ? await (deviceHeaders?.call() ?? Future.value(const {})) : const {});
      await _markSent(clientId, remote);
      unawaited(_analytics.track(AnalyticsEvent.supportMessageSent, {'has_device_meta': meta}));
      return OutboxResult.done;
    } on ApiError catch (e) {
      if (e.isRetryable && e.code != 'SUPPORT_DISABLED') rethrow; // the worker backs off and retries
      await _setStatus(clientId, 'failed');
      return OutboxResult.drop;
    }
  }

  Future<void> _markSent(String clientId, RemoteMessage m) async {
    await _db.transaction(() async {
      await (_db.delete(_db.supportMessagesCache)..where((t) => t.id.equals(m.id) & t.id.equals(clientId).not())).go();
      await (_db.update(_db.supportMessagesCache)..where((t) => t.id.equals(clientId))).write(SupportMessagesCacheCompanion(
        id: Value(m.id),
        status: const Value('sent'),
        createdAt: Value(m.createdAt.millisecondsSinceEpoch),
      ));
    });
  }

  Future<void> _setStatus(String id, String status) =>
      (_db.update(_db.supportMessagesCache)..where((t) => t.id.equals(id) | t.clientMsgId.equals(id))).write(SupportMessagesCacheCompanion(status: Value(status)));

  // ---- syncing -----------------------------------------------------------------------------------

  /// Pulls everything after the newest server message we know (works as the WebSocket fallback too).
  /// Returns how many new operator messages arrived.
  Future<int> sync({String via = 'ws', bool trackReplies = true}) async {
    final last = await (_db.select(_db.supportMessagesCache)
          ..where((t) => t.status.isIn(['sent', 'read']))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    var cursor = last?.id;
    var newReplies = 0;
    while (true) {
      final page = await _api.messages(after: cursor);
      for (final m in page.messages) {
        final exists = await (_db.select(_db.supportMessagesCache)..where((t) => t.id.equals(m.id))).getSingleOrNull();
        if (exists != null) continue;
        // our own message coming back with its server id: match by client id instead of duplicating it
        if (m.clientMsgId != null) {
          final mine = await (_db.select(_db.supportMessagesCache)..where((t) => t.clientMsgId.equals(m.clientMsgId!))).getSingleOrNull();
          if (mine != null) {
            await _markSent(mine.id, m);
            continue;
          }
        }
        await _db.into(_db.supportMessagesCache).insert(SupportMessagesCacheCompanion.insert(
            id: m.id,
            clientMsgId: Value(m.clientMsgId),
            sender: m.sender,
            body: m.body,
            createdAt: m.createdAt.millisecondsSinceEpoch,
            status: m.readAt == null ? 'sent' : 'read',
            readAt: Value(m.readAt?.millisecondsSinceEpoch),
            operatorName: Value(m.operatorName)));
        if (m.sender != 'user') newReplies++;
      }
      if (!page.hasMore || page.messages.isEmpty) break;
      cursor = page.messages.last.id;
    }
    if (newReplies > 0 && trackReplies) unawaited(_analytics.track(AnalyticsEvent.supportReplyReceived, {'via': via}));
    return newReplies;
  }

  /// The screen is open and showing everything: tell the server (clears the user's unread counter).
  Future<void> markAllRead() async {
    final newest = await (_db.select(_db.supportMessagesCache)
          ..where((t) => t.sender.equals('operator') & t.status.equals('sent'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    await _db.setMeta('support_unread', '0');
    await _db.setMeta(_kUnreadSeen, '0');
    if (newest == null) return;
    try {
      await _api.markRead(newest.id);
      await (_db.update(_db.supportMessagesCache)..where((t) => t.sender.equals('operator') & t.status.equals('sent')))
          .write(SupportMessagesCacheCompanion(status: const Value('read'), readAt: Value(_clock.now().millisecondsSinceEpoch)));
    } on ApiError {
      // best effort; the next open retries
    }
  }

  /// Background poll (`support_poll`): returns true when there are more unread replies than last time.
  Future<bool> pollForReplies() async {
    final info = await _api.conversation();
    final seen = int.tryParse(await _db.meta(_kUnreadSeen) ?? '') ?? 0;
    await _db.setMeta('support_unread', '${info.unreadCount}');
    await _db.setMeta(_kUnreadSeen, '${info.unreadCount}');
    if (info.unreadCount > seen) {
      unawaited(_analytics.track(AnalyticsEvent.supportReplyReceived, {'via': 'poll'}));
      return true;
    }
    return false;
  }

  // ---- deletion ----------------------------------------------------------------------------------

  Future<void> deleteConversation() async {
    await _api.deleteConversation();
    await clearLocal();
    unawaited(_analytics.track(AnalyticsEvent.supportConversationDeleted));
  }

  Future<void> clearLocal() async {
    await _db.delete(_db.supportMessagesCache).go();
    await (_db.delete(_db.outbox)..where((t) => t.kind.equals(kind))).go();
    await _db.setMeta('support_unread', '0');
    await _db.setMeta(_kUnreadSeen, '0');
  }
}
