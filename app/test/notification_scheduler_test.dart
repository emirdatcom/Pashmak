import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/content/copy_resolver.dart';
import 'package:pashmak_app/core/db/app_database.dart';
import 'package:pashmak_app/core/notifications/notification_service.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/notifications/data/notification_scheduler.dart';

import 'core_loop_helpers.dart';

DateTime at(int d, [int h = 10, int m = 0]) => DateTime(2026, 10, d, h, m);

({Loop l, FakeNotificationService svc, NotificationScheduler sched}) make({DateTime? now}) {
  final l = Loop(now ?? at(5, 6, 0));
  final svc = FakeNotificationService();
  final copy = CopyResolver(
    bundled: Map<String, dynamic>.from(l.copyEntries),
    appName: 'اپ',
    defaultCatName: 'ملوس',
    today: () => l.today().value,
  );
  final sched = NotificationScheduler(db: l.db, clock: l.clock, service: svc, config: () => l.config, copy: () => copy, analytics: l.analytics);
  return (l: l, svc: svc, sched: sched);
}

void main() {
  test('plans morning/evening for 7 days with resolved Persian texts within the length limits', () async {
    final t = make();
    final out = await t.sched.replan();
    expect(out.where((n) => n.type == 'morning').length, 7);
    for (final n in out) {
      expect(n.body, isNotEmpty);
      expect(n.body.runes.length, lessThanOrEqualTo(80), reason: n.planId);
      expect(n.title.runes.length, lessThanOrEqualTo(25), reason: n.planId);
      expect(n.body, isNot(contains('{')), reason: 'no unresolved variables');
    }
    expect(t.svc.calls.length, 1);
  });

  test('a habit reminder shows the habit name, offers the "done" action; completing it removes today\'s reminder', () async {
    final t = make(now: at(5, 6, 0));
    final id = await t.l.habits.create(const HabitDraft(title: 'ورزش', reminderMinutes: 13 * 60));
    var out = await t.sched.replan();
    final todayReminder = out.firstWhere((n) => n.type == 'habit_reminder' && n.fireAt.day == 5);
    expect(todayReminder.body, contains('ورزش'));
    expect(todayReminder.actionLabel, 'انجام شد');
    expect(todayReminder.route, '/goals/$id');
    await t.l.habits.complete(id, source: 'notification');
    out = await t.sched.replan();
    expect(out.where((n) => n.type == 'habit_reminder' && n.fireAt.day == 5), isEmpty);
    expect(out.where((n) => n.type == 'habit_reminder' && n.fireAt.day == 6).length, 1);
    final log = await t.l.db.select(t.l.db.habitLogs).getSingle();
    expect(log.source, 'notification');
    expect((await t.l.wallet.balance()).energy, 5, reason: 'the quick action earns energy like a normal tick');
  });

  test('the remote kill switch and the user switches remove types; streak_gentle is opt-in', () async {
    final t = make();
    t.l.config.raw['notifications']['types_enabled']['morning'] = false;
    expect((await t.sched.replan()).where((n) => n.type == 'morning'), isEmpty);
    await t.l.db.setSetting(NotifSettingKeys.enabled('evening_checkin'), 'false');
    expect((await t.sched.replan()).where((n) => n.type == 'evening_checkin'), isEmpty);
    // streak_gentle only when the user opts in and has a streak
    await t.l.streak.recordActivity(t.l.today());
    expect((await t.sched.replan()).where((n) => n.type == 'streak_gentle'), isEmpty);
  });

  test('exact alarms apply only to habit reminders and only when opted in', () async {
    final t = make();
    await t.l.habits.create(const HabitDraft(title: 'x', reminderMinutes: 14 * 60));
    var out = await t.sched.replan();
    expect(out.any((n) => n.exact), isFalse);
    await t.l.db.setSetting(NotifSettingKeys.exactAlarms, 'true');
    out = await t.sched.replan();
    expect(out.where((n) => n.exact).every((n) => n.type == 'habit_reminder'), isTrue);
    expect(out.any((n) => n.exact), isTrue);
  });

  test('trial reminders (day 6, 7) only while the trial is active and nothing was bought', () async {
    final t = make(now: at(3, 6, 0));
    await t.l.db.setMeta('trial_started_at', '${at(1, 9).millisecondsSinceEpoch}');
    await t.l.db.setMeta('trial_ends_at', '${at(8, 9).millisecondsSinceEpoch}');
    var out = await t.sched.replan();
    expect(out.where((n) => n.type == 'trial').map((n) => n.fireAt.day).toList(), [6, 7]);
    expect(out.firstWhere((n) => n.type == 'trial').route, '/paywall?trigger=trial_end');
    await t.l.db.setMeta('premium_purchased', 'true');
    out = await t.sched.replan();
    expect(out.where((n) => n.type == 'trial'), isEmpty);
  });

  test('tap: opened_at is logged and notification_opened carries only the type', () async {
    final t = make();
    final out = await t.sched.replan();
    final n = out.first;
    await t.sched.onOpened(NotificationTap(route: n.route, type: n.type, ref: n.ref, planId: n.planId));
    final row = await (t.l.db.select(t.l.db.notificationLog)..where((l) => l.id.equals(n.planId))).getSingle();
    expect(row.openedAt, isNotNull);
    final q = await t.l.db.select(t.l.db.analyticsQueue).get();
    expect(q.single.name, 'notification_opened');
    expect(q.single.props, contains('"type":"${n.type}"'));
    expect(q.single.props, isNot(contains(n.body)));
  });

  test('ignored notifications reduce frequency; opening the app near the time counts as seen', () async {
    final t = make(now: at(5, 6, 0));
    // three past evening check-ins that nobody opened
    for (var d = 2; d <= 4; d++) {
      await t.l.db.into(t.l.db.notificationLog).insert(NotificationLogCompanion.insert(id: 'evening_checkin::2026-10-0$d', type: 'evening_checkin', scheduledFor: at(d, 20, 30).millisecondsSinceEpoch));
    }
    var out = await t.sched.replan();
    expect(out.where((n) => n.type == 'evening_checkin').map((n) => n.fireAt.day).toList(), [6, 8, 10]);
    // the app was opened right after the Oct 4 notification → streak of ignores is broken
    await t.l.db.setMeta('recent_opens', '[${at(4, 21, 0).millisecondsSinceEpoch}]');
    out = await t.sched.replan();
    expect(out.where((n) => n.type == 'evening_checkin').length, 7);
  });

  test('replan failures (e.g. the OS refuses) never throw', () async {
    final t = make();
    final sched = NotificationScheduler(
        db: t.l.db, clock: t.l.clock, service: _Throwing(), config: () => t.l.config, copy: () => CopyResolver(bundled: const {}, appName: 'a', defaultCatName: 'c', today: () => 'x'));
    expect(await sched.replan(), isEmpty);
  });
}

class _Throwing extends NoopNotificationService {
  @override
  Future<void> replaceAll(List<ResolvedNotification> items) async => throw StateError('boom');
}
