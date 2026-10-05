import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/widgets_home/widget_callbacks.dart';
import 'package:pashmak_app/core/widgets_home/widget_snapshot.dart';
import 'package:pashmak_app/core/widgets_home/widget_snapshot_publisher.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';

import 'core_loop_helpers.dart';

class FakeBridge implements WidgetBridge {
  final saved = <String, String>{};
  int updates = 0;
  @override
  Future<void> save(String key, String value) async => saved[key] = value;
  @override
  Future<void> updateAll() async => updates++;
}

void main() {
  final t0 = DateTime(2026, 10, 5, 9); // Monday 09:00

  WidgetSnapshotBuilder builder(Loop l) => WidgetSnapshotBuilder(l.db, l.clock,
      dayStartHour: 4, habitTitle: (h) => h.templateKey ?? h.title ?? '', streakLabel: (n) => 'streak $n', progressLabel: (d, t) => '$d/$t');

  group('snapshot', () {
    test('at most three habits, undone first; counts include every scheduled habit', () async {
      final l = Loop(t0);
      final ids = [for (final k in ['water', 'sleep', 'walk', 'medicine']) await l.habits.create(HabitDraft(templateKey: k))];
      await l.habits.complete(ids[0]);
      final s = await builder(l).build();
      expect(s.habits, hasLength(3));
      expect(s.habits.map((h) => h.done), [false, false, false], reason: 'done habits sort last, so they fall off the list');
      expect((s.doneCount, s.totalCount), (1, 4));
      expect(s.catMood, 'happy');
    });

    test('privacy: no mood level, no note, no habit ids beyond the three shown', () async {
      final l = Loop(t0);
      await l.habits.create(const HabitDraft(templateKey: 'water'));
      await l.checkins.submit(1, note: 'یادداشت خصوصی');
      final json = (await builder(l).build()).encode();
      expect(json, isNot(contains('یادداشت')));
      expect(json.contains('mood_level'), isFalse);
      expect(jsonDecode(json)['checked_in_today'], isTrue);
      expect(jsonDecode(json)['cat_mood'], 'sad', reason: 'derived cat state, not the raw mood');
    });

    test('a new day invalidates yesterday: valid_until is the next day start and the builder shows fresh state', () async {
      final l = Loop(t0);
      final id = await l.habits.create(const HabitDraft(templateKey: 'water'));
      await l.habits.complete(id);
      final today = await builder(l).build();
      expect(DateTime.fromMillisecondsSinceEpoch(today.validUntilMs), DateTime(2026, 10, 6, 4));
      expect(today.doneCount, 1);
      l.clock.set(DateTime(2026, 10, 6, 5));
      final next = await builder(l).build();
      expect(next.doneCount, 0);
      expect(next.habits.single.done, isFalse);
    });

    test('locked and archived habits never appear', () async {
      final l = Loop(t0);
      final a = await l.habits.create(const HabitDraft(templateKey: 'water'));
      await l.habits.create(const HabitDraft(templateKey: 'walk'));
      await l.habits.lockExcept({a});
      expect((await builder(l).build()).habits.map((h) => h.title), ['water']);
    });
  });

  group('actions', () {
    test('uri parsing', () {
      expect((WidgetAction.parse(Uri.parse('app://habit/abc')) as CompleteHabitAction).habitId, 'abc');
      expect((WidgetAction.parse(Uri.parse('app://checkin?mood=4')) as QuickCheckinAction).mood, 4);
      expect(WidgetAction.parse(Uri.parse('app://checkin?mood=9')), isNull);
      expect(WidgetAction.parse(Uri.parse('app://checkin')), isNull);
      expect(WidgetAction.parse(Uri.parse('app://habit/')), isNull);
      expect(WidgetAction.parse(null), isNull);
    });

    test('tick from the widget: source=widget, energy once, snapshot republished', () async {
      final l = Loop(t0);
      final id = await l.habits.create(const HabitDraft(templateKey: 'water'));
      var republished = 0;
      final h = WidgetActionHandler(l.habits, l.checkins, () async => republished++);
      expect(await h.handle(CompleteHabitAction(id)), isTrue);
      expect((await l.db.select(l.db.habitLogs).getSingle()).source, 'widget');
      expect((await l.wallet.balance()).energy, l.config.energyPerGoal);
      expect(await h.handle(CompleteHabitAction(id)), isTrue, reason: 'already done is fine');
      expect((await l.wallet.balance()).energy, l.config.energyPerGoal, reason: 'no extra energy');
      expect(republished, 2);
      expect(await h.handle(const CompleteHabitAction('nope')), isFalse);
    });

    test('quick check-in: source=widget and energy only for the first of the day', () async {
      final l = Loop(t0);
      final h = WidgetActionHandler(l.habits, l.checkins, () async {});
      await h.handle(const QuickCheckinAction(3));
      await h.handle(const QuickCheckinAction(4));
      final rows = await l.db.select(l.db.checkins).get();
      expect(rows.map((r) => r.source).toSet(), {'widget'});
      expect((await l.wallet.balance()).energy, l.config.energyPerCheckin);
    });
  });

  group('publisher', () {
    test('writes the snapshot and updates all three widgets; disabled flag does nothing; errors are swallowed', () async {
      final l = Loop(t0);
      await l.habits.create(const HabitDraft(templateKey: 'water'));
      final bridge = FakeBridge();
      var on = true;
      final pub = HomeWidgetPublisher(builder(l), bridge, enabled: () => on);
      await pub.refresh();
      expect(jsonDecode(bridge.saved[widgetPrefsKey]!)['habits_today'], hasLength(1));
      expect(bridge.updates, 1);
      on = false;
      await pub.refresh();
      expect(bridge.updates, 1);
      await l.db.close();
      on = true;
      await pub.refresh(); // closed DB → exception inside, must not escape
    });
  });
}
