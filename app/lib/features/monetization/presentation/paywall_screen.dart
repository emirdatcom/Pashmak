import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/config/app_config.dart';
import '../../../core/entitlement/paywall_policy.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/payments/payment_gateway.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../domain/monetization_service.dart';
import '../monetization_providers.dart';

/// Thousands separated, Persian digits.
String formatToman(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('\u066C'); // Arabic thousands separator
    b.write(s[i]);
  }
  return toPersianDigits(b.toString());
}

int monthsOf(String productId) => switch (productId) {
      'premium_1m' => 1,
      'premium_3m' => 3,
      'premium_6m' => 6,
      'premium_12m' => 12,
      _ => 1,
    };

/// Real store prices when the market answers, else the configured Toman price. Skus come from config.
final storeProductsProvider = FutureProvider.autoDispose<Map<String, StoreProduct>>((ref) async {
  final market = ref.watch(flavorProvider).market.name;
  final plans = ref.watch(appConfigProvider).plans;
  final skus = [for (final p in plans) p.marketSku[market] ?? p.productId];
  final list = await ref.watch(paymentGatewayProvider).products(skus).timeout(const Duration(seconds: 6), onTimeout: () => const []);
  return {for (final p in list) p.sku: p};
});

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, required this.trigger});
  final String trigger;
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String? _selected;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final variant = ref.read(appConfigProvider).paywallVariant;
    unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.paywallViewed, {'trigger': widget.trigger, 'variant': variant}));
  }

  void _close() {
    unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.paywallClosed, {'trigger': widget.trigger}));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _buy(String productId) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final copy = ref.read(copyProvider);
    final r = await ref.read(monetizationServiceProvider).buy(productId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (r.outcome) {
        PurchaseOutcome.failed => copy.t('paywall.error.purchase'),
        PurchaseOutcome.pending => copy.t('paywall.pending'),
        _ => null,
      };
    });
    if (r.outcome == PurchaseOutcome.verified || r.outcome == PurchaseOutcome.pending) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t(r.outcome == PurchaseOutcome.verified ? 'paywall.unlocked' : 'paywall.pending'))));
      _close();
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final copy = ref.read(copyProvider);
    final n = await ref.read(monetizationServiceProvider).restore();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = n == 0 ? copy.t('paywall.restore.none') : copy.t('paywall.restore.done', {'n': toPersianDigits(n)});
    });
    if (n > 0 && ref.read(premiumProvider)) _close();
  }

  Future<void> _trial() async {
    setState(() => _busy = true);
    final copy = ref.read(copyProvider);
    final o = await ref.read(monetizationServiceProvider).startTrial();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = o == TrialOutcome.alreadyUsed ? copy.t('paywall.trial_used') : null;
    });
    if (o == TrialOutcome.started || o == TrialOutcome.startedOffline) _close();
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final config = ref.watch(appConfigProvider);
    final market = ref.watch(flavorProvider).market.name;
    final store = ref.watch(storeProductsProvider).value ?? const <String, StoreProduct>{};
    final status = ref.watch(premiumStatusProvider);
    final snapshotEligible = ref.watch(entitlementRepositoryProvider)?.snapshot.state?.trialEligible ?? true;
    final canTrial = config.trialEnabled && !status.isPremium && snapshotEligible;
    final plans = config.plans;
    final anchor = plans.where((p) => p.productId == config.monthlyAnchorProduct).firstOrNull;
    _selected ??= plans.where((p) => p.highlight).firstOrNull?.productId ?? plans.firstOrNull?.productId;
    final variantB = config.paywallVariant == 'b';

    Widget planTile(PricingPlan p) {
      final sku = p.marketSku[market] ?? p.productId;
      final price = store[sku]?.priceLabel;
      final label = (price != null && price.isNotEmpty) ? price : copy.t('paywall.price_toman', {'n': formatToman(p.displayPriceToman)});
      final save = anchor == null ? null : PaywallPolicy.savingPercent(price: p.displayPriceToman, months: monthsOf(p.productId), monthlyPrice: anchor.displayPriceToman);
      final selected = _selected == p.productId;
      return Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md), side: BorderSide(color: selected ? AppColors.orangeDark : Colors.transparent, width: 2)),
        child: Semantics(
          selected: selected,
          button: true,
          child: ListTile(
            onTap: _busy
                ? null
                : () {
                    setState(() => _selected = p.productId);
                    unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.paywallPlanSelected, {'product_id': p.productId}));
                  },
            title: Text(copy.t('paywall.plan.${p.productId}')),
            subtitle: save == null ? null : Text(copy.t('paywall.save_percent', {'n': toPersianDigits(save)})),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              if (p.badgeKey.isNotEmpty) Text(copy.t(p.badgeKey), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
    }

    final benefits = [
      for (final b in ['habits', 'exercises', 'stats', 'adventures', 'items']) ListTile(dense: true, leading: const Icon(Icons.check_circle_outline), title: Text(copy.t('paywall.benefit.$b'))),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [IconButton(tooltip: copy.t('paywall.close'), icon: const Icon(Icons.close), onPressed: _close)],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
          Text(copy.t('paywall.title'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(copy.t('paywall.subtitle')),
          const SizedBox(height: AppSpacing.md),
          // Variant "b" leads with the plans, "a" leads with the benefits (docs/60 §5).
          if (!variantB) ...benefits,
          for (final p in plans) planTile(p),
          if (variantB) ...benefits,
          if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text(_message!, textAlign: TextAlign.center)),
          const SizedBox(height: AppSpacing.sm),
          if (canTrial) ...[
            FilledButton(onPressed: _busy ? null : _trial, child: Text(copy.t('paywall.trial_cta'))),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: _busy || _selected == null ? null : () => _buy(_selected!), child: Text(copy.t('paywall.cta'))),
          ] else
            FilledButton(onPressed: _busy || _selected == null || status.isPremium && !status.provisional ? null : () => _buy(_selected!), child: Text(copy.t('paywall.cta'))),
          TextButton(onPressed: _busy ? null : _restore, child: Text(copy.t('paywall.restore'))),
          if (_busy) const Padding(padding: EdgeInsets.all(AppSpacing.sm), child: Center(child: CircularProgressIndicator())),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => context.push('/settings/terms'), child: Text(copy.t('paywall.terms'))),
            TextButton(onPressed: () => context.push('/settings/privacy'), child: Text(copy.t('paywall.privacy'))),
          ]),
        ]),
      ),
    );
  }
}
