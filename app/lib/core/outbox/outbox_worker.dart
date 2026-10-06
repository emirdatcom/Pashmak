import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../network/api_error.dart';
import '../time/clock.dart';

/// What a handler decided about one outbox row.
enum OutboxResult { done, retry, drop }

typedef OutboxHandler = Future<OutboxResult> Function(Map<String, dynamic> payload);

/// Exponential backoff: 30s, 1m, 2m … capped at 6 hours (docs/20 §5).
Duration outboxBackoff(int attempts) {
  final secs = 30 * pow(2, min(attempts, 20)).toInt();
  return Duration(seconds: min(secs, 6 * 3600));
}

/// Durable queue for server operations (trial_start, purchase_verify, purchase_restore, events_flush).
/// Rows are written first, then delivered when the app opens, connectivity returns, or WorkManager fires.
class OutboxWorker {
  OutboxWorker(this._db, this._clock, this.handlers);

  final AppDatabase _db;
  final Clock _clock;
  final Map<String, OutboxHandler> handlers;
  bool _running = false;

  Future<String> enqueue(String kind, Map<String, dynamic> payload) async {
    final id = const Uuid().v4();
    final now = _clock.now().millisecondsSinceEpoch;
    await _db.into(_db.outbox).insert(
        OutboxCompanion.insert(id: id, kind: kind, payload: jsonEncode(payload), nextAttemptAt: now, createdAt: now));
    return id;
  }

  Future<int> pending() async => (await _db.select(_db.outbox).get()).length;

  /// Whether the job [id] (from [enqueue]) is still waiting.
  Future<bool> isQueued(String id) async => (await (_db.select(_db.outbox)..where((t) => t.id.equals(id))).getSingleOrNull()) != null;

  /// Runs every due row once. Returns how many were delivered. Safe to call concurrently.
  Future<int> runDue() async {
    if (_running) return 0;
    _running = true;
    var delivered = 0;
    try {
      final now = _clock.now().millisecondsSinceEpoch;
      final rows = await (_db.select(_db.outbox)
            ..where((t) => t.nextAttemptAt.isSmallerOrEqualValue(now))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();
      for (final row in rows) {
        final handler = handlers[row.kind];
        if (handler == null) continue;
        OutboxResult result;
        String? error;
        try {
          result = await handler(jsonDecode(row.payload) as Map<String, dynamic>);
        } on ApiError catch (e) {
          error = e.toString();
          result = e.isRetryable ? OutboxResult.retry : OutboxResult.drop;
        } catch (e) {
          error = e.toString();
          result = OutboxResult.retry;
        }
        switch (result) {
          case OutboxResult.done:
            delivered++;
            await (_db.delete(_db.outbox)..where((t) => t.id.equals(row.id))).go();
          case OutboxResult.drop:
            await (_db.delete(_db.outbox)..where((t) => t.id.equals(row.id))).go();
          case OutboxResult.retry:
            final attempts = row.attempts + 1;
            await (_db.update(_db.outbox)..where((t) => t.id.equals(row.id))).write(OutboxCompanion(
              attempts: Value(attempts),
              nextAttemptAt: Value(_clock.now().add(outboxBackoff(attempts)).millisecondsSinceEpoch),
              lastError: Value(error),
            ));
        }
      }
    } finally {
      _running = false;
    }
    return delivered;
  }
}
