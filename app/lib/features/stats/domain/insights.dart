import 'package:drift/drift.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/db/app_database.dart';
import '../../../core/time/local_day.dart';

enum StatsRange { week, month }

/// One chart point: the average mood (1..5) of a day, or null when there was no check-in.
class MoodPoint {
  const MoodPoint(this.day, this.mood);
  final LocalDay day;
  final double? mood;
}

class HeatRow {
  const HeatRow(this.habit, this.done);
  final Habit habit;
  final List<bool> done; // aligned with the days of the range
}

class HabitMoodInsight {
  const HabitMoodInsight(this.habit, this.difference);
  final Habit habit;
  final double difference; // average mood on days it was done minus days it was not
}

class Insights {
  const Insights({required this.days, required this.mood, required this.heat, this.bestWeekday, required this.correlations});
  final List<LocalDay> days;
  final List<MoodPoint> mood;
  final List<HeatRow> heat;
  final int? bestWeekday; // 0 = Saturday … 6 = Friday
  final List<HabitMoodInsight> correlations;
}

/// The days of the current Saturday-first week or Jalali month, in order.
List<LocalDay> rangeDays(StatsRange range, LocalDay today) {
  if (range == StatsRange.week) {
    final start = today.addDays(-today.weekdayIndex);
    return [for (var i = 0; i < 7; i++) start.addDays(i)];
  }
  final j = Jalali.fromDateTime(today.date);
  final first = LocalDay.fromDate(Jalali(j.year, j.month, 1).toDateTime());
  return [for (var i = 0; i < j.monthLength; i++) first.addDays(i)];
}

/// Pure maths over already-loaded data, so every rule is table-testable.
class InsightMath {
  const InsightMath._();

  static const minWeekdaySamples = 3;
  static const minDaysPerSide = 5;
  static const minDifference = 0.4;

  /// Average mood per `LocalDay.value`.
  static Map<String, double> averageByDay(Iterable<({String day, int mood})> checkins) {
    final sums = <String, List<int>>{};
    for (final c in checkins) {
      (sums[c.day] ??= []).add(c.mood);
    }
    return {for (final e in sums.entries) e.key: e.value.reduce((a, b) => a + b) / e.value.length};
  }

  /// The weekday (0 = Saturday) with the highest average mood; needs [minWeekdaySamples] days each.
  static int? bestWeekday(Map<String, double> byDay) {
    final byWd = <int, List<double>>{};
    byDay.forEach((day, m) => (byWd[LocalDay.parse(day).weekdayIndex] ??= []).add(m));
    int? best;
    double bestAvg = -1;
    byWd.forEach((wd, list) {
      if (list.length < minWeekdaySamples) return;
      final avg = list.reduce((a, b) => a + b) / list.length;
      if (avg > bestAvg + 1e-9) {
        bestAvg = avg;
        best = wd;
      }
    });
    return best;
  }

  /// Mood on days a habit was done vs not done; only reported with enough days on both sides and a clear gap.
  /// Descriptive only (no causal claim).
  static double? moodDifference(Map<String, double> byDay, Set<String> doneDays) {
    final done = <double>[], notDone = <double>[];
    byDay.forEach((day, m) => (doneDays.contains(day) ? done : notDone).add(m));
    if (done.length < minDaysPerSide || notDone.length < minDaysPerSide) return null;
    final d = done.reduce((a, b) => a + b) / done.length - notDone.reduce((a, b) => a + b) / notDone.length;
    return d >= minDifference ? d : null;
  }
}

/// Local-only analytics for the premium stats screen: nothing here leaves the device.
class InsightsService {
  InsightsService(this._db);
  final AppDatabase _db;

  static const lookbackDays = 90;

  Future<Insights> compute(StatsRange range, LocalDay today) async {
    final days = rangeDays(range, today);
    final from = today.addDays(-lookbackDays).value;
    final checkins = await (_db.select(_db.checkins)..where((c) => c.deletedAt.isNull() & c.localDay.isBiggerOrEqualValue(from))).get();
    final byDay = InsightMath.averageByDay([for (final c in checkins) (day: c.localDay, mood: c.moodLevel)]);
    final logs = await (_db.select(_db.habitLogs)..where((l) => l.deletedAt.isNull() & l.localDay.isBiggerOrEqualValue(from))).get();
    final habits = await (_db.select(_db.habits)..where((h) => h.archivedAt.isNull() & h.deletedAt.isNull())..orderBy([(h) => OrderingTerm.asc(h.sortOrder)])).get();
    final doneByHabit = <String, Set<String>>{};
    for (final l in logs) {
      (doneByHabit[l.habitId] ??= {}).add(l.localDay);
    }
    final correlations = <HabitMoodInsight>[];
    for (final h in habits) {
      final d = InsightMath.moodDifference(byDay, doneByHabit[h.id] ?? const {});
      if (d != null) correlations.add(HabitMoodInsight(h, d));
    }
    correlations.sort((a, b) => b.difference.compareTo(a.difference));
    return Insights(
      days: days,
      mood: [for (final d in days) MoodPoint(d, byDay[d.value])],
      heat: [for (final h in habits) HeatRow(h, [for (final d in days) (doneByHabit[h.id] ?? const {}).contains(d.value)])],
      bestWeekday: InsightMath.bestWeekday(byDay),
      correlations: correlations,
    );
  }
}
