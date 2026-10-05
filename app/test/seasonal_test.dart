import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/time/local_day.dart';
import 'package:pashmak_app/core/widget_snapshot.dart';
import 'package:pashmak_app/features/shop/domain/shop_service.dart';
import 'package:pashmak_app/features/shop/seasonal/seasonal.dart';
import 'package:pashmak_app/features/wallet/domain/wallet_service.dart';

import 'core_loop_helpers.dart';

SeasonalCatalog catalog() => SeasonalCatalog.fromEntries([
      for (final k in ['nowruz', 'yalda', 'ramadan']) (jsonDecode(File('assets/content/seasonal_$k.json').readAsStringSync()) as Map)['entries'],
    ]);

void main() {
  test('Jalali season ranges: Yalda only inside its dates, Nowruz spans the year change', () {
    final c = catalog();
    LocalDay d(int y, int m, int day) => LocalDay.fromDate(DateTime(y, m, day));
    // 1405-09-28 = 2026-12-19, 1405-10-01 = 2026-12-22
    expect(c.active(d(2026, 12, 18)).map((p) => p.key), isNot(contains('yalda')));
    expect(c.active(d(2026, 12, 19)).map((p) => p.key), contains('yalda'));
    expect(c.active(d(2026, 12, 22)).map((p) => p.key), contains('yalda'));
    expect(c.active(d(2026, 12, 23)).map((p) => p.key), isNot(contains('yalda')));
    // 1405-12-20 = 2027-03-11 ... 1406-01-13 = 2027-04-02
    expect(c.active(d(2027, 3, 11)).map((p) => p.key), contains('nowruz'));
    expect(c.active(d(2027, 3, 21)).map((p) => p.key), contains('nowruz'));
    expect(c.active(d(2027, 4, 2)).map((p) => p.key), contains('nowruz'));
    expect(c.active(d(2027, 4, 3)).map((p) => p.key), isNot(contains('nowruz')));
    expect(c.active(d(2026, 10, 5)), isEmpty);
  });

  test('ramadan is text and theme only', () {
    expect(catalog().packs.firstWhere((p) => p.key == 'ramadan').items, isEmpty);
  });

  test('copy overlay exposes banner, notification and item names', () {
    final o = catalog().copyOverlay;
    expect(o['seasonal.yalda.home_banner'], isNotEmpty);
    expect(o['shop.item.hat_nowruz_sabzeh.name'], 'کلاه سبزه');
  });

  test('seasonal items can only be bought in season; purchase fires the seasonal event; owned items persist', () async {
    final l = Loop(DateTime(2026, 12, 20, 12));
    await l.wallet.grant(Currency.coins, 1000, 'promo', 'seed');
    final c = catalog();
    var active = false;
    final shop = ShopService(l.db, l.clock, l.wallet, l.analytics, const NoopWidgetSnapshotPublisher(),
        items: () => [for (final p in c.packs) for (final i in p.items) ShopItem(itemKey: i.itemKey, nameKey: i.nameKey, slot: i.slot, priceCoins: i.priceCoins, premiumOnly: false, seasonalKey: p.key)],
        isSeasonActive: (_) => active);
    expect(await shop.buy('hat_yalda_watermelon', isPremium: false), BuyStatus.outOfSeason);
    active = true;
    expect(await shop.buy('hat_yalda_watermelon', isPremium: false), BuyStatus.bought);
    final ev = await (l.db.select(l.db.analyticsQueue)..where((e) => e.name.equals('seasonal_item_purchased'))).getSingle();
    expect(jsonDecode(ev.props), {'seasonal_key': 'yalda'});
    active = false;
    expect(shop.item('hat_yalda_watermelon'), isNotNull, reason: 'still resolvable in the closet');
    expect(await shop.buy('hat_yalda_watermelon', isPremium: false), BuyStatus.alreadyOwned);
  });
}
