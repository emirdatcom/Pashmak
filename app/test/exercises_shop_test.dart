import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/features/exercises/domain/exercise_runner.dart';
import 'package:pashmak_app/features/shop/domain/shop_service.dart';
import 'package:pashmak_app/features/wallet/domain/wallet_service.dart';

import 'core_loop_helpers.dart';

DateTime at(int d, [int h = 10, int m = 0]) => DateTime(2026, 10, d, h, m);

void main() {
  group('exercise runner', () {
    test('expands repeated groups (inhale/hold/exhale x6) and totals the real pack', () {
      final l = Loop(at(5));
      final pack = l.exercisePack.firstWhere((e) => e['key'] == 'breathing_basic');
      final phases = expandSteps((pack['steps'] as List).cast<Map<String, dynamic>>());
      expect(phases.length, 1 + 6 * 3 + 1);
      expect(phases.map((p) => p.animation).skip(1).take(3), ['inhale', 'hold', 'exhale']);
      expect(phases.fold<int>(0, (a, p) => a + p.seconds), 6 + 6 * 14 + 5);
    });

    test('timeline follows timestamps, supports pause/resume and finishes', () {
      final r = ExerciseRunner(const [
        ExercisePhase(textKey: 'a', seconds: 4, animation: 'inhale'),
        ExercisePhase(textKey: 'b', seconds: 6, animation: 'exhale'),
      ]);
      final t0 = at(5);
      expect(r.snapshot(t0).phaseIndex, 0);
      r.start(t0);
      var s = r.snapshot(t0.add(const Duration(seconds: 3)));
      expect((s.phaseIndex, s.remainingInPhase.round(), s.finished), (0, 1, false));
      r.pause(t0.add(const Duration(seconds: 3)));
      s = r.snapshot(t0.add(const Duration(minutes: 5)));
      expect(s.elapsedSeconds, closeTo(3, 0.01), reason: 'time stands still while paused');
      r.resume(t0.add(const Duration(minutes: 5)));
      s = r.snapshot(t0.add(const Duration(minutes: 5, seconds: 2)));
      expect((s.phaseIndex, s.remainingInPhase.round()), (1, 5));
      s = r.snapshot(t0.add(const Duration(minutes: 5, seconds: 7)));
      expect(s.finished, isTrue);
    });
  });

  group('ExerciseService', () {
    test('config decides the locks (free_exercises is the single source of truth)', () {
      final l = Loop(at(5));
      expect(l.exercises.isLocked('breathing_basic', isPremium: false), isFalse);
      expect(l.exercises.isLocked('gratitude', isPremium: false), isTrue);
      expect(l.exercises.isLocked('gratitude', isPremium: true), isFalse);
      final changed = Loop(at(5));
      changed.config.raw['limits']['free_exercises'] = ['breathing_basic', 'gratitude'];
      expect(changed.exercises.isLocked('gratitude', isPremium: false), isFalse, reason: 'remote config unlocks it without an app release');
    });

    test('completion grants energy up to 3 rewards a day; the 4th is recorded without energy', () async {
      final l = Loop(at(5));
      for (var i = 1; i <= 4; i++) {
        final id = await l.exercises.start('breathing_basic');
        final r = await l.exercises.complete(id, durationS: 95);
        expect(r.rewarded, i <= 3, reason: 'session $i');
      }
      expect((await l.wallet.balance()).energy, 30);
      final done = await (l.db.select(l.db.exerciseSessions)..where((s) => s.completedAt.isNotNull())).get();
      expect(done.length, 4);
      expect((await l.streak.snapshot()).current, 1, reason: 'a finished exercise is an active day');
      // next day the allowance is back
      l.clock.set(at(6));
      final id = await l.exercises.start('breathing_basic');
      expect((await l.exercises.complete(id, durationS: 95)).rewarded, isTrue);
    });

    test('leaving early keeps completed_at empty and gives nothing; completing twice is a no-op', () async {
      final l = Loop(at(5));
      final id = await l.exercises.start('breathing_basic');
      var s = await (l.db.select(l.db.exerciseSessions)..where((x) => x.id.equals(id))).getSingle();
      expect(s.completedAt, isNull);
      expect((await l.wallet.balance()).energy, 0);
      await l.exercises.complete(id, durationS: 60);
      expect((await l.exercises.complete(id, durationS: 60)).rewarded, isFalse);
      s = await (l.db.select(l.db.exerciseSessions)..where((x) => x.id.equals(id))).getSingle();
      expect(s.completedAt, isNotNull);
    });

    test('journal text is stored locally and never reaches analytics', () async {
      final l = Loop(at(5));
      final id = await l.exercises.start('gratitude');
      await l.exercises.complete(id, durationS: 120, journalText: '  امروز ممنونم از مادرم  ');
      final s = await (l.db.select(l.db.exerciseSessions)).getSingle();
      expect(s.journalText, 'امروز ممنونم از مادرم');
      final q = (await l.db.select(l.db.analyticsQueue).get()).map((r) => '${r.name} ${r.props}').join('\n');
      expect(q, contains('exercise_completed'));
      expect(q, isNot(contains('ممنونم')));
      expect(q, isNot(contains('journal')));
    });
  });

  group('ShopService', () {
    Future<Loop> rich([int coins = 1000]) async {
      final l = Loop(at(5));
      await l.wallet.grant(Currency.coins, coins, 'promo', 'seed');
      return l;
    }

    test('buy deducts coins and adds to inventory once; second buy is alreadyOwned', () async {
      final l = await rich();
      expect(await l.shop.buy('collar_turquoise', isPremium: false), BuyStatus.bought);
      expect((await l.wallet.balance()).coins, 940);
      expect((await l.db.select(l.db.inventory).getSingle()).slot, 'collar');
      expect(await l.shop.buy('collar_turquoise', isPremium: false), BuyStatus.alreadyOwned);
      expect((await l.wallet.balance()).coins, 940);
      final ledger = await (l.db.select(l.db.walletLedger)..where((x) => x.reason.equals('shop_purchase'))).get();
      expect(ledger.single.refId, startsWith('collar_turquoise:'), reason: 'unique per purchase so an item can be bought again after selling it');
    });

    test('not enough coins changes nothing; premium-only items need premium; unknown item', () async {
      final l = await rich(50);
      expect(await l.shop.buy('hat_beanie', isPremium: false), BuyStatus.notEnoughCoins);
      expect(await l.db.select(l.db.inventory).get(), isEmpty);
      expect((await l.wallet.balance()).coins, 50);
      final rich2 = await rich();
      expect(await rich2.shop.buy('bg_garden_spring', isPremium: false), BuyStatus.premiumRequired);
      expect(await rich2.shop.buy('bg_garden_spring', isPremium: true), BuyStatus.bought);
      expect(await rich2.shop.buy('nope', isPremium: true), BuyStatus.unknownItem);
    });

    test('one equipped item per slot; unequip toggles; not owned', () async {
      final l = await rich();
      await l.shop.buy('collar_turquoise', isPremium: false);
      await l.shop.buy('collar_red', isPremium: false);
      expect(await l.shop.toggleEquip('collar_turquoise', isPremium: false), EquipStatus.equipped);
      expect(await l.shop.toggleEquip('collar_red', isPremium: false), EquipStatus.equipped);
      final eq = (await l.db.select(l.db.inventory).get()).where((i) => i.equipped).map((i) => i.itemKey).toList();
      expect(eq, ['collar_red']);
      expect(await l.shop.toggleEquip('collar_red', isPremium: false), EquipStatus.unequipped);
      expect(await l.shop.toggleEquip('hat_beanie', isPremium: false), EquipStatus.notOwned);
    });

    test('premium items stay equipped after expiry, but a new premium equip is locked', () async {
      final l = await rich();
      await l.shop.buy('pillow_cozy', isPremium: true);
      await l.shop.buy('bg_garden_spring', isPremium: true);
      expect(await l.shop.toggleEquip('pillow_cozy', isPremium: true), EquipStatus.equipped);
      // subscription ends: the equipped pillow is still there…
      expect((await l.db.select(l.db.inventory).get()).firstWhere((i) => i.itemKey == 'pillow_cozy').equipped, isTrue);
      // …but equipping the other premium item is locked
      expect(await l.shop.toggleEquip('bg_garden_spring', isPremium: false), EquipStatus.premiumLocked);
      // unequipping is always possible
      expect(await l.shop.toggleEquip('pillow_cozy', isPremium: false), EquipStatus.unequipped);
    });

    test('items are grouped into cat / room / background tabs', () async {
      final l = await rich();
      expect(l.shop.item('collar_red')!.tab, 'cat');
      expect(l.shop.item('samovar')!.tab, 'room');
      expect(l.shop.item('bg_alley_evening')!.tab, 'background');
    });
  });
}
