import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/time/local_day.dart';

/// "1405-09-28" → 14050928 (comparable). Seasonal ranges are Jalali dates with an explicit year (docs/40 §2).
int jalaliOrdinalOfString(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) throw FormatException('Not a Jalali date: $s');
  return int.parse(m[1]!) * 10000 + int.parse(m[2]!) * 100 + int.parse(m[3]!);
}

int jalaliOrdinalOf(LocalDay d) {
  final j = Jalali.fromDateTime(d.date);
  return j.year * 10000 + j.month * 100 + j.day;
}

class SeasonalItem {
  const SeasonalItem({required this.itemKey, required this.name, required this.slot, required this.priceCoins, required this.premiumOnly, required this.asset});
  factory SeasonalItem.fromJson(Map<String, dynamic> j) => SeasonalItem(
      itemKey: j['item_key'] as String, name: j['name'] as String, slot: j['slot'] as String, priceCoins: j['price_coins'] as int, premiumOnly: j['premium_only'] as bool, asset: j['asset'] as String);
  final String itemKey;
  final String name;
  final String slot;
  final int priceCoins;
  final bool premiumOnly;
  final String asset;

  /// Seasonal item names are pack data; they are exposed to `copy.t` under this key (see [SeasonalCatalog.copyOverlay]).
  String get nameKey => 'shop.item.$itemKey.name';
}

class SeasonalPack {
  SeasonalPack({required this.key, required this.from, required this.to, required this.name, required this.homeBanner, this.notifBody, this.accent, required this.items});

  /// [entries] is the pack's `entries` object.
  factory SeasonalPack.fromEntries(Map<String, dynamic> e) {
    final strings = (e['strings'] as Map).cast<String, dynamic>();
    final accent = (e['theme'] as Map?)?['accent'] as String?;
    return SeasonalPack(
      key: e['seasonal_key'] as String,
      from: jalaliOrdinalOfString(e['from'] as String),
      to: jalaliOrdinalOfString(e['to'] as String),
      name: strings['name'] as String,
      homeBanner: strings['home_banner'] as String,
      notifBody: strings['notif_body'] as String?,
      accent: accent == null ? null : int.parse('FF${accent.substring(1)}', radix: 16),
      items: [for (final i in (e['items'] as List).cast<Map<String, dynamic>>()) SeasonalItem.fromJson(i)],
    );
  }

  final String key;
  final int from; // Jalali ordinal, inclusive
  final int to; // inclusive
  final String name;
  final String homeBanner;
  final String? notifBody;
  final int? accent;
  final List<SeasonalItem> items;

  bool isActive(LocalDay today) {
    final o = jalaliOrdinalOf(today);
    return o >= from && o <= to;
  }

  /// First day of the season as a Gregorian date (for scheduling the seasonal notification).
  DateTime get startDate {
    final j = Jalali(from ~/ 10000, (from ~/ 100) % 100, from % 100).toDateTime();
    return DateTime(j.year, j.month, j.day);
  }
}

/// All seasonal packs the app knows (bundled + downloaded). Items of every pack stay resolvable after the
/// season (owned items keep their name and slot in the closet); only buying is restricted to the season.
class SeasonalCatalog {
  SeasonalCatalog(this.packs);

  factory SeasonalCatalog.fromEntries(Iterable<Object?> packEntries) => SeasonalCatalog([
        for (final e in packEntries)
          if (e is Map<String, dynamic>) SeasonalPack.fromEntries(e),
      ]);

  final List<SeasonalPack> packs;

  List<SeasonalPack> active(LocalDay today) => [for (final p in packs) if (p.isActive(today)) p];

  List<SeasonalItem> get allItems => [for (final p in packs) ...p.items];

  SeasonalPack? packOfItem(String itemKey) {
    for (final p in packs) {
      if (p.items.any((i) => i.itemKey == itemKey)) return p;
    }
    return null;
  }

  /// Texts exposed through the normal copy resolver so UI and notifications need no special case.
  Map<String, String> get copyOverlay => {
        for (final p in packs) ...{
          'seasonal.${p.key}.name': p.name,
          'seasonal.${p.key}.home_banner': p.homeBanner,
          if (p.notifBody != null) 'seasonal.${p.key}.notif_body': p.notifBody!,
          for (final i in p.items) i.nameKey: i.name,
        },
      };
}
