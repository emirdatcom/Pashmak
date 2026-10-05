import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/db/app_database.dart';
import 'package:pashmak_app/core/entitlement/premium_gate.dart';
import 'package:pashmak_app/core/safety/distress_detector.dart';
import 'package:pashmak_app/core/time/clock.dart';
import 'package:pashmak_app/core/time/local_day.dart';
import 'package:pashmak_app/core/widgets/cat_renderer.dart';
import 'package:pashmak_app/features/adventure/domain/adventure_service.dart';
import 'package:pashmak_app/features/cat/domain/cat_mood_resolver.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/wallet/domain/wallet_service.dart';

import 'core_loop_helpers.dart';
import 'helpers.dart';

DateTime at(int d, [int h = 10, int m = 0]) => DateTime(2026, 10, d, h, m);

Future<String> water(Loop l) => l.habits.create(const HabitDraft(templateKey: 'water'));

void main() {
  group('WalletService', () {
    test('grants are idempotent per (reason, ref_id) and the cache equals the ledger', () async {
      final l = Loop(at(5));
      expect(await l.wallet.grant(Currency.coins, 10, 'promo', 'x'), 10);
      expect(await l.wallet.grant(Currency.coins, 10, 'promo', 'x'), isNull);
      expect((await l.wallet.balance()).coins, 10);
      await l.wallet.rebuildCache();
      expect((await l.wallet.balance()).coins, 10);
    });
    test('energy is capped at economy.energy_cap; coins are not', () async {
      final l = Loop(at(5));
      await l.wallet.grant(Currency.energy, 95, 'promo', 'a');
      expect(await l.wallet.grant(Currency.energy, 10, 'promo', 'b'), 5);
      expect((await l.wallet.balance()).energy, 100);
      await l.wallet.grant(Currency.coins, 5000, 'promo', 'c');
      expect((await l.wallet.balance()).coins, 5000);
    });
    test('spend refuses when funds are insufficient and never goes negative', () async {
      final l = Loop(at(5));
      await l.wallet.grant(Currency.coins, 10, 'promo', 'a');
      expect(await l.wallet.spend(Currency.coins, 11, 'shop_purchase', 's1'), isFalse);
      expect(await l.wallet.spend(Currency.coins, 10, 'shop_purchase', 's2'), isTrue);
      expect((await l.wallet.balance()).coins, 0);
    });
    test('reverse only when the balance still covers it', () async {
      final l = Loop(at(5));
      await l.wallet.grant(Currency.energy, 10, 'habit_done', 'log1');
      expect(await l.wallet.spend(Currency.energy, 5, 'adventure_start', 'adv'), isTrue);
      expect(await l.wallet.reverse('habit_done', 'log1'), isFalse, reason: 'only 5 left; keep it, no punishment');
      expect((await l.wallet.balance()).energy, 5);
    });
  });

  group('habits', () {
    test('completing grants +10 energy once; undo takes it back; re-complete grants one fresh reward', () async {
      final l = Loop(at(5));
      final id = await water(l);
      final r1 = await l.habits.complete(id);
      expect(r1.status, CompleteStatus.completed);
      expect(r1.energyGranted, 10);
      expect((await l.habits.complete(id)).status, CompleteStatus.alreadyDone);
      expect((await l.wallet.balance()).energy, 10);
      // undo takes it back (balance covers it), re-completing the same day grants nothing (anti-farming)
      expect(await l.habits.undo(id), isTrue);
      expect((await l.wallet.balance()).energy, 0);
      final r2 = await l.habits.complete(id);
      expect(r2.status, CompleteStatus.completed);
      expect(r2.energyGranted, 10, reason: 'the undo really took the energy back, so one fresh reward is fine');
      expect((await l.wallet.balance()).energy, 10);
      // …but only once: undo/redo cycles cannot farm energy
      expect(await l.habits.undo(id), isTrue);
      await l.habits.complete(id);
      expect((await l.wallet.balance()).energy, lessThanOrEqualTo(10));
    });

    test('undo keeps the energy when it was already spent', () async {
      final l = Loop(at(5));
      final id = await water(l);
      await l.habits.complete(id);
      await l.wallet.spend(Currency.energy, 5, 'adventure_start', 'a');
      await l.habits.undo(id);
      expect((await l.wallet.balance()).energy, 5);
    });

    test('free limit: 3 active habits, then fourth_habit; custom is gated; premium is free', () async {
      final l = Loop(at(5));
      for (final k in ['water', 'sleep', 'walk']) {
        expect(await l.habits.gateFor(HabitDraft(templateKey: k), isPremium: false), isNull);
        await l.habits.create(HabitDraft(templateKey: k));
      }
      expect(await l.habits.gateFor(const HabitDraft(templateKey: 'medicine'), isPremium: false), HabitGate.fourthHabit);
      expect(HabitGate.fourthHabit.trigger, 'fourth_habit');
      expect(await l.habits.gateFor(const HabitDraft(title: 'x'), isPremium: false), HabitGate.customHabit);
      expect(await l.habits.gateFor(const HabitDraft(title: 'x'), isPremium: true), isNull);
      // archiving frees a slot
      final first = (await l.habits.watchAll().first).first;
      await l.habits.archive(first.id);
      expect(await l.habits.gateFor(const HabitDraft(templateKey: 'medicine'), isPremium: false), isNull);
    });

    test('weekly schedule uses a Saturday-first mask; locked habits are read-only', () async {
      final l = Loop(at(5)); // Monday 2026-10-05 = index 2 (Sat0, Sun1, Mon2)
      final mon = await l.habits.create(const HabitDraft(templateKey: 'walk', scheduleType: 'weekly', weekdaysMask: 0x04));
      final tue = await l.habits.create(const HabitDraft(templateKey: 'sleep', scheduleType: 'weekly', weekdaysMask: 0x08));
      final today = await l.habits.watchToday().first;
      expect(today.map((t) => t.habit.id), [mon]);
      expect(HabitService.scheduledOn((await l.habits.byId(tue))!, LocalDay.parse('2026-10-06')), isTrue);
      await (l.db.update(l.db.habits)..where((h) => h.id.equals(mon))).write(const HabitsCompanion(isLocked: Value(true)));
      expect((await l.habits.complete(mon)).status, CompleteStatus.locked);
    });

    test('day_start_hour: a completion at 03:30 counts for yesterday', () async {
      final l = Loop(DateTime(2026, 10, 5, 3, 30));
      final id = await water(l);
      await l.habits.complete(id);
      final log = await l.db.select(l.db.habitLogs).getSingle();
      expect(log.localDay, '2026-10-04');
      l.clock.set(DateTime(2026, 10, 5, 4, 0));
      expect((await l.habits.complete(id)).status, CompleteStatus.completed, reason: 'new day at 04:00');
    });
  });

  group('check-in', () {
    test('first check-in of the day gives energy, later ones do not; analytics never contain mood or note', () async {
      final l = Loop(at(5));
      final a = await l.checkins.submit(3, note: 'secret thoughts');
      expect(a.isFirstToday, isTrue);
      final b = await l.checkins.submit(4);
      expect(b.isFirstToday, isFalse);
      expect((await l.wallet.balance()).energy, 5);
      final rows = await l.db.select(l.db.analyticsQueue).get();
      final all = rows.map((r) => '${r.name} ${r.props}').join('\n');
      expect(all, contains('checkin_completed'));
      expect(all, isNot(contains('mood')));
      expect(all, isNot(contains('secret')));
      expect(all, contains('"has_note":true'));
    });
    test('validation: mood 1..5, note <= 1000', () async {
      final l = Loop(at(5));
      expect(() => l.checkins.submit(0), throwsArgumentError);
      expect(() => l.checkins.submit(6), throwsArgumentError);
      expect(() => l.checkins.submit(3, note: 'x' * 1001), throwsArgumentError);
      await l.checkins.submit(3, note: 'x' * 1000);
    });
    test('3 check-ins at level 1 within 4 days show the safety card once; again after 48h', () async {
      final l = Loop(at(2));
      expect((await l.checkins.submit(1)).showSafetyCard, isFalse);
      l.clock.set(at(3));
      expect((await l.checkins.submit(1)).showSafetyCard, isFalse);
      l.clock.set(at(4));
      expect((await l.checkins.submit(1)).showSafetyCard, isTrue, reason: 'third low check-in');
      // within 48h: no second card
      l.clock.set(at(4, 12));
      expect((await l.checkins.submit(1)).showSafetyCard, isFalse);
      // after the cooldown a new low check-in may show it again
      l.clock.set(at(7, 11));
      expect((await l.checkins.submit(1)).showSafetyCard, isTrue);
      l.clock.set(at(7, 12));
      expect((await l.checkins.submit(1)).showSafetyCard, isFalse);
    });
    test('keyword in the note triggers the card (normalizing Arabic letters and ZWNJ)', () async {
      final l = Loop(at(5));
      final r = await l.checkins.submit(3, note: 'امروز حس می‌کنم دلم می‌خواد بمیرم');
      expect(r.showSafetyCard, isTrue);
      final l2 = Loop(at(5));
      expect((await l2.checkins.submit(3, note: 'دلم م\u064A\u200cخواد ب\u0645\u064A\u0631\u0645')).showSafetyCard, isTrue, reason: 'Arabic yeh is normalized');
    });
  });

  group('DistressDetector', () {
    final d = DistressDetector(keywords: const ['نمی‌خوام زنده باشم'], lowMoodLevel: 1, lowMoodCount: 3, windowDays: 4);
    test('window and threshold', () {
      final pts = [const CheckinPoint('2026-10-05', 1), const CheckinPoint('2026-10-03', 1), const CheckinPoint('2026-10-02', 1)];
      expect(d.evaluate(recent: pts, today: '2026-10-05'), DistressKind.lowMoodStreak);
      expect(d.evaluate(recent: pts, today: '2026-10-06'), isNull, reason: '10-02 left the 4-day window and only 2 remain');
      expect(d.evaluate(recent: [const CheckinPoint('2026-10-05', 2)], today: '2026-10-05'), isNull);
    });
    test('keywords match after normalization; ordinary text does not', () {
      expect(d.evaluate(recent: const [], today: '2026-10-05', note: 'نمی خوام زنده  باشم'), DistressKind.keyword);
      expect(d.evaluate(recent: const [], today: '2026-10-05', note: 'امروز روز خوبی بود'), isNull);
    });
  });

  group('streak', () {
    test('continues day to day; a missed day is forgiven once a month; two missed days reset', () async {
      final l = Loop(at(5));
      await l.streak.recordActivity(l.today());
      l.clock.set(at(6));
      expect((await l.streak.recordActivity(l.today())).snapshot.current, 2);
      // skip the 7th, act on the 8th: freeze consumed, streak continues
      l.clock.set(at(8));
      final o = await l.streak.recordActivity(l.today());
      expect(o.freezeUsed, isTrue);
      expect(o.snapshot.current, 3);
      expect(o.snapshot.freezesLeft, 0);
      // skip the 9th and 10th... wait: skip only the 10th now (no freeze left) -> reset
      l.clock.set(at(10));
      final r = await l.streak.recordActivity(l.today());
      expect(r.reset, isTrue);
      expect(r.snapshot.current, 1, reason: 'starts over without blame');
      expect(r.snapshot.longest, 3);
    });
    test('freeze budget resets on the first day of the Persian month (1 Aban = 2026-10-23)', () async {
      final l = Loop(at(20));
      await l.streak.recordActivity(l.today());
      l.clock.set(at(22));
      await l.streak.recordActivity(l.today()); // freeze used (Mehr)
      expect((await l.streak.snapshot()).freezesLeft, 0);
      l.clock.set(at(22, 23, 0));
      expect((await l.streak.evaluate(l.today())).snapshot.freezesLeft, 0, reason: 'still 22 Mehr (day starts at 04:00)');
      l.clock.set(DateTime(2026, 10, 23, 5));
      expect((await l.streak.evaluate(l.today())).snapshot.freezesLeft, 1);
    });
    test('an idle gap of two or more days resets on open (evaluate) without any activity', () async {
      final l = Loop(at(5));
      await l.streak.recordActivity(l.today());
      l.clock.set(at(9));
      final o = await l.streak.evaluate(l.today());
      expect(o.reset, isTrue);
      expect(o.snapshot.current, 0);
    });
  });

  group('CatMoodResolver', () {
    CatVisualState r({bool away = false, int hour = 12, int? mood, bool done = false, bool claimed = false}) => CatMoodResolver.resolve(
        adventureActive: away, localHour: hour, lastCheckinMoodToday: mood, allHabitsDoneToday: done, adventureJustClaimed: claimed);
    test('priority order', () {
      expect(r(away: true, hour: 2, mood: 1, done: true).activity, CatActivity.away);
      expect(r(hour: 23).mood, CatMood.sleepy);
      expect(r(hour: 5, mood: 1).mood, CatMood.sleepy, reason: 'night beats sad');
      expect(r(mood: 2, done: true).mood, CatMood.sad);
      expect(r(mood: 3, done: true).mood, CatMood.proud);
      expect(r(claimed: true).mood, CatMood.proud);
      expect(r().mood, CatMood.happy);
      expect(r(hour: 6).mood, CatMood.happy);
      expect(r(hour: 22).mood, CatMood.happy);
    });
  });

  group('adventure', () {
    Future<Loop> rich() async {
      final l = Loop(at(5));
      await l.wallet.grant(Currency.energy, 100, 'promo', 'seed');
      return l;
    }

    test('start spends energy, fixes the reward, returns after the duration with the same reward', () async {
      final l = await rich();
      final s = await l.adventures.start('alley', isPremium: false);
      expect(s.status, StartStatus.started);
      expect((await l.wallet.balance()).energy, 80);
      final reward = (s.adventure!.rewardCoins, s.adventure!.rewardItemKey, s.adventure!.storyKey);
      expect((await l.adventures.start('rooftop', isPremium: false)).status, StartStatus.alreadyActive);
      expect((await l.adventures.current())!.status, 'active');
      // "kill the app": a fresh service on the same DB, 31 minutes later
      l.clock.advance(const Duration(minutes: 31));
      final again = Loop(l.clock.now(), database: l.db);
      final cur = (await again.adventures.current())!;
      expect(cur.status, 'returned');
      expect((cur.rewardCoins, cur.rewardItemKey, cur.storyKey), reward);
      final claim = (await again.adventures.claim(cur.id))!;
      expect(claim.coins, reward.$1);
      expect((await again.wallet.balance()).coins, reward.$1);
      expect(await again.adventures.claim(cur.id), isNull, reason: 'claimed once');
      expect((await again.wallet.balance()).coins, reward.$1);
      expect(await again.adventures.current(), isNull);
    });

    test('moving the clock back never ends an adventure early', () async {
      final l = await rich();
      await l.adventures.start('alley', isPremium: false);
      l.clock.advance(const Duration(minutes: 10));
      await l.adventures.current();
      l.clock.advance(const Duration(hours: -5)); // user rewinds the clock
      expect((await l.adventures.current())!.status, 'active');
      l.clock.set(at(5, 10, 0).add(const Duration(minutes: 29)));
      expect((await l.adventures.current())!.status, 'active');
    });

    test('rolling the clock back after a forward jump does not shorten the next adventure', () async {
      final l = await rich();
      l.clock.advance(const Duration(days: 2));
      await l.adventures.touch();
      l.clock.advance(const Duration(days: -2));
      final s = await l.adventures.start('alley', isPremium: false);
      expect(s.adventure!.startedAt, greaterThan(at(5).add(const Duration(days: 1)).millisecondsSinceEpoch));
    });

    test('not enough energy; premium locations need premium', () async {
      final l = Loop(at(5));
      expect((await l.adventures.start('alley', isPremium: false)).status, StartStatus.notEnoughEnergy);
      await l.wallet.grant(Currency.energy, 100, 'promo', 'a');
      expect((await l.adventures.start('bazaar', isPremium: false)).status, StartStatus.premiumRequired);
      expect((await l.adventures.start('bazaar', isPremium: true)).status, StartStatus.started);
      expect((await l.adventures.start('nowhere', isPremium: true)).status, StartStatus.unknownLocation);
    });

    test('reward is a pure function of the adventure id', () async {
      final l = await rich();
      final cfg = l.config.adventureLocation('courtyard')!;
      final loc = (l.adventuresPack['locations'] as List).cast<Map<String, dynamic>>().firstWhere((x) => x['location_key'] == 'courtyard');
      AdventureReward calc(String id, Set<String> owned) => AdventureService.computeReward(
          id, cfg, (loc['stories'] as List).cast<Map<String, dynamic>>(), (loc['possible_items'] as List).cast<String>(), owned);
      final a = calc('adv-1', {});
      final b = calc('adv-1', {});
      expect((a.coins, a.itemKey, a.storyKey), (b.coins, b.itemKey, b.storyKey));
      var drops = 0, inRange = true;
      for (var i = 0; i < 2000; i++) {
        final r = calc('id-$i', {});
        if (r.itemKey != null) drops++;
        inRange &= r.coins >= cfg.coinsMin && r.coins <= cfg.coinsMax;
      }
      expect(inRange, isTrue);
      expect(drops / 2000, closeTo(cfg.itemDropRate, 0.04));
      for (var i = 0; i < 200; i++) {
        expect(calc('id-$i', {'rug_small', 'samovar'}).itemKey, isNull, reason: 'owned items never drop');
      }
    });

    test('claiming an item adds it to the inventory with its slot', () async {
      final l = await rich();
      await l.db.into(l.db.adventures).insert(AdventuresCompanion.insert(
          id: 'forced', locationKey: 'courtyard', energyCost: 0, startedAt: 0, endsAt: 1, status: const Value('returned'), rewardCoins: const Value(7), rewardItemKey: const Value('samovar')));
      final c = (await l.adventures.claim('forced'))!;
      expect(c.itemKey, 'samovar');
      final inv = await l.db.select(l.db.inventory).getSingle();
      expect((inv.itemKey, inv.slot, inv.source), ('samovar', 'room_table', 'adventure'));
    });
  });

  group('PremiumGate (docs/60 §5)', () {
    PremiumGate gate(FakeClock c, AppDatabase db, {bool enabled = true}) =>
        PremiumGate(db, c, cooldownHours: () => 24, triggerEnabled: (_) => enabled);
    test('premium and disabled triggers pass through', () async {
      final db = memoryDb();
      final g = gate(FakeClock(at(5)), db);
      expect(await g.evaluate('fourth_habit', isPremium: true), GateDecision.allow);
      expect(await gate(FakeClock(at(5)), db, enabled: false).evaluate('fourth_habit', isPremium: false), GateDecision.allow);
      expect(await g.evaluate('fourth_habit', isPremium: false), GateDecision.showPaywall);
    });
    test('never during exercises, on the safety page, after a low-mood check-in, or before onboarding ends', () async {
      final g = gate(FakeClock(at(5)), memoryDb());
      for (final c in [
        const GateContext(inExercise: true),
        const GateContext(onSafetyScreen: true),
        const GateContext(lowMoodThisSession: true),
        const GateContext(onboardingCompleted: false),
      ]) {
        expect(await g.evaluate('premium_exercise', isPremium: false, context: c), GateDecision.suppressed);
      }
      expect(await g.evaluate('trial_offer', isPremium: false, context: const GateContext(onboardingCompleted: false)), GateDecision.showPaywall);
    });
    test('automatic paywalls respect the cooldown; direct user actions do not', () async {
      final c = FakeClock(at(5));
      final g = gate(c, memoryDb());
      expect(await g.evaluate('settings', isPremium: false, userInitiated: false), GateDecision.showPaywall);
      await g.markShown();
      c.advance(const Duration(hours: 2));
      expect(await g.evaluate('settings', isPremium: false, userInitiated: false), GateDecision.suppressed);
      expect(await g.evaluate('fourth_habit', isPremium: false), GateDecision.showPaywall);
      c.advance(const Duration(hours: 23));
      expect(await g.evaluate('settings', isPremium: false, userInitiated: false), GateDecision.showPaywall);
    });
  });
}
