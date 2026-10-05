import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/features/cat/domain/cat_growth.dart';
import 'package:pashmak_app/features/quests/domain/quest_engine.dart';
import 'package:pashmak_app/features/shop/domain/shop_rotation.dart';

QuestDef q(String k, String m, int t, {bool fixed = false}) => QuestDef(key: k, titleKey: 't', metric: m, target: t, route: '/home', fixed: fixed);

void main() {
  group('QuestEngine', () {
    const e = QuestEngine();
    final pool = [q('daily_claim', 'claim', 1, fixed: true), for (var i = 0; i < 8; i++) q('q$i', 'goals_done_today', i + 1)];

    test('first quest is the fixed claim, others are deterministic per day', () {
      final a = e.selectDaily(pool, count: 4, localDay: '2026-10-05', seed: 7);
      expect(a.first, 'daily_claim');
      expect(a.length, 4);
      expect(e.selectDaily(pool, count: 4, localDay: '2026-10-05', seed: 7), a);
      expect(e.selectDaily(pool, count: 4, localDay: '2026-10-06', seed: 7), isNot(a));
    });

    test('pause mode generates no daily quests', () {
      expect(e.selectDaily(pool, count: 4, localDay: 'x', seed: 1, paused: true), isEmpty);
    });

    test('states: in progress → ready → claimed (and claim is never re-doable)', () {
      final d = q('tick_three', 'goals_done_today', 3);
      expect(e.evaluate(d, {'goals_done_today': 2}, claimed: false).state, QuestState.inProgress);
      expect(e.evaluate(d, {'goals_done_today': 3}, claimed: false).state, QuestState.ready);
      expect(e.evaluate(d, {'goals_done_today': 9}, claimed: false).shown, 3);
      expect(e.evaluate(d, {'goals_done_today': 3}, claimed: true).state, QuestState.claimed);
    });

    test('claim metric is ready immediately', () {
      expect(e.evaluate(q('daily_claim', 'claim', 1), {}, claimed: false).state, QuestState.ready);
    });

    test('special metrics', () {
      final s = q('grow_young', 'adventures_count', 7);
      expect(e.evaluate(s, {'adventures_count': 6}, claimed: false).state, QuestState.inProgress);
      expect(e.evaluate(s, {'adventures_count': 7}, claimed: false).state, QuestState.ready);
    });
  });

  group('ShopRotation', () {
    const r = ShopRotation();
    final items = [for (var i = 0; i < 20; i++) 'item$i'];
    List<String> day(String d, {int refresh = 0}) => r.pick(items, size: 6, installId: 'inst', localDay: d, shop: 'outfit', refreshCount: refresh);

    test('stable within a day, different next day', () {
      expect(day('2026-10-05'), day('2026-10-05'));
      expect(day('2026-10-05'), hasLength(6));
      expect(day('2026-10-06'), isNot(day('2026-10-05')));
    });

    test('a refresh changes the stock', () {
      expect(day('2026-10-05', refresh: 1), isNot(day('2026-10-05')));
    });

    test('small pool returns everything', () {
      expect(r.pick(['a', 'b'], size: 6, installId: 'i', localDay: 'd', shop: 's'), hasLength(2));
    });

    test('sell price rounds down', () {
      expect(r.sellPrice(121, 0.5), 60);
    });

    test('countdown never negative', () {
      final now = DateTime(2026, 10, 5, 10);
      expect(r.untilRefresh(now, DateTime(2026, 10, 6, 4)), const Duration(hours: 18));
      expect(r.untilRefresh(now, DateTime(2026, 10, 5, 4)), Duration.zero);
    });
  });

  group('CatGrowth', () {
    const g = CatGrowth(young: 7, adult: 30);
    test('stages', () {
      expect(g.stageFor(0), CatStage.kitten);
      expect(g.stageFor(6), CatStage.kitten);
      expect(g.stageFor(7), CatStage.young);
      expect(g.stageFor(30), CatStage.adult);
    });
    test('upgrade only when the stage changes', () {
      expect(g.upgrade(6, 7), CatStage.young);
      expect(g.upgrade(7, 8), isNull);
      expect(g.upgrade(29, 30), CatStage.adult);
    });
  });
}
