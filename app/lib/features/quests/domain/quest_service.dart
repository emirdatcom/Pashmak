import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import '../../../core/widget_snapshot.dart';
import '../../wallet/domain/wallet_service.dart';
import '../../shop/domain/shop_service.dart' show ShopItem;
import 'quest_engine.dart';

enum ClaimStatus { claimed, notReady, alreadyClaimed, unknown }

class QuestClaim {
  const QuestClaim(this.status, {this.coins = 0});
  final ClaimStatus status;
  final int coins;
}

/// Daily and special quests on local data (docs/22 §10). Progress is derived from the existing tables, only the
/// day's chosen quests, the claims and the reflection answer are stored.
class QuestService {
  QuestService(
    this._db,
    this._clock,
    this._wallet,
    this._analytics,
    this._publisher, {
    required this.today,
    required this.dayStart,
    required this.dailyPool,
    required this.specialPool,
    required this.dailyCount,
    required this.dailyRewardCoins,
    required this.seed,
    this.engine = const QuestEngine(),
  });

  final AppDatabase _db;
  final Clock _clock;
  final WalletService _wallet;
  final AnalyticsService _analytics;
  final WidgetSnapshotPublisher _publisher;
  final String Function() today; // LocalDay.value
  final DateTime Function() dayStart; // start instant of the current local day
  final List<QuestDef> Function() dailyPool;
  final List<QuestDef> Function() specialPool;
  final int Function() dailyCount;
  final int Function() dailyRewardCoins;
  final Future<int> Function() seed; // stable per install
  final QuestEngine engine;

  Future<bool> _paused() async => await _db.setting('pause_mode') == 'true';

  /// Today's row, created on first use (none while rest mode is on).
  Future<QuestDailyStateData?> _ensureToday() async {
    final day = today();
    final row = await (_db.select(_db.questDailyState)..where((t) => t.localDay.equals(day))).getSingleOrNull();
    if (row != null) return row;
    if (await _paused()) return null;
    final keys = engine.selectDaily(dailyPool(), count: dailyCount(), localDay: day, seed: await seed());
    await _db.into(_db.questDailyState).insert(QuestDailyStateCompanion.insert(localDay: day, questKeys: jsonEncode(keys)), mode: InsertMode.insertOrIgnore);
    return (_db.select(_db.questDailyState)..where((t) => t.localDay.equals(day))).getSingle();
  }

  Future<int> _count(TableInfo t, Expression<bool> Function() where) async {
    final c = countAll();
    final q = _db.selectOnly(t)..addColumns([c])..where(where());
    return (await q.map((r) => r.read(c) ?? 0).getSingle());
  }

  /// Every metric a quest can refer to (docs/40 `quests_*` packs).
  Future<Map<String, int>> metrics() async {
    final day = today();
    final startMs = dayStart().millisecondsSinceEpoch;
    final row = await (_db.select(_db.questDailyState)..where((t) => t.localDay.equals(day))).getSingleOrNull();
    final ledger = await (_db.select(_db.walletLedger)
          ..where((l) => l.currency.equals('energy') & l.delta.isBiggerThanValue(0) & l.createdAt.isBiggerOrEqualValue(startMs) & l.reason.isIn(const ['habit_done', 'checkin', 'exercise_done'])))
        .get();
    // Energy an undo took back (`adjust` / `undo:<ledger id>`) does not count toward today's energy.
    final undone = ledger.isEmpty
        ? const <String>{}
        : {
            for (final a in await (_db.select(_db.walletLedger)..where((l) => l.reason.equals('adjust') & l.refId.isIn([for (final l in ledger) 'undo:${l.id}']))).get())
              a.refId.substring('undo:'.length),
          };
    // A goal counts as done once its log reaches the goal's times per day.
    final logs = await (_db.select(_db.habitLogs).join([innerJoin(_db.habits, _db.habits.id.equalsExp(_db.habitLogs.habitId))])
          ..where(_db.habitLogs.deletedAt.isNull() & _db.habitLogs.count.isBiggerOrEqual(_db.habits.targetPerDay)))
        .get();
    final doneLogs = [for (final r in logs) r.readTable(_db.habitLogs)];
    final adventures = await _db.select(_db.adventures).get();
    final claimed = adventures.where((a) => a.status == 'claimed');
    final owned = await _db.select(_db.inventory).get();
    final streak = await _db.select(_db.streakState).getSingle();
    return {
      'checkin_today': await _count(_db.checkins, () => _db.checkins.localDay.equals(day) & _db.checkins.deletedAt.isNull()),
      'exercise_today': await _count(_db.exerciseSessions, () => _db.exerciseSessions.localDay.equals(day) & _db.exerciseSessions.completedAt.isNotNull()),
      'goals_done_today': doneLogs.where((l) => l.localDay == day).length,
      'reflection_today': row?.reflectionAnswer == null ? 0 : 1,
      'energy_today': ledger.where((l) => !undone.contains(l.id)).fold<int>(0, (a, l) => a + l.delta),
      'shop_visit_today': await _db.meta('visit:shop:$day') == '1' ? 1 : 0,
      'cat_visit_today': await _db.meta('visit:cat:$day') == '1' ? 1 : 0,
      'adventures_count': claimed.length,
      'owned_outfit': owned.where((i) => ShopItem.outfitSlots.contains(i.slot)).length,
      'owned_furniture': owned.where((i) => i.slot.startsWith('room_') || i.slot == 'background').length,
      'locations_visited': adventures.map((a) => a.locationKey).toSet().length,
      'streak_days': streak.current,
      'discoveries_count': (await _db.select(_db.discoveriesFound).get()).length,
      'goals_done_total': doneLogs.length,
    };
  }

  Future<List<QuestView>> daily() async {
    final row = await _ensureToday();
    if (row == null) return const [];
    final pool = {for (final q in dailyPool()) q.key: q};
    final claimed = (jsonDecode(row.claimed) as List).cast<String>().toSet();
    final m = await metrics();
    return [
      for (final k in (jsonDecode(row.questKeys) as List).cast<String>())
        if (pool[k] != null) engine.evaluate(pool[k]!, m, claimed: claimed.contains(k)),
    ];
  }

  Future<List<QuestView>> special() async {
    final claimed = {for (final r in await (_db.select(_db.questProgress)..where((t) => t.claimedAt.isNotNull())).get()) r.questKey};
    final m = await metrics();
    return [for (final q in specialPool()) engine.evaluate(q, m, claimed: claimed.contains(q.key))];
  }

  /// Claims a ready quest once: idempotent through the ledger (`quest_reward`, ref `daily:<day>:<key>` / `special:<key>`).
  Future<QuestClaim> claim(String questKey, {required bool special}) async {
    final views = special ? await this.special() : await daily();
    final v = views.where((x) => x.def.key == questKey).firstOrNull;
    if (v == null) return const QuestClaim(ClaimStatus.unknown);
    if (v.state == QuestState.claimed) return const QuestClaim(ClaimStatus.alreadyClaimed);
    if (v.state != QuestState.ready) return const QuestClaim(ClaimStatus.notReady);
    final coins = v.def.rewardCoins ?? dailyRewardCoins();
    final day = today();
    await _db.transaction(() async {
      await _wallet.grant(Currency.coins, coins, 'quest_reward', special ? 'special:$questKey' : 'daily:$day:$questKey');
      if (special) {
        await _db.into(_db.questProgress).insertOnConflictUpdate(QuestProgressCompanion.insert(questKey: questKey, claimedAt: Value(_clock.now().millisecondsSinceEpoch)));
      } else {
        final row = await (_db.select(_db.questDailyState)..where((t) => t.localDay.equals(day))).getSingle();
        final list = (jsonDecode(row.claimed) as List).cast<String>().toSet()..add(questKey);
        await (_db.update(_db.questDailyState)..where((t) => t.localDay.equals(day))).write(QuestDailyStateCompanion(claimed: Value(jsonEncode(list.toList()))));
      }
    });
    await _analytics.track(AnalyticsEvent.questClaimed, {'quest_key': questKey, 'kind': special ? 'special' : 'daily'});
    await _publisher.refresh();
    return QuestClaim(ClaimStatus.claimed, coins: coins);
  }

  /// "Visited" flags for `shop_visit_today` / `cat_visit_today`.
  Future<void> recordVisit(String kind) => _db.setMeta('visit:$kind:${today()}', '1');

  /// The two-option reflective prompt of the day. The answer stays on the device (never synced, never tracked).
  Future<void> answerReflection(String answer) async {
    await _ensureToday();
    await (_db.update(_db.questDailyState)..where((t) => t.localDay.equals(today()))).write(QuestDailyStateCompanion(reflectionAnswer: Value(answer)));
  }
}
