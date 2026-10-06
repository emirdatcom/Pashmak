import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widget_snapshot.dart';
import '../../streak/domain/streak_service.dart';
import '../../wallet/domain/wallet_service.dart';

class ExerciseCompletion {
  const ExerciseCompletion({required this.energyGranted, required this.rewarded});
  final int energyGranted;
  final bool rewarded;
}

/// Exercise sessions. A session that is not completed (user left early) has no `completed_at` and no
/// reward. `journal_text` stays on the device: it is stored in the encrypted DB and never reaches
/// analytics or logs (docs/80 §1).
class ExerciseService {
  ExerciseService(this._db, this._clock, this._wallet, this._streak, this._analytics, this._publisher,
      {required this.today, required this.energyPerExercise, required this.rewardsPerDay, required this.freeExercises, this.onCompleted});

  final AppDatabase _db;
  final Clock _clock;
  final WalletService _wallet;
  final StreakService _streak;
  final AnalyticsService _analytics;
  final WidgetSnapshotPublisher _publisher;
  final LocalDay Function() today;
  final int Function() energyPerExercise;
  final int Function() rewardsPerDay;
  final List<String> Function() freeExercises;

  /// Called with the exercise key after a session is completed (ticks the goals linked to it).
  final Future<void> Function(String exerciseKey)? onCompleted;

  /// `limits.free_exercises` from config is the single source of truth for locks.
  bool isLocked(String exerciseKey, {required bool isPremium}) => !isPremium && !freeExercises().contains(exerciseKey);

  Future<String> start(String exerciseKey) async {
    final id = const Uuid().v7();
    final now = _clock.now().millisecondsSinceEpoch;
    await _db.into(_db.exerciseSessions).insert(ExerciseSessionsCompanion.insert(
        id: id, exerciseKey: exerciseKey, startedAt: now, localDay: today().value, createdAt: now, updatedAt: now));
    await _analytics.track(AnalyticsEvent.exerciseStarted, {'exercise_key': exerciseKey});
    return id;
  }

  Future<int> _rewardsToday() async {
    final sessions = await (_db.select(_db.exerciseSessions)..where((s) => s.localDay.equals(today().value) & s.completedAt.isNotNull())).get();
    if (sessions.isEmpty) return 0;
    final ids = sessions.map((s) => s.id).toList();
    final rows = await (_db.select(_db.walletLedger)..where((l) => l.reason.equals('exercise_done') & l.refId.isIn(ids))).get();
    return rows.length;
  }

  Future<ExerciseCompletion> complete(String sessionId, {required int durationS, String? journalText}) async {
    final session = await (_db.select(_db.exerciseSessions)..where((s) => s.id.equals(sessionId))).getSingle();
    if (session.completedAt != null) return const ExerciseCompletion(energyGranted: 0, rewarded: false);
    final now = _clock.now().millisecondsSinceEpoch;
    final text = journalText?.trim();
    var granted = 0;
    await _db.transaction(() async {
      final canReward = await _rewardsToday() < rewardsPerDay();
      await (_db.update(_db.exerciseSessions)..where((s) => s.id.equals(sessionId))).write(ExerciseSessionsCompanion(
          completedAt: Value(now), durationS: Value(durationS), journalText: Value((text == null || text.isEmpty) ? null : text), updatedAt: Value(now)));
      if (canReward) granted = await _wallet.grant(Currency.energy, energyPerExercise(), 'exercise_done', sessionId) ?? 0;
    });
    await _streak.recordActivity(today());
    await onCompleted?.call(session.exerciseKey);
    await _analytics.track(AnalyticsEvent.exerciseCompleted, {'exercise_key': session.exerciseKey, 'duration_s': durationS});
    await _publisher.refresh();
    return ExerciseCompletion(energyGranted: granted, rewarded: granted > 0);
  }
}
