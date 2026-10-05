import 'package:flutter/services.dart';

import '../logger.dart';
import 'payment_gateway.dart';

/// Talks to the per-flavor Kotlin billing code over `app/billing`
/// (android/app/src/{bazaar,myket}/kotlin/.../FlavorBilling.kt). Each flavor links only its own
/// market SDK, so the APK of one market never contains the other's billing library (docs/20 §10).
///
/// Wire contract:
///  connect({rsa_key}) → bool
///  products({skus}) → [{sku, price}]
///  purchase({sku, subscription}) → {status: success|canceled|error, sku, token, order_id}
///  restore() → [{sku, token, order_id}]
///  consume({token}) → bool
class ChannelPaymentGateway implements PaymentGateway {
  ChannelPaymentGateway(this.market, {this.rsaKey, MethodChannel? channel}) : _channel = channel ?? const MethodChannel('app/billing');

  @override
  final Market market;
  final String? rsaKey;
  final MethodChannel _channel;
  bool _connected = false;

  @override
  Future<void> connect() async {
    if (_connected) return;
    try {
      _connected = (await _channel.invokeMethod<bool>('connect', {'rsa_key': rsaKey})) ?? false;
    } on PlatformException catch (e) {
      AppLogger.warn('billing connect failed: ${e.code}');
    } on MissingPluginException {
      AppLogger.warn('billing channel missing (not an Android market build)');
    }
  }

  @override
  Future<List<StoreProduct>> products(List<String> skus) async {
    await connect();
    try {
      final r = await _channel.invokeListMethod<Map<Object?, Object?>>('products', {'skus': skus}) ?? const [];
      return [for (final m in r) StoreProduct(sku: m['sku']! as String, priceLabel: (m['price'] as String?) ?? '')];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<PurchaseResult> purchase(String sku, {bool subscription = false}) async {
    await connect();
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('purchase', {'sku': sku, 'subscription': subscription});
      switch (m?['status']) {
        case 'success':
          return PurchaseResult.success(StorePurchase(sku: m!['sku']! as String, token: m['token']! as String, orderId: (m['order_id'] as String?) ?? ''));
        case 'canceled':
          return const PurchaseResult.canceled();
      }
      return const PurchaseResult.error();
    } on PlatformException {
      return const PurchaseResult.error();
    } on MissingPluginException {
      return const PurchaseResult.error();
    }
  }

  @override
  Future<List<StorePurchase>> restore() async {
    await connect();
    try {
      final r = await _channel.invokeListMethod<Map<Object?, Object?>>('restore') ?? const [];
      return [for (final m in r) StorePurchase(sku: m['sku']! as String, token: m['token']! as String, orderId: (m['order_id'] as String?) ?? '')];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> consume(String purchaseToken) async {
    await connect();
    try {
      await _channel.invokeMethod<bool>('consume', {'token': purchaseToken});
    } on PlatformException catch (e) {
      AppLogger.warn('consume failed: ${e.code}'); // token stays; the purchase can be retried safely
    } on MissingPluginException {
      // nothing to consume
    }
  }
}

/// Cafe Bazaar (Poolakey). `BAZAAR_RSA_KEY` enables the optional local signature check.
class BazaarGateway extends ChannelPaymentGateway {
  BazaarGateway({super.rsaKey, super.channel}) : super(Market.bazaar);
}

/// Myket IAB. The RSA public key from the Myket panel is mandatory for the IabHelper (`MYKET_RSA_KEY`).
class MyketGateway extends ChannelPaymentGateway {
  MyketGateway({super.rsaKey, super.channel}) : super(Market.myket);
}
