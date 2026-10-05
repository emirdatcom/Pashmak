import 'payments/payment_gateway.dart';

/// Build flavors = app markets.
enum Flavor {
  bazaar(Market.bazaar, 'bazaar'),
  myket(Market.myket, 'myket');

  const Flavor(this.market, this.wireName);
  final Market market;
  final String wireName;

  /// Deep link into the market app's page for this app (force update, rating).
  Uri storeUri(String applicationId) => switch (this) {
        Flavor.bazaar => Uri.parse('bazaar://details?id=$applicationId'),
        Flavor.myket => Uri.parse('myket://details?id=$applicationId'),
      };

  Uri storeWebUri(String applicationId) => switch (this) {
        Flavor.bazaar => Uri.parse('https://cafebazaar.ir/app/$applicationId'),
        Flavor.myket => Uri.parse('https://myket.ir/app/$applicationId'),
      };
}

/// `--dart-define=API_BASE_URL=...` (default points at a local backend).
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');
