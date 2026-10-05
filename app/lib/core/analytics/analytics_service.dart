import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../time/clock.dart';
import 'analytics_event.dart';

Map<String, Object?> _noProps() => const {};

/// `track` never blocks UI and never throws.
abstract class AnalyticsService {
  Future<void> track(AnalyticsEvent event, [Map<String, Object?> props = const {}]);
}

class NoopAnalytics implements AnalyticsService {
  const NoopAnalytics();
  @override
  Future<void> track(AnalyticsEvent event, [Map<String, Object?> props = const {}]) async {}
}

/// Writes events to `analytics_queue` (cap 5000 rows). A later step flushes batches to `/v1/events`.
/// Honors the `analytics_opt_out` setting: nothing is queued and the queue is emptied.
class QueueAnalytics implements AnalyticsService {
  QueueAnalytics(this._db, this._clock, {required this.sessionId, this.commonProps = _noProps});

  final AppDatabase _db;
  final Clock _clock;
  final String Function() sessionId;
  final Map<String, Object?> Function() commonProps;
  static const maxRows = 5000;

  @override
  Future<void> track(AnalyticsEvent event, [Map<String, Object?> props = const {}]) async {
    try {
      if (await _db.setting('analytics_opt_out') == 'true') {
        await _db.delete(_db.analyticsQueue).go();
        return;
      }
      final clean = <String, Object?>{};
      void put(String k, Object? v) {
        if (analyticsForbiddenProps.contains(k.toLowerCase()) || v == null) return;
        final ok = event.allowedProps.contains(k) ||
            analyticsCommonProps.contains(k) ||
            analyticsCommonPrefixes.any((p) => k.startsWith(p) && k.length > p.length);
        if (ok) clean[k] = v;
      }

      commonProps().forEach(put);
      props.forEach(put);
      await _db.into(_db.analyticsQueue).insert(AnalyticsQueueCompanion.insert(
          id: const Uuid().v4(),
          name: event.wireName,
          props: jsonEncode(clean),
          ts: _clock.now().millisecondsSinceEpoch,
          sessionId: sessionId()));
      final count = await _db.analyticsQueue.count().getSingle();
      if (count > maxRows) {
        await _db.customStatement(
            'DELETE FROM analytics_queue WHERE id IN (SELECT id FROM analytics_queue ORDER BY ts ASC LIMIT ?)',
            [count - maxRows]);
      }
    } catch (_) {
      // analytics must never affect the app
    }
  }
}
