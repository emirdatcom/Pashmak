import '../../goals/domain/goal_recommender.dart' show stableHash;

/// Pure rotating-stock logic (docs/60). The stock of a day is stable for the whole day and changes at the next
/// `local_day`; a paid refresh bumps [refreshCount] and gives a different stock.
class ShopRotation {
  const ShopRotation();

  /// [candidates] are the rotating items (not `always_available`). The result has at most [size] item keys.
  List<String> pick(List<String> candidates, {required int size, required String installId, required String localDay, required String shop, int refreshCount = 0}) {
    final sorted = [...candidates]
      ..sort((a, b) => stableHash('$installId|$localDay|$shop|$refreshCount|$a').compareTo(stableHash('$installId|$localDay|$shop|$refreshCount|$b')));
    return sorted.take(size).toList();
  }

  /// Sell price: [ratio] of the buy price, rounded down.
  int sellPrice(int priceCoins, double ratio) => (priceCoins * ratio).floor();

  /// "۱۲:۲۷:۰۵" style countdown until the next day start.
  Duration untilRefresh(DateTime now, DateTime nextDayStart) => nextDayStart.isAfter(now) ? nextDayStart.difference(now) : Duration.zero;
}
