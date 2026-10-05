import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/time/local_day.dart';

class StreakSnapshot {
  const StreakSnapshot({required this.current, required this.longest, required this.freezesLeft, this.lastActiveDay});
  final int current;
  final int longest;
  final int freezesLeft;
  final LocalDay? lastActiveDay;
}

/// What happened while evaluating, for UI and analytics. `reset` means "start over" (never blame the user).
class StreakOutcome {
  const StreakOutcome({required this.snapshot, this.reset = false, this.freezeUsed = false, this.changed = false});
  final StreakSnapshot snapshot;
  final bool reset;
  final bool freezeUsed;
  final bool changed;
}

/// Daily streak with a monthly "forgiveness day" (docs/30 §5). The freeze budget resets at the start
/// of every Persian month.
class StreakService {
  StreakService(this._db, {required this.freezesPerMonth});

  final AppDatabase _db;
  final int Function() freezesPerMonth;

  Stream<StreakSnapshot> watch() => _db.select(_db.streakState).watchSingle().map(_snap);

  StreakSnapshot _snap(StreakStateData s) => StreakSnapshot(
      current: s.current,
      longest: s.longest,
      freezesLeft: s.freezesLeft,
      lastActiveDay: s.lastActiveDay == null ? null : LocalDay.parse(s.lastActiveDay!));

  Future<StreakSnapshot> snapshot() async => _snap(await _db.select(_db.streakState).getSingle());

  /// Resets the monthly freeze budget and handles a missed day. Call when the app opens / a new day starts.
  Future<StreakOutcome> evaluate(LocalDay today) => _db.transaction(() async {
        var s = await _db.select(_db.streakState).getSingle();
        // Rest mode freezes the streak: no reset and no freeze is spent while it is on.
        if (await _db.setting('pause_mode') == 'true') return StreakOutcome(snapshot: _snap(s));
        var changed = false;
        final month = JalaliFormatter.monthKey(today);
        var freezes = s.freezesLeft;
        if (s.freezeMonth != month) {
          freezes = freezesPerMonth();
          changed = true;
        }
        var current = s.current;
        var last = s.lastActiveDay == null ? null : LocalDay.parse(s.lastActiveDay!);
        var reset = false, freezeUsed = false;
        if (last != null && current > 0) {
          final gap = last.daysUntil(today);
          if (gap == 2 && freezes > 0) {
            freezes--; // the missed day is forgiven
            last = today.addDays(-1);
            freezeUsed = true;
            changed = true;
          } else if (gap >= 2) {
            current = 0;
            reset = true;
            changed = true;
          }
        }
        if (changed || s.freezeMonth != month) {
          await _db.update(_db.streakState).write(StreakStateCompanion(
              current: Value(current), freezesLeft: Value(freezes), freezeMonth: Value(month), lastActiveDay: Value(last?.value)));
          s = await _db.select(_db.streakState).getSingle();
        }
        return StreakOutcome(snapshot: _snap(s), reset: reset, freezeUsed: freezeUsed, changed: changed);
      });

  /// Marks [today] as an active day (habit done, check-in, or finished exercise).
  Future<StreakOutcome> recordActivity(LocalDay today) => _db.transaction(() async {
        final before = await evaluate(today);
        final s = await _db.select(_db.streakState).getSingle();
        final last = s.lastActiveDay == null ? null : LocalDay.parse(s.lastActiveDay!);
        if (last == today) return StreakOutcome(snapshot: _snap(s), reset: before.reset, freezeUsed: before.freezeUsed);
        final continues = last != null && last.daysUntil(today) == 1 && s.current > 0;
        final current = continues ? s.current + 1 : 1;
        final longest = current > s.longest ? current : s.longest;
        await _db.update(_db.streakState).write(StreakStateCompanion(current: Value(current), longest: Value(longest), lastActiveDay: Value(today.value)));
        return StreakOutcome(
            snapshot: _snap(await _db.select(_db.streakState).getSingle()), reset: before.reset, freezeUsed: before.freezeUsed, changed: true);
      });

  /// Rest mode ended: continue "from the same point" — the last active day becomes yesterday so the next
  /// activity extends the streak instead of resetting it.
  Future<void> resumeFromPause(LocalDay today) async {
    final s = await _db.select(_db.streakState).getSingle();
    if (s.current <= 0) return;
    await _db.update(_db.streakState).write(StreakStateCompanion(lastActiveDay: Value(today.addDays(-1).value)));
  }
}
