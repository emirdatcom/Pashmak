import 'dart:async';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/entitlement/entitlement_repository.dart';
import '../../../core/logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/outbox/outbox_worker.dart';
import '../../../core/payments/payment_gateway.dart';
import '../../../core/time/clock.dart';
import '../../wallet/domain/wallet_service.dart';

enum TrialOutcome { started, startedOffline, alreadyUsed, unavailable }

/// What the app should do on open after the entitlement state changed.
enum ExpiryAction { none, unlockHabits, showTrialEnded, showLockSelection }

enum PurchaseOutcome { verified, pending, canceled, failed }

class PurchaseReport {
  const PurchaseReport(this.outcome, {this.coinsGranted = 0});
  final PurchaseOutcome outcome;
  final int coinsGranted;
}

/// Trial, purchase and restore flows (docs/60 §4–§7). Everything that talks to the server goes through the
/// outbox so a flaky network never loses a paid purchase.
class MonetizationService {
  MonetizationService({
    required this.repo,
    required this.api,
    required this.gateway,
    required AppDatabase db,
    required this.wallet,
    required this.analytics,
    required this.clock,
    required this.config,
  }) : _db = db {
    outbox = OutboxWorker(db, clock, handlers);
  }

  final AppDatabase _db;

  final EntitlementRepository repo;
  final ApiClient api;
  final PaymentGateway gateway;
  late final OutboxWorker outbox;
  final WalletService wallet;
  final AnalyticsService analytics;
  final Clock clock;
  final AppConfig Function() config;

  Map<String, OutboxHandler> get handlers => {
        'trial_start': _trialStartHandler,
        'purchase_verify': _purchaseVerifyHandler,
        'purchase_restore': _restoreHandler,
      };

  // ---- trial ----------------------------------------------------------------

  /// "Start N free days" (explicit; never needs a payment). Online: the server decides. Offline: a
  /// provisional trial runs locally and `trial_start` confirms it later.
  Future<TrialOutcome> startTrial() async {
    if (!config().trialEnabled) return TrialOutcome.unavailable;
    try {
      final r = await api.request<Map<String, dynamic>>('POST', '/v1/trial/start', data: <String, dynamic>{});
      if (!await repo.accept(r.data!)) return TrialOutcome.unavailable;
      unawaited(analytics.track(AnalyticsEvent.trialStarted, {'provisional': false}));
      return TrialOutcome.started;
    } on ApiError catch (e) {
      if (e.code == 'TRIAL_ALREADY_USED') {
        await repo.markTrialUsed(_endOfLocalDay());
        return TrialOutcome.alreadyUsed;
      }
      if (!e.isNetwork && !e.isRetryable) return TrialOutcome.unavailable;
      final started = await repo.startProvisionalTrial();
      await outbox.enqueue('trial_start', {'provisional_started_at': started.toUtc().toIso8601String()});
      unawaited(analytics.track(AnalyticsEvent.trialStarted, {'provisional': true}));
      return TrialOutcome.startedOffline;
    }
  }

  Future<OutboxResult> _trialStartHandler(Map<String, dynamic> p) async {
    try {
      final r = await api.request<Map<String, dynamic>>('POST', '/v1/trial/start', data: {'provisional_started_at': p['provisional_started_at']});
      await repo.accept(r.data!);
      return OutboxResult.done;
    } on ApiError catch (e) {
      if (e.code == 'TRIAL_ALREADY_USED') {
        // Gentle: premium stays until the end of today, then the free tier (docs/60 §4).
        await repo.markTrialUsed(_endOfLocalDay());
        return OutboxResult.done;
      }
      rethrow;
    }
  }

  DateTime _endOfLocalDay() {
    final n = clock.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  /// Called on open (after refresh): premium → unlock everything; trial just ended → the calm "what now"
  /// page once; otherwise, if the free tier is exceeded, let the user pick which habits stay active.
  Future<ExpiryAction> reconcile({required int activeHabits, required int lockedHabits, required int freeLimit}) async {
    if (repo.status().isPremium) return lockedHabits > 0 ? ExpiryAction.unlockHabits : ExpiryAction.none;
    final endsMs = await _db.meta('trial_ends_at');
    final ends = int.tryParse(endsMs ?? '');
    if (ends != null && clock.now().millisecondsSinceEpoch >= ends && await _db.meta('trial_end_seen') != endsMs) {
      await _db.setMeta('trial_end_seen', endsMs!);
      final purchased = await _db.meta('premium_purchased') == 'true';
      unawaited(analytics.track(AnalyticsEvent.trialEnded, {'converted': purchased}));
      return ExpiryAction.showTrialEnded;
    }
    return activeHabits > freeLimit ? ExpiryAction.showLockSelection : ExpiryAction.none;
  }

  // ---- purchase -------------------------------------------------------------

  PricingPlan? planFor(String productId) {
    for (final p in config().plans) {
      if (p.productId == productId) return p;
    }
    return null;
  }

  String _skuFor(String productId) => planFor(productId)?.marketSku[gateway.market.name] ?? productId;

  /// Charges through the market, then verifies on the server. Premium is provisional (pending) in
  /// between, and a coin pack / pass is consumed only after the server confirmed it.
  Future<PurchaseReport> buy(String productId) async {
    unawaited(analytics.track(AnalyticsEvent.purchaseStarted, {'product_id': productId}));
    final res = await gateway.purchase(_skuFor(productId));
    switch (res.status) {
      case PurchaseStatus.canceled:
        return const PurchaseReport(PurchaseOutcome.canceled);
      case PurchaseStatus.error:
        unawaited(analytics.track(AnalyticsEvent.purchaseFailed, {'product_id': productId, 'reason': 'market'}));
        return const PurchaseReport(PurchaseOutcome.failed);
      case PurchaseStatus.success:
        break;
    }
    final pur = res.purchase!;
    // Paid: give provisional premium right away, then verify (outbox survives a kill/offline).
    await repo.setPending(Duration(hours: config().pendingVerificationHours));
    await outbox.enqueue('purchase_verify', {
      'market': gateway.market.name,
      'product_id': productId,
      'market_sku': pur.sku,
      'purchase_token': pur.token,
      'order_id': pur.orderId,
    });
    await outbox.runDue();
    final stillQueued = await outbox.pending() > 0;
    return PurchaseReport(stillQueued ? PurchaseOutcome.pending : PurchaseOutcome.verified);
  }

  Future<OutboxResult> _purchaseVerifyHandler(Map<String, dynamic> p) async {
    try {
      final r = await api.request<Map<String, dynamic>>('POST', '/v1/purchases/verify', data: {
        'market': p['market'],
        'product_id': p['product_id'],
        'market_sku': p['market_sku'],
        'purchase_token': p['purchase_token'],
        if ((p['order_id'] as String?)?.isNotEmpty ?? false) 'order_id': p['order_id'],
      });
      final body = r.data!;
      final state = body['purchase_state'] as String?;
      if (state != 'verified') {
        await repo.clearPending();
        unawaited(analytics.track(AnalyticsEvent.purchaseFailed, {'product_id': p['product_id'], 'reason': state ?? 'unknown'}));
        return OutboxResult.drop;
      }
      await repo.accept(body['entitlement_state'] as Map<String, dynamic>);
      await repo.clearPending();
      final coins = (body['coins_granted'] as int?) ?? 0;
      if (coins > 0) await wallet.grant(Currency.coins, coins, 'iap_coins', body['purchase_id'] as String);
      await gateway.consume(p['purchase_token'] as String); // only now: the server has the purchase
      unawaited(analytics.track(AnalyticsEvent.purchaseCompleted, {'kind': coins > 0 ? 'consumable' : 'pass', 'product_id': p['product_id']}));
      return OutboxResult.done;
    } on ApiError catch (e) {
      if (!e.isRetryable) {
        await repo.clearPending();
        unawaited(analytics.track(AnalyticsEvent.purchaseFailed, {'product_id': p['product_id'], 'reason': e.code}));
      }
      rethrow;
    }
  }

  // ---- restore --------------------------------------------------------------

  /// Re-sends what the market says this account owns; the server returns the new signed state.
  /// Returns the number of purchases found (0 = nothing to restore).
  Future<int> restore() async {
    final owned = await gateway.restore();
    if (owned.isEmpty) return 0;
    final payload = {
      'market': gateway.market.name,
      'purchases': [
        for (final o in owned.take(50)) {'product_id': _productIdForSku(o.sku), 'market_sku': o.sku, 'purchase_token': o.token, if (o.orderId.isNotEmpty) 'order_id': o.orderId},
      ],
    };
    try {
      await _restoreHandler(payload);
    } on ApiError catch (e) {
      AppLogger.warn('restore failed: ${e.code}');
      await outbox.enqueue('purchase_restore', payload);
      return owned.length;
    }
    unawaited(analytics.track(AnalyticsEvent.restoreCompleted, {'restored_count': owned.length}));
    return owned.length;
  }

  String _productIdForSku(String sku) {
    for (final p in config().plans) {
      if (p.marketSku[gateway.market.name] == sku) return p.productId;
    }
    return sku;
  }

  Future<OutboxResult> _restoreHandler(Map<String, dynamic> p) async {
    final r = await api.request<Map<String, dynamic>>('POST', '/v1/purchases/restore', data: p);
    await repo.accept(r.data!);
    return OutboxResult.done;
  }
}
