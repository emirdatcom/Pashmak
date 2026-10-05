import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/features/notifications/domain/notification_planner.dart';

PlannerSettings settings({
  Map<String, bool>? enabled,
  int morning = 540,
  int evening = 1230,
  int max = 3,
}) =>
    PlannerSettings(
      enabled: enabled ?? {for (final t in notificationPriority) t: t != 'streak_gentle'},
      morningMinutes: morning,
      eveningMinutes: evening,
      maxPerDay: max,
    );

DateTime d(int day, [int h = 10, int m = 0]) => DateTime(2026, 10, day, h, m); // 2026-10-05 is a Monday

List<PlanItem> plan(PlanInput i) => planNotifications(i);

List<PlanItem> ofType(List<PlanItem> l, String t) => l.where((x) => x.type == t).toList();

void main() {
  final now = d(5, 6, 0);

  test('seven days of morning + evening, deterministic ids', () {
    final p = plan(PlanInput(now: now, settings: settings()));
    expect(ofType(p, 'morning').length, 7);
    expect(ofType(p, 'evening_checkin').length, 7);
    final again = plan(PlanInput(now: now, settings: settings()));
    expect(p.map((x) => x.id).toList(), again.map((x) => x.id).toList());
    expect(p.first.id, startsWith('morning::2026-10-05'));
    expect(p.map((x) => x.intId).toSet().length, p.length, reason: 'no id collisions');
  });

  group('quiet hours 22:30–08:00', () {
    test('morning at 07:00 moves to 08:00 the same day', () {
      final p = plan(PlanInput(now: now, settings: settings(morning: 420)));
      final m = ofType(p, 'morning').first;
      expect((m.fireAt.day, m.fireAt.hour, m.fireAt.minute), (5, 8, 0));
    });
    test('evening at 23:00 moves to 08:00 next day', () {
      final p = plan(PlanInput(now: now, settings: settings(evening: 23 * 60)));
      final e = ofType(p, 'evening_checkin').first;
      expect((e.fireAt.day, e.fireAt.hour), (6, 8));
    });
    test('the cat returning inside quiet hours is dropped, not delayed', () {
      final i = PlanInput(now: now, settings: settings(), adventure: PlanAdventure(id: 'a', endsAt: d(5, 23, 30)));
      expect(ofType(plan(i), 'cat_returned'), isEmpty);
      final ok = PlanInput(now: now, settings: settings(), adventure: PlanAdventure(id: 'a', endsAt: d(5, 15, 0)));
      expect(ofType(plan(ok), 'cat_returned').single.fireAt, d(5, 15, 0));
    });
  });

  group('daily cap', () {
    test('5 candidates in one day keep the 3 with highest priority', () {
      final habits = [
        const PlanHabit(id: 'h1', templateKey: 'water', reminderMinutes: 600, scheduleType: 'daily', weekdaysMask: 127),
        const PlanHabit(id: 'h2', templateKey: 'walk', reminderMinutes: 1000, scheduleType: 'daily', weekdaysMask: 127),
      ];
      final p = plan(PlanInput(
          now: d(5, 5, 0),
          settings: settings(),
          habits: habits,
          adventure: PlanAdventure(id: 'a', endsAt: d(5, 16, 0)),
          trial: PlanTrial(active: true, startedAt: d(0 + 5 - 5 + 5 - 0, 8).subtract(const Duration(days: 5))))); // trial day 6 = Oct 5
      final today = p.where((x) => x.fireAt.day == 5).toList();
      expect(today.length, 3);
      expect(today.map((x) => x.type).toSet(), {'trial', 'habit_reminder'}, reason: 'trial + two reminders beat cat/evening/morning');
      // on a normal day (no trial) priority is habit > cat > evening > morning
      final q = plan(PlanInput(now: d(5, 5, 0), settings: settings(), habits: habits, adventure: PlanAdventure(id: 'a', endsAt: d(5, 16, 0)))).where((x) => x.fireAt.day == 5).map((x) => x.type).toList();
      expect(q.where((t) => t == 'habit_reminder').length, 2);
      expect(q, contains('cat_returned'));
      expect(q, isNot(contains('morning')));
    });
    test('max_per_day is configurable', () {
      final p = plan(PlanInput(now: d(5, 5, 0), settings: settings(max: 1)));
      expect(p.where((x) => x.fireAt.day == 5).length, 1);
    });
  });

  group('ignored notifications reduce frequency', () {
    List<PlanLogEntry> ignored(String type, int n, {String ref = '', Set<int> openedIndexes = const {}}) => [
          for (var k = 0; k < n; k++)
            PlanLogEntry(type: type, ref: ref, scheduledFor: d(5, 20, 30).subtract(Duration(days: n - k)), openedAt: openedIndexes.contains(k) ? d(5) : null),
        ];

    test('3 unopened evening check-ins → every other day; opening one resets', () {
      final base = PlanInput(now: d(5, 6, 0), settings: settings(), log: ignored('evening_checkin', 3));
      final days = ofType(plan(base), 'evening_checkin').map((x) => x.fireAt.day).toList();
      // last logged on Oct 4 → next allowed Oct 6, then 8, 10 (every other day, window ends Oct 11)
      expect(days, [6, 8, 10]);
      final reset = PlanInput(now: d(5, 6, 0), settings: settings(), log: ignored('evening_checkin', 3, openedIndexes: {2}));
      expect(ofType(plan(reset), 'evening_checkin').length, 7);
    });
    test('6 ignored → weekly', () {
      final p = plan(PlanInput(now: d(5, 6, 0), settings: settings(), log: ignored('evening_checkin', 6)));
      expect(ofType(p, 'evening_checkin').length, 1);
    });
    test('habit reminders are counted per habit', () {
      final habits = [
        const PlanHabit(id: 'a', templateKey: 'water', reminderMinutes: 600, scheduleType: 'daily', weekdaysMask: 127),
        const PlanHabit(id: 'b', templateKey: 'walk', reminderMinutes: 700, scheduleType: 'daily', weekdaysMask: 127),
      ];
      final p = plan(PlanInput(now: d(5, 5, 0), settings: settings(max: 9), habits: habits, log: ignored('habit_reminder', 3, ref: 'a')));
      expect(p.where((x) => x.type == 'habit_reminder' && x.ref == 'a').length, lessThan(7));
      expect(p.where((x) => x.type == 'habit_reminder' && x.ref == 'b').length, 7);
    });
  });

  group('habit reminders', () {
    test('done today → no more reminder today; weekday mask is Saturday-first; locked habits are skipped', () {
      final habits = [
        const PlanHabit(id: 'done', templateKey: 'water', reminderMinutes: 700, scheduleType: 'daily', weekdaysMask: 127, doneToday: true),
        const PlanHabit(id: 'mon', templateKey: 'walk', reminderMinutes: 1000, scheduleType: 'weekly', weekdaysMask: 0x04), // Monday only
        const PlanHabit(id: 'locked', templateKey: 'sleep', reminderMinutes: 1000, scheduleType: 'daily', weekdaysMask: 127, isLocked: true),
      ];
      final p = plan(PlanInput(now: d(5, 5, 0), settings: settings(max: 99), habits: habits));
      final done = p.where((x) => x.ref == 'done').map((x) => x.fireAt.day).toList();
      expect(done, [6, 7, 8, 9, 10, 11], reason: 'today is done; tomorrow on');
      expect(p.where((x) => x.ref == 'mon').map((x) => x.fireAt.day).toList(), [5, 12 - 0].where((x) => x <= 11).toList());
      expect(p.where((x) => x.ref == 'locked'), isEmpty);
    });
    test('body key uses the template or the generic copy; vars carry the habit name', () {
      final p = plan(PlanInput(
          now: d(5, 5, 0),
          settings: settings(max: 99),
          habits: [
            const PlanHabit(id: 'w', templateKey: 'water', reminderMinutes: 700, scheduleType: 'daily', weekdaysMask: 127),
            const PlanHabit(id: 'c', title: 'ورزش', reminderMinutes: 800, scheduleType: 'daily', weekdaysMask: 127),
          ]));
      expect(ofType(p, 'habit_reminder').firstWhere((x) => x.ref == 'w').bodyKey, 'notif.habit_reminder.water');
      final c = ofType(p, 'habit_reminder').firstWhere((x) => x.ref == 'c');
      expect((c.bodyKey, c.vars['habit']), ('notif.habit_reminder.generic', 'ورزش'));
    });
  });

  test('evening check-in is skipped today once checked in', () {
    final p = plan(PlanInput(now: d(5, 5, 0), settings: settings(), checkedInToday: true));
    expect(ofType(p, 'evening_checkin').first.fireAt.day, 6);
  });

  group('comeback 3/7/14', () {
    test('scheduled relative to the last open, inside the window only', () {
      final p = plan(PlanInput(now: d(5, 12, 0), settings: settings(), lastOpenedAt: d(5, 11, 0)));
      expect(ofType(p, 'comeback').map((x) => (x.fireAt.day, x.fireAt.hour, x.ref)).toList(), [(8, 18, '3')]);
      final later = plan(PlanInput(now: d(5, 12, 0), settings: settings(), lastOpenedAt: d(2, 11, 0)));
      expect(ofType(later, 'comeback').map((x) => x.ref).toList(), ['3', '7'], reason: 'day 3 (Oct 5 18:00) and day 7 (Oct 9)');
    });
  });

  group('trial reminders (days 6 and 7)', () {
    test('only while the trial is active and nothing was bought', () {
      final started = d(1, 9);
      PlanInput input(PlanTrial t) => PlanInput(now: d(5, 5, 0), settings: settings(), trial: t);
      final p = plan(input(PlanTrial(active: true, startedAt: started)));
      expect(ofType(p, 'trial').map((x) => (x.fireAt.day, x.ref, x.bodyKey)).toList(), [(6, '6', 'notif.trial.6'), (7, '7', 'notif.trial.7')]);
      expect(ofType(plan(input(PlanTrial(active: true, startedAt: started, purchased: true))), 'trial'), isEmpty);
      expect(ofType(plan(input(const PlanTrial(active: false))), 'trial'), isEmpty);
    });
  });

  group('streak_gentle (opt-in)', () {
    test('off by default; when on needs streak >= 3, not active today, none in the last 2 days', () {
      PlanInput input({bool on = true, int streak = 4, bool active = false, List<PlanLogEntry> log = const []}) => PlanInput(
          now: d(5, 5, 0), settings: settings(enabled: {'streak_gentle': on}), streakCurrent: streak, activeToday: active, log: log);
      expect(ofType(plan(input()), 'streak_gentle').single.fireAt.hour, 19);
      expect(ofType(plan(input(on: false)), 'streak_gentle'), isEmpty);
      expect(ofType(plan(input(streak: 2)), 'streak_gentle'), isEmpty);
      expect(ofType(plan(input(active: true)), 'streak_gentle'), isEmpty);
      expect(ofType(plan(input(log: [PlanLogEntry(type: 'streak_gentle', scheduledFor: d(4, 19))])), 'streak_gentle'), isEmpty);
    });
  });

  test('disabled types (user switch or remote kill switch) produce nothing; past times are dropped', () {
    final p = plan(PlanInput(now: d(5, 10, 0), settings: settings(enabled: {'morning': false, 'evening_checkin': true})));
    expect(ofType(p, 'morning'), isEmpty);
    expect(p.every((x) => x.fireAt.isAfter(d(5, 10, 0))), isTrue);
  });
}
