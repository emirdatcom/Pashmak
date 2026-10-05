import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';
import '../time/clock.dart';

/// Sends queued events to `POST /v1/events` in batches (docs/70). Rows are deleted only after the server
/// answered 200 (events it rejected are not retried: they would be rejected again); network/5xx errors
/// keep the queue for the next attempt.
class AnalyticsFlusher {
  AnalyticsFlusher(this._db, this._api, this._clock);

  final AppDatabase _db;
  final ApiClient _api;
  final Clock _clock;

  static const batchSize = 100;
  static const minBatchToSend = 20; // flush earlier than app-open only when this many are waiting
  bool _running = false;

  Future<int> pending() async => _db.analyticsQueue.count().getSingle();

  /// Sends everything that is queued (several batches). Returns how many events the server accepted.
  Future<int> flush() async {
    if (_running) return 0;
    _running = true;
    var accepted = 0;
    try {
      if (await _db.setting('analytics_opt_out') == 'true') {
        await _db.delete(_db.analyticsQueue).go();
        return 0;
      }
      while (true) {
        final rows = await (_db.select(_db.analyticsQueue)
              ..orderBy([(t) => OrderingTerm.asc(t.ts)])
              ..limit(batchSize))
            .get();
        if (rows.isEmpty) break;
        try {
          final r = await _api.request<Map<String, dynamic>>('POST', '/v1/events', data: {
            'sent_at': _clock.now().toUtc().toIso8601String(),
            'events': [
              for (final e in rows)
                {
                  'event_id': e.id,
                  'name': e.name,
                  'ts': DateTime.fromMillisecondsSinceEpoch(e.ts, isUtc: true).toIso8601String(),
                  'session_id': e.sessionId,
                  'props': jsonDecode(e.props),
                },
            ],
          });
          accepted += (r.data?['accepted'] as int?) ?? 0;
        } on ApiError catch (e) {
          if (e.isRetryable || e.status == 401) break; // try again later
          // 400/413: the batch itself is bad; dropping it avoids blocking the queue forever.
        }
        await (_db.delete(_db.analyticsQueue)..where((t) => t.id.isIn([for (final e in rows) e.id]))).go();
        if (rows.length < batchSize) break;
      }
    } finally {
      _running = false;
    }
    return accepted;
  }
}
