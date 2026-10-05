import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/core_loop_providers.dart';
import '../../features/habits/domain/habit_service.dart';
import '../../features/wallet/domain/wallet_service.dart';
import '../db/app_database.dart';
import '../providers.dart';

/// `--dart-define=DEMO_SEED=true` fills a debug build with showcase data (coins, goals, an adventure, discoveries, quests).
const bool kDemoSeedFlag = bool.fromEnvironment('DEMO_SEED');

/// The seed never runs in a release build, whatever the flag says (checked in test/demo_seed_test.dart).
bool demoSeedActive({bool flag = kDemoSeedFlag, bool release = kReleaseMode}) => flag && !release;

/// Reference state of the visual comparison (prompt 23 §1): 3 quests done + 1 open, one goal left today with an adventure
/// card, 302 coins, a few discoveries. Idempotent: running it twice does not double anything.
Future<void> applyDemoSeed(ProviderContainer c, {int coins = 302}) async {
  final db = c.read(databaseProvider);
  final habits = c.read(habitServiceProvider);
  final now = c.read(clockProvider).now();

  if ((await habits.activeHabits()).isEmpty) {
    const drafts = [
      HabitDraft(templateKey: 'water', areaKey: 'nutrition', timeOfDay: 'morning'),
      HabitDraft(templateKey: 'sleep', areaKey: 'sleep', timeOfDay: 'evening'),
      HabitDraft(templateKey: 'walk', areaKey: 'movement', timeOfDay: 'afternoon'),
      HabitDraft(templateKey: 'short_break', areaKey: 'calm', timeOfDay: 'any'),
    ];
    final ids = [for (final d in drafts) await habits.create(d)];
    for (final id in ids.take(ids.length - 1)) {
      await habits.complete(id);
    }
  }

  final wallet = c.read(walletServiceProvider);
  final have = (await wallet.balance()).coins;
  if (have < coins) await wallet.grant(Currency.coins, coins - have, 'demo_seed', 'coins');

  if (await db.select(db.adventures).get().then((r) => r.isEmpty)) {
    final id = 'demo-adventure';
    final opts = c.read(adventureServiceProvider).options();
    await db.into(db.adventures).insert(AdventuresCompanion.insert(
          id: id,
          locationKey: opts.isEmpty ? 'alley' : opts.first.locationKey,
          energyCost: 0,
          startedAt: now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
          endsAt: now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
          status: const Value('returned'),
          rewardCoins: const Value(20),
        ));
  }

  final discoveries = c.read(contentRepositoryProvider).entries('discoveries');
  final keys = (discoveries as List? ?? const []).whereType<Map>().map((d) => '${d['key']}').take(6);
  for (final k in keys) {
    await db.into(db.discoveriesFound).insert(DiscoveriesFoundCompanion.insert(discoveryKey: k, foundAt: now.millisecondsSinceEpoch), mode: InsertMode.insertOrIgnore);
  }

  final quests = c.read(questServiceProvider);
  final daily = await quests.daily();
  if (daily.length > 1) {
    final day = c.read(todayProvider).value;
    final done = [for (final q in daily.take(daily.length - 1)) q.def.key];
    await (db.update(db.questDailyState)..where((t) => t.localDay.equals(day))).write(QuestDailyStateCompanion(claimed: Value(jsonEncode(done))));
  }
}
