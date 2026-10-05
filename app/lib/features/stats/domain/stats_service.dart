import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/time/local_day.dart';
import '../../streak/domain/streak_service.dart';

class WeekDay {
  const WeekDay({required this.day, required this.active, required this.isToday, required this.isFuture});
  final LocalDay day;
  final bool active;
  final bool isToday;
  final bool isFuture;
}

class HabitWeekCount {
  const HabitWeekCount(this.habit, this.count);
  final Habit habit;
  final int count;
}

class WeekStats {
  const WeekStats({required this.days, required this.perHabit, required this.streak});
  final List<WeekDay> days; // Saturday … Friday
  final List<HabitWeekCount> perHabit;
  final StreakSnapshot streak;
}

/// MVP stats (docs/30 §8): streak, the current Jalali week and per-habit completions. Pure reads.
class StatsService {
  StatsService(this._db, this._streak);
  final AppDatabase _db;
  final StreakService _streak;

  Future<WeekStats> week(LocalDay today) async {
    final start = today.addDays(-today.weekdayIndex); // Saturday-first week
    final days = [for (var i = 0; i < 7; i++) start.addDays(i)];
    final logs = await (_db.select(_db.habitLogs)
          ..where((l) => l.deletedAt.isNull() & l.localDay.isBiggerOrEqualValue(days.first.value) & l.localDay.isSmallerOrEqualValue(days.last.value)))
        .get();
    final activeDays = {for (final l in logs) l.localDay};
    final habits = await (_db.select(_db.habits)..where((h) => h.archivedAt.isNull() & h.deletedAt.isNull())..orderBy([(h) => OrderingTerm.asc(h.sortOrder)])).get();
    return WeekStats(
      days: [for (final d in days) WeekDay(day: d, active: activeDays.contains(d.value), isToday: d.value == today.value, isFuture: d.value.compareTo(today.value) > 0)],
      perHabit: [for (final h in habits) HabitWeekCount(h, logs.where((l) => l.habitId == h.id).fold(0, (a, l) => a + l.count))],
      streak: await _streak.snapshot(),
    );
  }
}
