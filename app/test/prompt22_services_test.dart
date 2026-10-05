import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/time/local_day.dart';
import 'package:pashmak_app/features/adventure/domain/adventure_service.dart';
import 'package:pashmak_app/features/cat/domain/cat_growth.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/notifications/domain/notification_planner.dart';
import 'package:pashmak_app/features/quests/domain/quest_engine.dart';
import 'package:pashmak_app/features/quests/domain/quest_service.dart';
import 'package:pashmak_app/features/shop/domain/shop_service.dart';
import 'package:pashmak_app/features/wallet/domain/wallet_service.dart';

import 'core_loop_helpers.dart';

DateTime at(int d, [int h = 10, int m = 0]) => DateTime(2026, 10, d, h, m);

Future<String> goal(Loop l, String key, {String? title}) => l.habits.create(HabitDraft(templateKey: key, title: title, areaKey: 'calm', source: 'tab'));

void main() {
  group('goals', () {
    test('a goal stores its library fields and a once-goal only shows on its due day', () async {
      final l = Loop(at(5));
      final id = await l.habits.create(HabitDraft(templateKey: 'home_drawer_one', areaKey: 'home', repeatType: 'once', dueDay: l.today().addDays(1).value));
      final h = (await l.habits.byId(id))!;
      expect((h.goalKey, h.templateKey, h.areaKey, h.repeatType), ('home_drawer_one', 'home_drawer_one', 'home', 'once'));
      expect(HabitService.scheduledOn(h, l.today()), isFalse);
      expect(HabitService.scheduledOn(h, l.today().addDays(1)), isTrue);
      expect(HabitService.scheduledOn(h, l.today().addDays(2)), isFalse);
    });

    test('completing a goal grants economy.energy_per_goal (5)', () async {
      final l = Loop(at(5));
      final id = await goal(l, 'calm_five_breaths');
      expect((await l.habits.complete(id)).energyGranted, 5);
    });
  });

  group('automatic adventure (daily energy target)', () {
    Future<void> tick4(Loop l) async {
      for (final k in ['calm_five_breaths', 'calm_tea_slow', 'home_bed_make', 'food_water_glass']) {
        await l.habits.complete(await goal(l, k));
      }
    }

    test('4 goals × 5 energy fills the bar and starts today\'s adventure once; the second one waits for tomorrow', () async {
      final l = Loop(at(5));
      expect(await l.adventures.maybeAutoStart(isPremium: false), isNull, reason: 'bar not full');
      await tick4(l);
      expect((await l.wallet.balance()).energy, 20);
      final r = await l.adventures.maybeAutoStart(isPremium: false);
      expect(r, isNotNull);
      expect(r!.status, StartStatus.started);
      expect((await l.wallet.balance()).energy, 0, reason: 'the target is spent');
      // refill the same day: no second adventure
      await l.wallet.grant(Currency.energy, 30, 'promo', 'p1');
      expect(await l.adventures.maybeAutoStart(isPremium: false), isNull);
    });

    test('locations rotate through the unlocked ones and premium ones are skipped for free users', () async {
      final l = Loop(at(5));
      final seen = <String>[];
      for (var day = 5; day < 11; day++) {
        l.clock.set(at(day));
        await l.wallet.grant(Currency.energy, 20, 'promo', 'e$day');
        final r = await l.adventures.maybeAutoStart(isPremium: false);
        expect(r, isNotNull, reason: 'day $day');
        seen.add(r!.adventure!.locationKey);
        l.clock.advance(const Duration(hours: 5));
        await l.adventures.claim(r.adventure!.id);
      }
      expect(seen.toSet().every(l.config.freeAdventureLocations.contains), isTrue);
      expect(seen.take(3).toSet().length, 3, reason: 'a different place each time');
    });

    test('claim gives coins and one new discovery; the collection fills without repeats', () async {
      final l = Loop(at(5));
      final found = <String>{};
      for (var day = 5; day < 12; day++) {
        l.clock.set(at(day));
        await l.wallet.grant(Currency.energy, 20, 'promo', 'e$day');
        final r = (await l.adventures.maybeAutoStart(isPremium: true))!;
        l.clock.advance(const Duration(hours: 6));
        final c = (await l.adventures.claim(r.adventure!.id))!;
        expect(c.discoveryKey, isNotNull);
        expect(found.add(c.discoveryKey!), isTrue, reason: 'never the same discovery twice');
        expect(c.stageUp, day == 11 ? CatStage.young : isNull, reason: '7th adventure grows the cat');
      }
      expect((await l.db.select(l.db.discoveriesFound).get()).length, 7);
    });
  });

  group('quests', () {
    test('first daily quest is the claim; ticking goals moves progress; claiming pays once', () async {
      final l = Loop(at(5));
      var daily = await l.quests.daily();
      expect(daily.first.def.key, 'daily_claim');
      expect(daily.first.state, QuestState.ready);
      final c1 = await l.quests.claim('daily_claim', special: false);
      expect((c1.status, c1.coins), (ClaimStatus.claimed, l.config.questsDailyRewardCoins));
      expect((await l.quests.claim('daily_claim', special: false)).status, ClaimStatus.alreadyClaimed);
      expect((await l.wallet.balance()).coins, l.config.questsDailyRewardCoins);
      daily = await l.quests.daily();
      expect(daily.first.state, QuestState.claimed);
      expect(daily.length, l.config.questsDailyCount);
    });

    test('the day\'s quests change with the day and not within it', () async {
      final l = Loop(at(5));
      final a = (await l.quests.daily()).map((v) => v.def.key).toList();
      expect((await l.quests.daily()).map((v) => v.def.key).toList(), a);
      l.clock.set(at(6));
      expect((await l.quests.daily()).map((v) => v.def.key).toList(), isNot(a));
    });

    test('special quests: first discovery / outfit become ready from local data', () async {
      final l = Loop(at(5));
      var sp = {for (final v in await l.quests.special()) v.def.key: v};
      expect(sp['first_outfit']!.state, QuestState.inProgress);
      await l.wallet.grant(Currency.coins, 500, 'promo', 'c');
      expect(await l.shop.buy('collar_turquoise', isPremium: false), BuyStatus.bought);
      sp = {for (final v in await l.quests.special()) v.def.key: v};
      expect(sp['first_outfit']!.state, QuestState.ready);
      final c = await l.quests.claim('first_outfit', special: true);
      expect(c.status, ClaimStatus.claimed);
      expect((await l.quests.claim('first_outfit', special: true)).status, ClaimStatus.alreadyClaimed);
    });

    test('reflection answers stay local and complete the reflection quest metric', () async {
      final l = Loop(at(5));
      expect((await l.quests.metrics())['reflection_today'], 0);
      await l.quests.answerReflection('a');
      expect((await l.quests.metrics())['reflection_today'], 1);
    });

    test('rest mode: no daily quests are generated', () async {
      final l = Loop(at(5));
      await l.pause.set(true);
      expect(await l.quests.daily(), isEmpty);
    });
  });

  group('shop rotation, refresh and selling', () {
    test('six items per shop, stable within the day, different the next day', () async {
      final l = Loop(at(5));
      final a = (await l.shop.stock('outfit')).map((i) => i.itemKey).toList();
      expect(a.length, lessThanOrEqualTo(l.config.shopRotationSize));
      expect((await l.shop.stock('outfit')).map((i) => i.itemKey).toList(), a);
      l.clock.set(at(6));
      expect((await l.shop.stock('outfit')).map((i) => i.itemKey).toList(), isNot(a));
      expect(l.shop.permanent('outfit').every((i) => i.alwaysAvailable), isTrue);
    });

    test('a paid refresh costs coins, changes the stock and refuses without funds', () async {
      final l = Loop(at(5));
      final a = (await l.shop.stock('furniture')).map((i) => i.itemKey).toList();
      expect(await l.shop.refresh('furniture'), RefreshStatus.notEnoughCoins);
      await l.wallet.grant(Currency.coins, 100, 'promo', 'c');
      expect(await l.shop.refresh('furniture'), RefreshStatus.refreshed);
      expect((await l.wallet.balance()).coins, 100 - l.config.shopRefreshCost);
      expect((await l.shop.stock('furniture')).map((i) => i.itemKey).toList(), isNot(a));
    });

    test('selling pays half, removes the item, and a worn item cannot be sold', () async {
      final l = Loop(at(5));
      await l.wallet.grant(Currency.coins, 500, 'promo', 'c');
      await l.shop.buy('hat_beanie', isPremium: false); // 120
      await l.shop.toggleEquip('hat_beanie', isPremium: false);
      expect(await l.shop.sell('hat_beanie'), SellStatus.equipped);
      await l.shop.toggleEquip('hat_beanie', isPremium: false);
      final before = (await l.wallet.balance()).coins;
      expect(await l.shop.sell('hat_beanie'), SellStatus.sold);
      expect((await l.wallet.balance()).coins - before, 60);
      expect(await l.shop.sell('hat_beanie'), SellStatus.notOwned);
      // buy + sell again works (new ledger ref per acquisition)
      l.clock.advance(const Duration(minutes: 1));
      await l.shop.buy('hat_beanie', isPremium: false);
      expect(await l.shop.sell('hat_beanie'), SellStatus.sold);
    });
  });

  group('rest mode', () {
    test('streak is frozen while resting and continues from the same point afterwards', () async {
      final l = Loop(at(5));
      await l.habits.complete(await goal(l, 'calm_five_breaths'));
      await l.habits.complete(await goal(l, 'calm_tea_slow'));
      expect((await l.streak.snapshot()).current, 1);
      await l.pause.set(true);
      l.clock.set(at(9)); // 4 days away
      await l.streak.evaluate(l.today());
      expect((await l.streak.snapshot()).current, 1, reason: 'no reset');
      expect((await l.streak.snapshot()).freezesLeft, l.config.streakFreezesPerMonth, reason: 'no freeze spent');
      await l.pause.set(false);
      await l.streak.evaluate(l.today());
      final id = await goal(l, 'home_bed_make');
      await l.habits.complete(id);
      expect((await l.streak.snapshot()).current, 2, reason: 'continues instead of restarting');
    });

    test('the planner only keeps trial notifications while resting', () {
      const settings = PlannerSettings(enabled: {'morning': true, 'evening_checkin': true, 'trial': true, 'habit_reminder': true});
      final input = PlanInput(
        now: DateTime(2026, 10, 5, 8),
        settings: settings,
        trial: PlanTrial(active: true, startedAt: DateTime(2026, 10, 1), purchased: false),
        habits: const [PlanHabit(id: 'h', reminderMinutes: 600, scheduleType: 'daily', weekdaysMask: 127)],
        paused: true,
      );
      final plan = planNotifications(input);
      expect(plan, isNotEmpty);
      expect(plan.every((p) => p.type == 'trial'), isTrue);
      expect(planNotifications(PlanInput(now: input.now, settings: settings, habits: input.habits)).any((p) => p.type == 'morning'), isTrue);
    });

    test('once goals only remind on their due day', () {
      const settings = PlannerSettings(enabled: {'habit_reminder': true});
      final due = LocalDay.fromDate(DateTime(2026, 10, 7)).value;
      final plan = planNotifications(PlanInput(
        now: DateTime(2026, 10, 5, 8),
        settings: settings,
        habits: [PlanHabit(id: 'h', reminderMinutes: 600, scheduleType: 'daily', weekdaysMask: 127, repeatType: 'once', dueDay: due)],
      ));
      expect(plan.length, 1);
      expect(plan.single.day, due);
    });
  });
}
