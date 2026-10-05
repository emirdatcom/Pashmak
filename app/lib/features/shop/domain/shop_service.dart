import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import '../../../core/widget_snapshot.dart';
import '../../wallet/domain/wallet_service.dart';
import 'shop_rotation.dart';

class ShopItem {
  const ShopItem({required this.itemKey, required this.nameKey, required this.slot, required this.priceCoins, required this.premiumOnly, this.seasonalKey, this.alwaysAvailable = false});
  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
      itemKey: j['item_key'] as String, nameKey: j['name_key'] as String, slot: j['slot'] as String, priceCoins: j['price_coins'] as int, premiumOnly: j['premium_only'] as bool, alwaysAvailable: (j['always_available'] as bool?) ?? false);
  final String? seasonalKey;
  final String itemKey;
  final String nameKey;
  final String slot;
  final int priceCoins;
  final bool premiumOnly;
  final bool alwaysAvailable; // "permanent collection": always on offer, never part of the rotation

  /// Shop tab: `cat` (collar, hat), `room` (room_*), `background`.
  /// The two shops of prompt 22: `outfit` (what the cat wears) and `furniture` (the home).
  String get shop => const ['collar', 'hat', 'glasses', 'scarf'].contains(slot) ? 'outfit' : 'furniture';

  String get tab => slot == 'background' ? 'background' : (slot.startsWith('room_') ? 'room' : 'cat');
}

enum BuyStatus { bought, alreadyOwned, notEnoughCoins, premiumRequired, unknownItem, outOfSeason }

enum RefreshStatus { refreshed, notEnoughCoins }

enum SellStatus { sold, notOwned, equipped }

enum EquipStatus { equipped, unequipped, notOwned, premiumLocked }

class ShopService {
  ShopService(this._db, this._clock, this._wallet, this._analytics, this._publisher, {
    required this.items,
    this.isSeasonActive = _always,
    this.today,
    this.installId,
    this.rotationSize,
    this.refreshCost,
    this.sellRatio,
  });

  // Rotating stock (prompt 22). All optional so the plain buy/equip service still works without them.
  final String Function()? today;
  final Future<String> Function()? installId;
  final int Function()? rotationSize;
  final int Function()? refreshCost;
  final double Function()? sellRatio;
  final ShopRotation _rotation = const ShopRotation();

  static bool _always(String _) => true;

  /// Seasonal items can only be bought while their season runs (owned ones stay usable afterwards).
  final bool Function(String seasonalKey) isSeasonActive;

  final AppDatabase _db;
  final Clock _clock;
  final WalletService _wallet;
  final AnalyticsService _analytics;
  final WidgetSnapshotPublisher _publisher;
  final List<ShopItem> Function() items;

  ShopItem? item(String key) => items().where((i) => i.itemKey == key).firstOrNull;

  Stream<List<InventoryData>> watchOwned() => _db.select(_db.inventory).watch();

  /// Pays with coins and adds the item in one transaction. Premium-only items need premium to buy.
  Future<BuyStatus> buy(String itemKey, {required bool isPremium}) async {
    final it = item(itemKey);
    if (it == null) return BuyStatus.unknownItem;
    if ((await (_db.select(_db.inventory)..where((i) => i.itemKey.equals(itemKey))).getSingleOrNull()) != null) return BuyStatus.alreadyOwned;
    if (it.seasonalKey != null && !isSeasonActive(it.seasonalKey!)) return BuyStatus.outOfSeason;
    if (it.premiumOnly && !isPremium) return BuyStatus.premiumRequired;
    final status = await _db.transaction(() async {
      if (!await _wallet.spend(Currency.coins, it.priceCoins, 'shop_purchase', '$itemKey:${_clock.now().millisecondsSinceEpoch}')) return BuyStatus.notEnoughCoins;
      await _db.into(_db.inventory).insert(InventoryCompanion.insert(itemKey: itemKey, acquiredAt: _clock.now().millisecondsSinceEpoch, source: 'shop', slot: it.slot));
      return BuyStatus.bought;
    });
    if (status == BuyStatus.bought) {
      await _analytics.track(AnalyticsEvent.shopItemPurchased, {'item_key': itemKey, 'price_coins': it.priceCoins});
      if (it.seasonalKey != null) await _analytics.track(AnalyticsEvent.seasonalItemPurchased, {'seasonal_key': it.seasonalKey});
    }
    return status;
  }

  /// One item per slot. A premium item the user already has stays equipped after the subscription ends
  /// (docs/60 §7), but equipping a *new* premium item needs premium.
  Future<EquipStatus> toggleEquip(String itemKey, {required bool isPremium}) async {
    final owned = await (_db.select(_db.inventory)..where((i) => i.itemKey.equals(itemKey))).getSingleOrNull();
    if (owned == null) return EquipStatus.notOwned;
    if (owned.equipped) {
      await (_db.update(_db.inventory)..where((i) => i.itemKey.equals(itemKey))).write(const InventoryCompanion(equipped: Value(false)));
      await _publisher.refresh();
      return EquipStatus.unequipped;
    }
    if ((item(itemKey)?.premiumOnly ?? false) && !isPremium) return EquipStatus.premiumLocked;
    await _db.transaction(() async {
      await (_db.update(_db.inventory)..where((i) => i.slot.equals(owned.slot))).write(const InventoryCompanion(equipped: Value(false)));
      await (_db.update(_db.inventory)..where((i) => i.itemKey.equals(itemKey))).write(const InventoryCompanion(equipped: Value(true)));
    });
    await _analytics.track(AnalyticsEvent.itemEquipped, {'item_key': itemKey, 'slot': owned.slot});
    await _publisher.refresh();
    return EquipStatus.equipped;
  }

  // --- rotating stock, refresh and selling (docs/60) ---------------------------------------------------

  /// Today's rotating items of [shop] (`outfit` | `furniture`). Created once per day (and per paid refresh) and
  /// stored, so the stock stays put while the user buys from it.
  Future<List<ShopItem>> stock(String shop) async {
    final day = today!();
    var row = await (_db.select(_db.shopRotation)..where((r) => r.localDay.equals(day) & r.shop.equals(shop))).getSingleOrNull();
    row ??= await _roll(day, shop, 0);
    final byKey = {for (final i in items()) i.itemKey: i};
    return [for (final k in (jsonDecode(row.itemKeys) as List).cast<String>()) if (byKey[k] != null) byKey[k]!];
  }

  Future<ShopRotationData> _roll(String day, String shop, int refreshCount) async {
    final owned = (await _db.select(_db.inventory).get()).map((i) => i.itemKey).toSet();
    final candidates = [
      for (final i in items())
        if (i.shop == shop && !i.alwaysAvailable && i.seasonalKey == null && !owned.contains(i.itemKey)) i.itemKey,
    ];
    final keys = _rotation.pick(candidates, size: rotationSize!(), installId: await installId!(), localDay: day, shop: shop, refreshCount: refreshCount);
    await _db.into(_db.shopRotation).insertOnConflictUpdate(
        ShopRotationCompanion.insert(localDay: day, shop: shop, refreshCount: Value(refreshCount), itemKeys: jsonEncode(keys)));
    return (_db.select(_db.shopRotation)..where((r) => r.localDay.equals(day) & r.shop.equals(shop))).getSingle();
  }

  /// "Permanent collection": base items that are always available.
  List<ShopItem> permanent(String shop) => [for (final i in items()) if (i.shop == shop && i.alwaysAvailable) i];

  /// Pays `shop.refresh_cost` coins for a different stock today.
  Future<RefreshStatus> refresh(String shop) async {
    final day = today!();
    final row = await (_db.select(_db.shopRotation)..where((r) => r.localDay.equals(day) & r.shop.equals(shop))).getSingleOrNull();
    final n = (row?.refreshCount ?? 0) + 1;
    final status = await _db.transaction(() async {
      if (!await _wallet.spend(Currency.coins, refreshCost!(), 'shop_refresh', '$day:$shop:$n')) return RefreshStatus.notEnoughCoins;
      await _roll(day, shop, n);
      return RefreshStatus.refreshed;
    });
    if (status == RefreshStatus.refreshed) await _analytics.track(AnalyticsEvent.shopRefreshed, {'paid': true});
    return status;
  }

  /// Sells an owned, not-worn item for `shop.sell_ratio` of its price.
  Future<SellStatus> sell(String itemKey) async {
    final owned = await (_db.select(_db.inventory)..where((i) => i.itemKey.equals(itemKey))).getSingleOrNull();
    if (owned == null) return SellStatus.notOwned;
    if (owned.equipped) return SellStatus.equipped;
    final price = item(itemKey)?.priceCoins ?? 0;
    await _db.transaction(() async {
      await _wallet.grant(Currency.coins, _rotation.sellPrice(price, sellRatio!()), 'item_sell', '$itemKey:${owned.acquiredAt}');
      await (_db.delete(_db.inventory)..where((i) => i.itemKey.equals(itemKey))).go();
    });
    await _analytics.track(AnalyticsEvent.itemSold, {'item_key': itemKey});
    await _publisher.refresh();
    return SellStatus.sold;
  }

  /// Sell value shown next to an owned item.
  int sellValue(String itemKey) => _rotation.sellPrice(item(itemKey)?.priceCoins ?? 0, sellRatio!());
}
