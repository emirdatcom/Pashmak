import 'package:drift/drift.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import '../../../core/widget_snapshot.dart';
import '../../wallet/domain/wallet_service.dart';

class ShopItem {
  const ShopItem({required this.itemKey, required this.nameKey, required this.slot, required this.priceCoins, required this.premiumOnly});
  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
      itemKey: j['item_key'] as String, nameKey: j['name_key'] as String, slot: j['slot'] as String, priceCoins: j['price_coins'] as int, premiumOnly: j['premium_only'] as bool);
  final String itemKey;
  final String nameKey;
  final String slot;
  final int priceCoins;
  final bool premiumOnly;

  /// Shop tab: `cat` (collar, hat), `room` (room_*), `background`.
  String get tab => slot == 'background' ? 'background' : (slot.startsWith('room_') ? 'room' : 'cat');
}

enum BuyStatus { bought, alreadyOwned, notEnoughCoins, premiumRequired, unknownItem }

enum EquipStatus { equipped, unequipped, notOwned, premiumLocked }

class ShopService {
  ShopService(this._db, this._clock, this._wallet, this._analytics, this._publisher, {required this.items});

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
    if (it.premiumOnly && !isPremium) return BuyStatus.premiumRequired;
    final status = await _db.transaction(() async {
      if (!await _wallet.spend(Currency.coins, it.priceCoins, 'shop_purchase', itemKey)) return BuyStatus.notEnoughCoins;
      await _db.into(_db.inventory).insert(InventoryCompanion.insert(itemKey: itemKey, acquiredAt: _clock.now().millisecondsSinceEpoch, source: 'shop', slot: it.slot));
      return BuyStatus.bought;
    });
    if (status == BuyStatus.bought) {
      await _analytics.track(AnalyticsEvent.shopItemPurchased, {'item_key': itemKey, 'price_coins': it.priceCoins});
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
}
