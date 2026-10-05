import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/cat/domain/cat_mood_resolver.dart';
import '../../features/habits/domain/habit_service.dart';
import '../db/app_database.dart';
import '../l10n/digits.dart';
import '../time/clock.dart';
import '../time/local_day.dart';
import '../widgets/cat_renderer.dart';

class WidgetHabit {
  const WidgetHabit({required this.id, required this.title, required this.done});
  final String id;
  final String title;
  final bool done;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
}

/// What the Android widgets show. **Only** habit titles/status, streak, a check-in flag and the cat mood:
/// never the check-in mood level or notes (docs/20 §8, docs/80 §4). Persian digits are pre-rendered so the
/// Kotlin side needs no number formatting.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.catMood,
    required this.habits,
    required this.doneCount,
    required this.totalCount,
    required this.streak,
    required this.checkedInToday,
    required this.validUntilMs,
    required this.streakText,
    required this.progressText,
  });

  final String catMood; // happy | sleepy | sad | proud
  final List<WidgetHabit> habits; // at most 3
  final int doneCount;
  final int totalCount;
  final int streak;
  final bool checkedInToday;

  /// When the app's "today" ends. After this instant the widget must not show yesterday's ticks.
  final int validUntilMs;
  final String streakText;
  final String progressText;

  Map<String, dynamic> toJson() => {
        'cat_mood': catMood,
        'habits_today': [for (final h in habits) h.toJson()],
        'done_count': doneCount,
        'total_count': totalCount,
        'streak': streak,
        'checked_in_today': checkedInToday,
        'valid_until_ms': validUntilMs,
        'streak_text': streakText,
        'progress_text': progressText,
        'locale_digits': 'fa',
      };

  String encode() => jsonEncode(toJson());
}

/// Builds the snapshot straight from the database (works in the background isolate too).
class WidgetSnapshotBuilder {
  WidgetSnapshotBuilder(this._db, this._clock, {required this.dayStartHour, required this.habitTitle, required this.streakLabel, required this.progressLabel});

  final AppDatabase _db;
  final Clock _clock;
  final int dayStartHour;
  final String Function(Habit h) habitTitle;
  final String Function(int days) streakLabel; // already Persian-digit text from copy
  final String Function(int done, int total) progressLabel;

  Future<WidgetSnapshot> build() async {
    final now = _clock.now();
    final today = LocalDay.of(now, dayStartHour: dayStartHour);
    final habits = await (_db.select(_db.habits)
          ..where((h) => h.archivedAt.isNull() & h.deletedAt.isNull() & h.isLocked.equals(false))
          ..orderBy([(h) => OrderingTerm.asc(h.sortOrder)]))
        .get();
    final logs = await (_db.select(_db.habitLogs)..where((l) => l.localDay.equals(today.value) & l.deletedAt.isNull())).get();
    final counts = {for (final l in logs) l.habitId: l.count};
    final scheduled = [for (final h in habits) if (HabitService.scheduledOn(h, today)) h];
    bool done(Habit h) => (counts[h.id] ?? 0) >= h.targetPerDay;
    final doneCount = scheduled.where(done).length;

    final checkins = await (_db.select(_db.checkins)
          ..where((c) => c.localDay.equals(today.value) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
          ..limit(1))
        .get();
    final adventure = await (_db.select(_db.adventures)..where((a) => a.status.equals('active'))).getSingleOrNull();
    final streak = (await _db.select(_db.streakState).getSingle()).current;
    final mood = CatMoodResolver.resolve(
      adventureActive: adventure != null,
      localHour: now.hour,
      lastCheckinMoodToday: checkins.isEmpty ? null : checkins.first.moodLevel,
      allHabitsDoneToday: scheduled.isNotEmpty && doneCount == scheduled.length,
      adventureJustClaimed: false,
    );
    // Not-done habits first so the quick ticks are the useful ones.
    final shown = [...scheduled.where((h) => !done(h)), ...scheduled.where(done)].take(3);
    final nextDay = DateTime(today.year, today.month, today.day).add(Duration(days: 1, hours: dayStartHour));
    return WidgetSnapshot(
      catMood: adventure != null ? CatMood.happy.name : mood.mood.name,
      habits: [for (final h in shown) WidgetHabit(id: h.id, title: habitTitle(h), done: done(h))],
      doneCount: doneCount,
      totalCount: scheduled.length,
      streak: streak,
      checkedInToday: checkins.isNotEmpty,
      validUntilMs: nextDay.millisecondsSinceEpoch,
      streakText: streakLabel(streak),
      progressText: progressLabel(doneCount, scheduled.length),
    );
  }
}

/// Digits helper for callers that format counts themselves.
String faNumber(int n) => toPersianDigits(n);
