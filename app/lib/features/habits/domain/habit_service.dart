import 'dart:convert';

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
import 'goal_schedule.dart';

/// A habit scheduled for a day plus its progress.
class TodayHabit {
  const TodayHabit({required this.habit, required this.count, this.goalOfDay = false});
  final Habit habit;
  final int count;

  /// The one goal the user starred for today (listed first).
  final bool goalOfDay;
  bool get done => count >= habit.targetPerDay;
}


enum CompleteStatus { completed, alreadyDone, locked, notFound }

class CompleteResult {
  const CompleteResult(this.status, {this.energyGranted = 0, this.logId, this.streak});
  final CompleteStatus status;
  final int energyGranted;
  final String? logId;
  final StreakOutcome? streak;
}

/// Why creating a habit is gated, mapped to a paywall trigger (docs/60 §5).
enum HabitGate { fourthHabit, customHabit }

extension HabitGateTrigger on HabitGate {
  String get trigger => this == HabitGate.fourthHabit ? 'fourth_habit' : 'custom_habit';
}

class HabitDraft {
  const HabitDraft({
    this.templateKey,
    this.title,
    this.icon = 'check',
    this.scheduleType = 'daily',
    this.weekdaysMask = 127,
    this.targetPerDay = 1,
    this.reminderMinutes,
    this.areaKey,
    this.timeOfDay = 'any',
    this.repeatType = 'daily',
    this.dueDay,
    this.exerciseKey,
    this.keepUntilDone = false,
    this.source = 'custom',
  });

  /// Goal-library key (kept under the old name; stored in both `template_key` and `goal_key`).
  final String? templateKey;
  final String? areaKey;
  final String timeOfDay; // morning | afternoon | evening | bedtime | any
  final String repeatType; // daily | weekly | monthly | once
  final String? dueDay; // local_day: the day of `once`, the anchor of `monthly`, else an optional first day
  final String source; // suggested | tab | custom (analytics)
  final String? title;
  final String icon;
  final String scheduleType; // daily | weekly
  final int weekdaysMask; // bit0 = Saturday … bit6 = Friday
  final int targetPerDay;
  final int? reminderMinutes;

  /// Exercise (exercises pack key) that this goal starts; finishing it ticks the goal.
  final String? exerciseKey;

  /// An undone `once` goal stays on the following days until it is done.
  final bool keepUntilDone;
  bool get isCustom => templateKey == null;
}

/// Habits and their daily completion (docs/30 §3–§4).
class HabitService {
  HabitService(
    this._db,
    this._clock,
    this._wallet,
    this._streak,
    this._analytics,
    this._publisher, {
    required this.energyPerGoal,
    required this.freeActiveHabits,
    required this.freeCustomHabits,
    required this.today,
  });

  final AppDatabase _db;
  final Clock _clock;
  final WalletService _wallet;
  final StreakService _streak;
  final AnalyticsService _analytics;
  final WidgetSnapshotPublisher _publisher;
  final int Function() energyPerGoal;
  final int Function() freeActiveHabits;
  final int Function() freeCustomHabits;
  final LocalDay Function() today;

  int _now() => _clock.now().millisecondsSinceEpoch;

  Expression<bool> _active($HabitsTable h) => h.archivedAt.isNull() & h.deletedAt.isNull();

  Future<int> activeCount() async {
    final rows = await (_db.select(_db.habits)..where((h) => _active(h) & h.isLocked.equals(false))).get();
    return rows.length;
  }

  /// Premium ended: every active habit not in [keepIds] becomes read-only (locked, never deleted).
  Future<void> lockExcept(Set<String> keepIds) => _db.transaction(() async {
        final rows = await (_db.select(_db.habits)..where(_active)).get();
        for (final h in rows) {
          final lock = !keepIds.contains(h.id);
          if (h.isLocked != lock) {
            await (_db.update(_db.habits)..where((t) => t.id.equals(h.id))).write(HabitsCompanion(isLocked: Value(lock), updatedAt: Value(_now())));
          }
        }
      });

  /// Premium restored: everything is writable again.
  Future<void> unlockAll() => (_db.update(_db.habits)..where((h) => h.isLocked.equals(true))).write(HabitsCompanion(isLocked: const Value(false), updatedAt: Value(_now())));

  /// Active habits (locked or not) — the lock-selection screen lists these.
  Future<List<Habit>> activeHabits() => (_db.select(_db.habits)..where(_active)..orderBy([(h) => OrderingTerm.asc(h.sortOrder)])).get();

  /// Returns the gate that blocks creating this habit for a free user, or null if allowed.
  Future<HabitGate?> gateFor(HabitDraft draft, {required bool isPremium}) async {
    if (isPremium) return null;
    if (draft.isCustom && freeCustomHabits() <= 0) return HabitGate.customHabit;
    if (await activeCount() >= freeActiveHabits()) return HabitGate.fourthHabit;
    return null;
  }

  Future<String> create(HabitDraft d) async {
    final id = const Uuid().v7();
    final now = _now();
    final order = ((await (_db.select(_db.habits)..where(_active)).get()).map((h) => h.sortOrder).fold<int>(-1, (a, b) => a > b ? a : b)) + 1;
    final first = (await _db.select(_db.habits).get()).isEmpty;
    await _db.into(_db.habits).insert(HabitsCompanion.insert(
          id: id,
          templateKey: Value(d.templateKey),
          goalKey: Value(d.templateKey),
          areaKey: Value(d.areaKey),
          timeOfDay: Value(d.timeOfDay),
          repeatType: Value(d.repeatType),
          dueDay: Value(d.dueDay),
          title: Value(d.title),
          icon: Value(d.icon),
          scheduleType: Value(d.scheduleType),
          weekdaysMask: Value(d.weekdaysMask),
          targetPerDay: Value(d.targetPerDay),
          reminderMinutes: Value(d.reminderMinutes),
          exerciseKey: Value(d.exerciseKey),
          keepUntilDone: Value(d.keepUntilDone),
          isCustom: Value(d.isCustom),
          sortOrder: Value(order),
          createdAt: now,
          updatedAt: now,
        ));
    final tk = d.templateKey ?? 'custom';
    await _analytics.track(AnalyticsEvent.goalCreated, {'source': d.source, 'area_key': d.areaKey ?? 'none'});
    if (first) await _analytics.track(AnalyticsEvent.firstHabitCreated, {'template_key': tk});
    await _publisher.refresh();
    return id;
  }

  Future<void> update(String id, HabitDraft d) async {
    await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(HabitsCompanion(
      title: Value(d.title),
      icon: Value(d.icon),
      scheduleType: Value(d.scheduleType),
      weekdaysMask: Value(d.weekdaysMask),
      targetPerDay: Value(d.targetPerDay),
      reminderMinutes: Value(d.reminderMinutes),
      exerciseKey: Value(d.exerciseKey),
      keepUntilDone: Value(d.keepUntilDone),
      areaKey: Value(d.areaKey),
      timeOfDay: Value(d.timeOfDay),
      repeatType: Value(d.repeatType),
      dueDay: Value(d.dueDay),
      updatedAt: Value(_now()),
    ));
    await _publisher.refresh();
  }

  Future<void> archive(String id) async {
    await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(HabitsCompanion(archivedAt: Value(_now()), updatedAt: Value(_now())));
    await _publisher.refresh();
  }

  Future<void> reorder(List<String> orderedIds) => _db.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (_db.update(_db.habits)..where((h) => h.id.equals(orderedIds[i]))).write(HabitsCompanion(sortOrder: Value(i), updatedAt: Value(_now())));
        }
      });

  Future<Habit?> byId(String id) => (_db.select(_db.habits)..where((h) => h.id.equals(id))).getSingleOrNull();

  Stream<List<Habit>> watchAll() =>
      (_db.select(_db.habits)..where(_active)..orderBy([(h) => OrderingTerm.asc(h.sortOrder)])).watch();

  /// Habits scheduled on [day] (Saturday-first `weekdays_mask`), with progress. Locked habits are shown
  /// read-only by the UI (`habit.isLocked`).
  static bool scheduledOn(Habit h, LocalDay day) =>
      goalScheduledOn(repeatType: h.repeatType, dueDay: h.dueDay, scheduleType: h.scheduleType, weekdaysMask: h.weekdaysMask, day: day);

  Stream<List<TodayHabit>> watchToday() {
    final day = today();
    final q = _db.select(_db.habits).join([
      leftOuterJoin(_db.habitLogs, _db.habitLogs.habitId.equalsExp(_db.habits.id) & _db.habitLogs.localDay.equals(day.value) & _db.habitLogs.deletedAt.isNull()),
    ])
      ..where(_db.habits.archivedAt.isNull() & _db.habits.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(_db.habits.sortOrder)]);
    return q.watch().asyncMap((rows) async {
      // `once` goals marked "keep until complete" whose day has passed: they stay until some day has a completion.
      final overdue = [
        for (final r in rows)
          if (_carriesOver(r.readTable(_db.habits), day)) r.readTable(_db.habits).id,
      ];
      final doneBefore = overdue.isEmpty
          ? const <String>{}
          : {
              for (final l in await (_db.select(_db.habitLogs)
                    ..where((l) => l.habitId.isIn(overdue) & l.deletedAt.isNull() & l.localDay.isSmallerThanValue(day.value)))
                  .get())
                l.habitId,
            };
      final state = await _todayState();
      final list = [
        for (final r in rows)
          if (!state.skipped.contains(r.readTable(_db.habits).id) &&
              (scheduledOn(r.readTable(_db.habits), day) || (overdue.contains(r.readTable(_db.habits).id) && !doneBefore.contains(r.readTable(_db.habits).id))))
            TodayHabit(habit: r.readTable(_db.habits), count: r.readTableOrNull(_db.habitLogs)?.count ?? 0, goalOfDay: r.readTable(_db.habits).id == state.star),
      ];
      return [...list.where((t) => t.goalOfDay), ...list.where((t) => !t.goalOfDay)];
    });
  }

  // --- today's view state: goals skipped for today and the goal of the day. It is not history, so it lives in one
  // app_meta row tagged with its local day (a new day starts clean) and is not part of backups.
  static const _todayStateKey = 'today_goal_state';

  Future<({Set<String> skipped, String? star})> _todayState() async {
    final raw = await _db.meta(_todayStateKey);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['day'] == today().value) return (skipped: {...((j['skipped'] as List?) ?? const []).cast<String>()}, star: j['star'] as String?);
    }
    return (skipped: <String>{}, star: null);
  }

  Future<void> _saveTodayState(Set<String> skipped, String? star, {required String touch}) async {
    await _db.setMeta(_todayStateKey, jsonEncode({'day': today().value, 'skipped': skipped.toList(), 'star': star}));
    // watchToday listens to the habits table: touching the row makes it read this state again.
    await (_db.update(_db.habits)..where((h) => h.id.equals(touch))).write(HabitsCompanion(updatedAt: Value(_now())));
    await _publisher.refresh();
  }

  /// Hides the goal for the rest of today; nothing is logged and no energy is given.
  Future<void> skipToday(String habitId) async {
    final s = await _todayState();
    await _saveTodayState({...s.skipped, habitId}, s.star == habitId ? null : s.star, touch: habitId);
  }

  /// Until tomorrow: a goal with a single day moves to tomorrow, a repeating one is just hidden for today.
  Future<void> snooze(String habitId) async {
    final h = await byId(habitId);
    if (h == null) return;
    if (h.repeatType == 'once') {
      await (_db.update(_db.habits)..where((x) => x.id.equals(habitId))).write(HabitsCompanion(dueDay: Value(today().addDays(1).value), updatedAt: Value(_now())));
      await _publisher.refresh();
    } else {
      await skipToday(habitId);
    }
  }

  /// Stars the goal as today's goal of the day (or removes the star when it already has it).
  Future<void> toggleGoalOfDay(String habitId) async {
    final s = await _todayState();
    await _saveTodayState(s.skipped, s.star == habitId ? null : habitId, touch: habitId);
  }

  static bool _carriesOver(Habit h, LocalDay day) =>
      h.repeatType == 'once' && h.keepUntilDone == true && h.dueDay != null && h.dueDay!.compareTo(day.value) < 0;

  /// Ticks today's undone goals linked to [exerciseKey] (called when that exercise is finished).
  Future<void> completeLinked(String exerciseKey) async {
    for (final t in await watchToday().first) {
      if (t.habit.exerciseKey == exerciseKey && !t.done && !t.habit.isLocked) await complete(t.habit.id);
    }
  }

  /// Completes (or increments) today's log. Energy is granted once per habit and day.
  Future<CompleteResult> complete(String habitId, {String source = 'app'}) async {
    final habit = await byId(habitId);
    if (habit == null || habit.archivedAt != null || habit.deletedAt != null) return const CompleteResult(CompleteStatus.notFound);
    if (habit.isLocked) return const CompleteResult(CompleteStatus.locked);
    final day = today();
    final result = await _db.transaction(() async {
      final now = _now();
      final log = await (_db.select(_db.habitLogs)..where((l) => l.habitId.equals(habitId) & l.localDay.equals(day.value))).getSingleOrNull();
      String logId;
      if (log == null) {
        logId = const Uuid().v7();
        await _db.into(_db.habitLogs).insert(HabitLogsCompanion.insert(
            id: logId, habitId: habitId, localDay: day.value, completedAt: now, source: Value(source), createdAt: now, updatedAt: now));
      } else {
        logId = log.id;
        if (log.deletedAt == null && log.count >= habit.targetPerDay) return CompleteResult(CompleteStatus.alreadyDone, logId: logId);
        await (_db.update(_db.habitLogs)..where((l) => l.id.equals(logId))).write(HabitLogsCompanion(
            count: Value(log.deletedAt != null ? 1 : log.count + 1), deletedAt: const Value(null), completedAt: Value(now), updatedAt: Value(now)));
      }
      var granted = await _wallet.grant(Currency.energy, energyPerGoal(), 'habit_done', logId) ?? 0;
      if (granted == 0 && log != null && log.deletedAt != null) {
        // Re-completing after an undo that really took the energy back: grant once more (net effect
        // stays one reward, so there is nothing to farm). If the undo kept the energy, nothing is granted.
        final orig = await (_db.select(_db.walletLedger)..where((t) => t.reason.equals('habit_done') & t.refId.equals(logId))).getSingleOrNull();
        final reversed = orig == null
            ? null
            : await (_db.select(_db.walletLedger)..where((t) => t.reason.equals('adjust') & t.refId.equals('undo:${orig.id}'))).getSingleOrNull();
        if (reversed != null) granted = await _wallet.grant(Currency.energy, energyPerGoal(), 'habit_done', '$logId:redo') ?? 0;
      }
      return CompleteResult(CompleteStatus.completed, energyGranted: granted, logId: logId);
    });
    final streak = await _streak.recordActivity(day);
    await _analytics.track(AnalyticsEvent.goalCompleted, {'goal_key': habit.goalKey ?? habit.templateKey ?? 'custom', 'source': source});
    if (streak.changed) {
      await _analytics.track(AnalyticsEvent.streakUpdated, {'current': streak.snapshot.current, 'freeze_used': streak.freezeUsed});
    }
    await _publisher.refresh();
    return CompleteResult(result.status, energyGranted: result.energyGranted, logId: result.logId, streak: streak);
  }

  /// Undo today's completion. Energy is taken back only if the balance still covers it.
  Future<bool> undo(String habitId) async {
    final day = today();
    final log = await (_db.select(_db.habitLogs)..where((l) => l.habitId.equals(habitId) & l.localDay.equals(day.value) & l.deletedAt.isNull())).getSingleOrNull();
    if (log == null) return false;
    await _db.transaction(() async {
      await (_db.update(_db.habitLogs)..where((l) => l.id.equals(log.id))).write(HabitLogsCompanion(deletedAt: Value(_now()), updatedAt: Value(_now())));
      await _wallet.reverse('habit_done', log.id);
    });
    await _publisher.refresh();
    return true;
  }

  /// Completed days of [habitId] within [start]..[end] (inclusive), for the weekly calendar.
  Future<Set<String>> doneDays(String habitId, LocalDay start, LocalDay end) async {
    final rows = await (_db.select(_db.habitLogs)
          ..where((l) => l.habitId.equals(habitId) & l.deletedAt.isNull() & l.localDay.isBetweenValues(start.value, end.value)))
        .get();
    return {for (final r in rows) r.localDay};
  }
}
