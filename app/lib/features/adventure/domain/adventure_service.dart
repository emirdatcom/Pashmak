import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/content/copy_resolver.dart';
import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import '../../../core/widget_snapshot.dart';
import '../../cat/domain/cat_growth.dart';
import '../../wallet/domain/wallet_service.dart';

enum StartStatus { started, premiumRequired, notEnoughEnergy, alreadyActive, unknownLocation }

class StartResult {
  const StartResult(this.status, {this.adventure});
  final StartStatus status;
  final Adventure? adventure;
}

class ClaimResult {
  const ClaimResult({required this.coins, this.itemKey, this.storyKey, this.discoveryKey, this.stageUp});
  final int coins;
  final String? itemKey;
  final String? storyKey;
  final String? discoveryKey; // a new entry of the discoveries collection
  final CatStage? stageUp; // set when this adventure made the cat grow
}

/// A location the user can pick: content (names, stories) + config numbers.
class AdventureOption {
  const AdventureOption({required this.locationKey, required this.nameKey, required this.config, required this.premium});
  final String locationKey;
  final String nameKey;
  final AdventureLocationConfig config;
  final bool premium;
}

/// Reward decided at start time (docs/30 §4: seed = hash(adventure.id), so killing the app cannot re-roll).
class AdventureReward {
  const AdventureReward({required this.coins, this.itemKey, required this.storyKey});
  final int coins;
  final String? itemKey;
  final String storyKey;
}

class AdventureService {
  AdventureService(
    this._db,
    this._clock,
    this._wallet,
    this._analytics,
    this._publisher, {
    required this.configs,
    required this.adventuresPack,
    required this.shopItems,
    required this.freeLocations,
    required this.dailyEnergyTarget,
    required this.discoveries,
    required this.growth,
    required this.today,
  });

  final AppDatabase _db;
  final Clock _clock;
  final WalletService _wallet;
  final AnalyticsService _analytics;
  final WidgetSnapshotPublisher _publisher;
  final List<AdventureLocationConfig> Function() configs;
  final Map<String, dynamic> Function() adventuresPack; // pack `adventures` entries
  final List<dynamic> Function() shopItems; // pack `shop_items` entries
  final List<String> Function() freeLocations;
  final int Function() dailyEnergyTarget; // `adventure.daily_energy_target`
  final List<Map<String, dynamic>> Function() discoveries; // pack `discoveries` entries
  final CatGrowth Function() growth;
  final String Function() today; // LocalDay.value

  static const _kLastSeen = 'last_seen_wall_ms';
  static const _kLastStartDay = 'adventure_last_start_day';

  /// Mild clock-rollback protection (docs/30 §4): time never moves backwards for adventures.
  Future<DateTime> effectiveNow() async {
    final now = _clock.now();
    final seen = int.tryParse(await _db.meta(_kLastSeen) ?? '') ?? 0;
    return seen > now.millisecondsSinceEpoch ? DateTime.fromMillisecondsSinceEpoch(seen) : now;
  }

  /// Remembers the latest wall-clock time seen (only moves forward).
  Future<void> touch() async {
    final now = _clock.now().millisecondsSinceEpoch;
    final seen = int.tryParse(await _db.meta(_kLastSeen) ?? '') ?? 0;
    if (now > seen) await _db.setMeta(_kLastSeen, '$now');
  }

  List<AdventureOption> options() {
    final names = {for (final l in (adventuresPack()['locations'] as List? ?? const []).cast<Map<String, dynamic>>()) l['location_key'] as String: l['name_key'] as String};
    return [
      for (final c in configs())
        if (names.containsKey(c.locationKey))
          AdventureOption(locationKey: c.locationKey, nameKey: names[c.locationKey]!, config: c, premium: !freeLocations().contains(c.locationKey)),
    ];
  }

  /// Promotes `active` → `returned` once the end time has passed. Returns the unclaimed adventure, if any.
  Future<Adventure?> current() async {
    await touch();
    final now = (await effectiveNow()).millisecondsSinceEpoch;
    await (_db.update(_db.adventures)..where((a) => a.status.equals('active') & a.endsAt.isSmallerOrEqualValue(now))).write(const AdventuresCompanion(status: Value('returned')));
    return (_db.select(_db.adventures)
          ..where((a) => a.status.isIn(['active', 'returned']))
          ..orderBy([(a) => OrderingTerm.desc(a.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<Adventure?> watchCurrent() => (_db.select(_db.adventures)
        ..where((a) => a.status.isIn(['active', 'returned']))
        ..orderBy([(a) => OrderingTerm.desc(a.startedAt)])
        ..limit(1))
      .watchSingleOrNull();

  Future<StartResult> start(String locationKey, {required bool isPremium, int? energyCost}) async {
    final opt = options().where((o) => o.locationKey == locationKey).firstOrNull;
    if (opt == null) return const StartResult(StartStatus.unknownLocation);
    if (opt.premium && !isPremium) return const StartResult(StartStatus.premiumRequired);
    if (await current() != null) return const StartResult(StartStatus.alreadyActive);
    final id = const Uuid().v7();
    final started = await effectiveNow();
    final owned = (await _db.select(_db.inventory).get()).map((e) => e.itemKey).toSet();
    final loc = (adventuresPack()['locations'] as List).cast<Map<String, dynamic>>().firstWhere((l) => l['location_key'] == locationKey);
    final reward = computeReward(id, opt.config, (loc['stories'] as List).cast<Map<String, dynamic>>(), (loc['possible_items'] as List).cast<String>(), owned);
    final ok = await _db.transaction(() async {
      if (!await _wallet.spend(Currency.energy, energyCost ?? opt.config.energyCost, 'adventure_start', id)) return false;
      await _db.into(_db.adventures).insert(AdventuresCompanion.insert(
            id: id,
            locationKey: locationKey,
            energyCost: energyCost ?? opt.config.energyCost,
            startedAt: started.millisecondsSinceEpoch,
            endsAt: started.add(Duration(minutes: opt.config.durationMinutes)).millisecondsSinceEpoch,
            rewardCoins: Value(reward.coins),
            rewardItemKey: Value(reward.itemKey),
            storyKey: Value(reward.storyKey),
          ));
      return true;
    });
    if (!ok) return const StartResult(StartStatus.notEnoughEnergy);
    await _db.setMeta(_kLastStartDay, today());
    await _analytics.track(AnalyticsEvent.adventureStarted, {'location_key': locationKey, 'duration_minutes': opt.config.durationMinutes});
    await _publisher.refresh();
    return StartResult(StartStatus.started, adventure: await (_db.select(_db.adventures)..where((a) => a.id.equals(id))).getSingle());
  }

  /// Locations the user may be sent to, in config order (premium ones only for premium users).
  List<AdventureOption> rotationPool({required bool isPremium}) => [for (final o in options()) if (isPremium || !o.premium) o];

  /// Daily energy bar (docs/22 §9): progress of today's energy toward `adventure.daily_energy_target`.
  /// Returns null when an adventure already started today (the bar then shows the carried-over reserve).
  Future<bool> startedToday() async => await _db.meta(_kLastStartDay) == today();

  /// When the energy balance reaches the daily target, today's adventure starts by itself (at most one a day,
  /// none while another is active/unclaimed). The location rotates through the unlocked ones. Returns the result
  /// when it started, else null.
  Future<StartResult?> maybeAutoStart({required bool isPremium}) async {
    if (await startedToday()) return null;
    final target = dailyEnergyTarget();
    if ((await _wallet.balance()).energy < target) return null;
    if (await current() != null) return null;
    final pool = rotationPool(isPremium: isPremium);
    if (pool.isEmpty) return null;
    final count = (await _db.select(_db.adventures).get()).length;
    final r = await start(pool[count % pool.length].locationKey, isPremium: isPremium, energyCost: target);
    return r.status == StartStatus.started ? r : null;
  }

  /// Deterministic reward for an adventure id. Same id ⇒ same result, on every device and run.
  static AdventureReward computeReward(String adventureId, AdventureLocationConfig cfg, List<Map<String, dynamic>> stories, List<String> possibleItems, Set<String> owned) {
    final rng = Random(CopyResolver.hash(adventureId));
    final coins = cfg.coinsMin + (cfg.coinsMax > cfg.coinsMin ? rng.nextInt(cfg.coinsMax - cfg.coinsMin + 1) : 0);
    final dropRoll = rng.nextDouble();
    final itemPick = rng.nextDouble();
    final candidates = possibleItems.where((i) => !owned.contains(i)).toList();
    final item = (dropRoll < cfg.itemDropRate && candidates.isNotEmpty) ? candidates[(itemPick * candidates.length).floor() % candidates.length] : null;
    final total = stories.fold<int>(0, (a, s) => a + (s['weight'] as int));
    var pos = rng.nextInt(total);
    var story = stories.last['story_key'] as String;
    for (final s in stories) {
      pos -= s['weight'] as int;
      if (pos < 0) {
        story = s['story_key'] as String;
        break;
      }
    }
    return AdventureReward(coins: coins, itemKey: item, storyKey: story);
  }

  Future<ClaimResult?> claim(String adventureId) async {
    await current(); // promote returned
    final before = await _claimedCount();
    final res = await _db.transaction(() async {
      final a = await (_db.select(_db.adventures)..where((x) => x.id.equals(adventureId))).getSingleOrNull();
      if (a == null || a.status != 'returned') return null;
      await _wallet.grant(Currency.coins, a.rewardCoins, 'adventure_reward', a.id);
      final item = a.rewardItemKey;
      if (item != null) {
        final slot = (shopItems().cast<Map<String, dynamic>>().where((s) => s['item_key'] == item).firstOrNull?['slot'] as String?) ?? 'room_floor';
        await _db.into(_db.inventory).insert(InventoryCompanion.insert(itemKey: item, acquiredAt: _clock.now().millisecondsSinceEpoch, source: 'adventure', slot: slot), mode: InsertMode.insertOrIgnore);
      }
      await (_db.update(_db.adventures)..where((x) => x.id.equals(a.id))).write(AdventuresCompanion(status: const Value('claimed'), claimedAt: Value(_clock.now().millisecondsSinceEpoch)));
      final found = await _discover(a.id);
      return ClaimResult(coins: a.rewardCoins, itemKey: item, storyKey: a.storyKey, discoveryKey: found);
    });
    if (res != null) {
      final a = await (_db.select(_db.adventures)..where((x) => x.id.equals(adventureId))).getSingle();
      final up = growth().upgrade(before, before + 1);
      if (up != null) await _analytics.track(AnalyticsEvent.catStageUp, {'stage': up.name});
      final foundKey = res.discoveryKey;
      if (foundKey != null) {
        final cat = discoveries().firstWhere((d) => d['key'] == foundKey, orElse: () => const {'category': 'unknown'})['category'];
        await _analytics.track(AnalyticsEvent.discoveryFound, {'category': '$cat'});
      }
      await _analytics.track(AnalyticsEvent.adventureClaimed, {'location_key': a.locationKey, 'coins': res.coins, 'got_item': res.itemKey != null});
      await _publisher.refresh();
      final out = ClaimResult(coins: res.coins, itemKey: res.itemKey, storyKey: res.storyKey, discoveryKey: res.discoveryKey, stageUp: up);
      await _db.setMeta('adventure_result:$adventureId', jsonEncode({'discovery': out.discoveryKey, 'stage_up': out.stageUp?.name}));
      return out;
    }
    return res;
  }

  Future<int> _claimedCount() async => (await (_db.select(_db.adventures)..where((a) => a.status.equals('claimed'))).get()).length;

  /// A not-yet-found discovery picked deterministically from the adventure id (same id ⇒ same pick for the same
  /// collection state). Null when the collection is complete. Runs inside the claim transaction.
  Future<String?> _discover(String adventureId) async {
    final found = (await _db.select(_db.discoveriesFound).get()).map((r) => r.discoveryKey).toSet();
    final left = [for (final d in discoveries()) if (!found.contains(d['key'])) d['key'] as String]..sort();
    if (left.isEmpty) return null;
    final key = left[CopyResolver.hash('discovery:$adventureId') % left.length];
    await _db.into(_db.discoveriesFound).insert(DiscoveriesFoundCompanion.insert(discoveryKey: key, foundAt: _clock.now().millisecondsSinceEpoch), mode: InsertMode.insertOrIgnore);
    return key;
  }
}

/// What a claimed adventure brought beyond coins/items (kept so the result screen can be reopened).
Future<({String? discovery, String? stageUp})> adventureExtras(AppDatabase db, String adventureId) async {
  final raw = await db.meta('adventure_result:$adventureId');
  if (raw == null) return (discovery: null, stageUp: null);
  final m = jsonDecode(raw) as Map<String, dynamic>;
  return (discovery: m['discovery'] as String?, stageUp: m['stage_up'] as String?);
}
