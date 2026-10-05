
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widget_snapshot.dart';
import '../../streak/domain/streak_service.dart';

/// Rest mode (prompt 22 §12). While on: the streak is frozen (no freeze spent), only trial notifications
/// are planned, no daily quests are generated and the home screen shows a kind message.
class PauseService {
  PauseService(this._db, this._clock, this._streak, this._analytics, this._publisher, {required this.today});

  final AppDatabase _db;
  final Clock _clock;
  final StreakService _streak;
  final AnalyticsService _analytics;
  final WidgetSnapshotPublisher _publisher;
  final LocalDay Function() today;

  Future<bool> isPaused() async => await _db.setting('pause_mode') == 'true';

  Stream<bool> watch() => (_db.select(_db.userSettings)..where((t) => t.key.equals('pause_mode'))).watchSingleOrNull().map((r) => r?.value == 'true');

  Future<void> set(bool on) async {
    if (await isPaused() == on) return;
    await _db.setSetting('pause_mode', on ? 'true' : 'false');
    if (on) {
      await _db.setSetting('paused_since', '${_clock.now().millisecondsSinceEpoch}');
    } else {
      await _streak.resumeFromPause(today());
      await _db.setSetting('paused_since', '');
    }
    await _analytics.track(AnalyticsEvent.pauseModeToggled, {'on': on});
    await _publisher.refresh();
  }
}
