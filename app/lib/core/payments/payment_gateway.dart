enum Market { bazaar, myket }

class StoreProduct {
  const StoreProduct({required this.sku, required this.priceLabel});
  final String sku;
  final String priceLabel;
}

class StorePurchase {
  const StorePurchase({required this.sku, required this.token, required this.orderId});
  final String sku;
  final String token;
  final String orderId;
}

enum PurchaseStatus { success, canceled, error }

class PurchaseResult {
  const PurchaseResult.success(StorePurchase p)
      : status = PurchaseStatus.success,
        purchase = p;
  const PurchaseResult.canceled()
      : status = PurchaseStatus.canceled,
        purchase = null;
  const PurchaseResult.error()
      : status = PurchaseStatus.error,
        purchase = null;
  final PurchaseStatus status;
  final StorePurchase? purchase;
}

/// docs/20 §10. The flavor decides which implementation is injected.
abstract class PaymentGateway {
  Market get market;
  Future<void> connect();
  Future<List<StoreProduct>> products(List<String> skus);
  Future<PurchaseResult> purchase(String sku, {bool subscription = false});
  Future<List<StorePurchase>> restore();

  /// Consumes a coin pack / pass **only after** the server verified it.
  Future<void> consume(String purchaseToken);
}

/// Dev/test gateway: tokens use the backend's fake adapter conventions (`test_valid_*`).
class FakeGateway implements PaymentGateway {
  FakeGateway({this.market = Market.bazaar});
  @override
  final Market market;
  int _n = 0;
  final List<StorePurchase> owned = [];
  final List<String> consumed = [];

  @override
  Future<void> connect() async {}
  @override
  Future<List<StoreProduct>> products(List<String> skus) async =>
      [for (final s in skus) StoreProduct(sku: s, priceLabel: '—')];
  @override
  Future<PurchaseResult> purchase(String sku, {bool subscription = false}) async {
    final p = StorePurchase(sku: sku, token: 'test_valid_${_n++}_$sku', orderId: 'fake-$_n');
    owned.add(p);
    return PurchaseResult.success(p);
  }

  @override
  Future<List<StorePurchase>> restore() async => List.of(owned);
  @override
  Future<void> consume(String purchaseToken) async => consumed.add(purchaseToken);
}
