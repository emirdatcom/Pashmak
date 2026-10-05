import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/safety/distress_detector.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/local_day.dart';

/// Stores `safety_flags` (device-only) and decides when the kind card may be shown: at most once per
/// `safety.card_cooldown_hours`. No paywall, no analytics reason, no follow-up notification (docs/80 §5).
class SafetyService {
  SafetyService(this._db, this._clock, {required this.cooldownHours});

  final AppDatabase _db;
  final Clock _clock;
  final int Function() cooldownHours;

  /// Records a flag and returns true if the card should be shown now.
  Future<bool> flag(DistressKind kind, LocalDay today) async {
    final now = _clock.now().millisecondsSinceEpoch;
    final since = now - cooldownHours() * 3600 * 1000;
    final recent = await (_db.select(_db.safetyFlags)..where((f) => f.shownAt.isBiggerOrEqualValue(since))).get();
    if (recent.isNotEmpty) return false;
    await _db.into(_db.safetyFlags).insert(SafetyFlagsCompanion.insert(
        id: const Uuid().v7(), localDay: today.value, kind: kind == DistressKind.keyword ? 'keyword' : 'low_mood_streak', shownAt: Value(now)));
    return true;
  }

  /// The card is visible while the latest flag was shown within the cooldown and not dismissed.
  Stream<bool> watchCardVisible() => (_db.select(_db.safetyFlags)..orderBy([(f) => OrderingTerm.desc(f.shownAt)])..limit(1)).watch().map((rows) {
        if (rows.isEmpty) return false;
        final f = rows.first;
        return f.dismissedAt == null && f.shownAt != null;
      });

  Future<void> dismissCard() async {
    await (_db.update(_db.safetyFlags)..where((f) => f.dismissedAt.isNull())).write(SafetyFlagsCompanion(dismissedAt: Value(_clock.now().millisecondsSinceEpoch)));
  }
}
