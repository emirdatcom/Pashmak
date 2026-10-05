import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/safety/distress_detector.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widget_snapshot.dart';
import '../../safety/domain/safety_service.dart';
import '../../streak/domain/streak_service.dart';
import '../../wallet/domain/wallet_service.dart';

class CheckinResult {
  const CheckinResult({required this.id, required this.isFirstToday, required this.moodLevel, this.showSafetyCard = false});
  final String id;
  final bool isFirstToday;
  final int moodLevel;
  final bool showSafetyCard;
}

/// The emotional check-in. `mood_level` and the note never leave the device and never reach analytics.
class CheckinService {
  CheckinService(this._db, this._clock, this._wallet, this._streak, this._safety, this._analytics, this._publisher,
      {required this.energyPerCheckin, required this.today, required this.detector});

  static const maxNoteLength = 1000;

  final AppDatabase _db;
  final Clock _clock;
  final WalletService _wallet;
  final StreakService _streak;
  final SafetyService _safety;
  final AnalyticsService _analytics;
  final WidgetSnapshotPublisher _publisher;
  final int Function() energyPerCheckin;
  final LocalDay Function() today;
  final DistressDetector Function() detector;

  Future<bool> doneToday() async =>
      (await (_db.select(_db.checkins)..where((c) => c.localDay.equals(today().value) & c.deletedAt.isNull())).get()).isNotEmpty;

  Stream<int?> watchLastMoodToday() => (_db.select(_db.checkins)
        ..where((c) => c.localDay.equals(today().value) & c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
        ..limit(1))
      .watch()
      .map((r) => r.isEmpty ? null : r.first.moodLevel);

  Future<CheckinResult> submit(int moodLevel, {String? note, String source = 'app'}) async {
    if (moodLevel < 1 || moodLevel > 5) throw ArgumentError.value(moodLevel, 'moodLevel', 'must be 1..5');
    final text = note?.trim();
    if (text != null && text.length > maxNoteLength) throw ArgumentError('note too long');
    final day = today();
    final now = _clock.now().millisecondsSinceEpoch;
    final id = const Uuid().v7();
    final first = !(await doneToday());
    await _db.transaction(() async {
      await _db.into(_db.checkins).insert(CheckinsCompanion.insert(
          id: id, localDay: day.value, moodLevel: moodLevel, note: Value((text == null || text.isEmpty) ? null : text), source: Value(source), createdAt: now, updatedAt: now));
      if (first) await _wallet.grant(Currency.energy, energyPerCheckin(), 'checkin', id);
    });
    final streak = await _streak.recordActivity(day);
    // Distress detection runs locally on the saved data.
    final window = day.addDays(-30);
    final rows = await (_db.select(_db.checkins)..where((c) => c.deletedAt.isNull() & c.localDay.isBiggerOrEqualValue(window.value))).get();
    final kind = detector().evaluate(recent: [for (final r in rows) CheckinPoint(r.localDay, r.moodLevel)], today: day.value, note: text);
    final showCard = kind != null && await _safety.flag(kind, day);
    // Analytics: only has_note and source. Never the mood or the text.
    await _analytics.track(AnalyticsEvent.checkinCompleted, {'has_note': text != null && text.isNotEmpty, 'source': source});
    if (streak.changed) await _analytics.track(AnalyticsEvent.streakUpdated, {'current': streak.snapshot.current, 'freeze_used': streak.freezeUsed});
    await _publisher.refresh();
    return CheckinResult(id: id, isFirstToday: first, moodLevel: moodLevel, showSafetyCard: showCard);
  }
}
