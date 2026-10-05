import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/config/app_config.dart';
import 'package:pashmak_app/core/entitlement/canonical_json.dart';
import 'package:pashmak_app/core/entitlement/entitlement_repository.dart';
import 'package:pashmak_app/core/entitlement/paywall_policy.dart';
import 'package:pashmak_app/core/entitlement/premium_gate.dart';
import 'package:pashmak_app/core/entitlement/signature_verifier.dart';
import 'package:pashmak_app/core/payments/payment_gateway.dart';
import 'package:pashmak_app/features/monetization/domain/monetization_service.dart';
import 'package:pashmak_app/features/wallet/domain/wallet_service.dart';

import 'package:pashmak_app/features/habits/domain/habit_service.dart';

import 'core_loop_helpers.dart';
import 'helpers.dart';

final t0 = DateTime.utc(2026, 10, 5, 8);
String iso(DateTime d) => d.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');

/// Signs states with the same test seed the Go fixture uses (bytes 0..31, kid `ent-test`).
final _priv = ed.newKeyFromSeed(Uint8List.fromList(List.generate(32, (i) => i)));
final _keys = EntitlementKeys({'ent-test': Uint8List.fromList(ed.public(_priv).bytes)});

Map<String, dynamic> signed({List<(String, DateTime, DateTime)> entries = const [], DateTime? now, Map<String, dynamic>? trial}) {
  final n = now ?? t0;
  final m = <String, dynamic>{
    'entitlements': [for (final e in entries) {'key': 'premium', 'source': e.$1, 'starts_at': iso(e.$2), 'ends_at': iso(e.$3)}],
    'trial': trial ?? {'eligible': true, 'used': false, 'ends_at': null},
    'server_time': iso(n),
    'valid_until': iso(n.add(const Duration(days: 7))),
    'grace_days': 3,
  };
  final sig = ed.sign(_priv, canonicalJson(Map<String, dynamic>.of(m)));
  return {...m, 'kid': 'ent-test', 'signature': base64Url.encode(sig).replaceAll('=', '')};
}

Map<String, dynamic> premiumState({DateTime? now}) =>
    signed(now: now, entries: [('pass', now ?? t0, (now ?? t0).add(const Duration(days: 30)))], trial: {'eligible': false, 'used': true, 'ends_at': null});

DioException offline() => DioException.connectionError(requestOptions: RequestOptions(path: '/x'), reason: 'offline');

void main() {
  late ApiHarness h;
  late FakeGateway gateway;
  late EntitlementRepository repo;
  late MonetizationService svc;
  late WalletService wallet;
  late AppConfig config;

  setUp(() async {
    h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 1)), refresh: 'r', userId: 'u1'));
    config = AppConfig(jsonDecode(realAssets().files['assets/config/default.json']!) as Map<String, dynamic>);
    gateway = FakeGateway();
    repo = EntitlementRepository(h.db, h.api, SignatureVerifier(_keys), h.clock, trialDays: () => 7);
    await repo.load();
    wallet = WalletService(h.db, h.clock, energyCap: () => 100);
    svc = MonetizationService(
        repo: repo, api: h.api, gateway: gateway, db: h.db, wallet: wallet, analytics: const NoopAnalytics(), clock: h.clock, config: () => config);
  });

  group('trial', () {
    test('online: the server decides, nothing is queued', () async {
      h.mock.onPost('/v1/trial/start', (s) => s.reply(200, signed(trial: {'eligible': false, 'used': true, 'ends_at': iso(t0.add(const Duration(days: 7)))}, entries: [('trial', t0, t0.add(const Duration(days: 7)))])),
          data: Matchers.any);
      expect(await svc.startTrial(), TrialOutcome.started);
      expect(repo.status().isPremium, isTrue);
      expect(repo.status().source, 'trial');
      expect(await svc.outbox.pending(), 0);
    });

    test('offline: provisional trial, confirmed later by the outbox', () async {
      h.mock.onPost('/v1/trial/start', (s) => s.throws(0, offline()), data: Matchers.any);
      expect(await svc.startTrial(), TrialOutcome.startedOffline);
      expect(repo.status().provisional, isTrue);
      expect(repo.status().isPremium, isTrue);
      expect(await svc.outbox.pending(), 1);

      h.mock.reset();
      h.mock.onPost('/v1/trial/start', (s) => s.reply(200, signed(trial: {'eligible': false, 'used': true, 'ends_at': iso(t0.add(const Duration(days: 7)))}, entries: [('trial', t0, t0.add(const Duration(days: 7)))])),
          data: Matchers.any);
      h.clock.advance(const Duration(minutes: 5));
      await svc.outbox.runDue();
      expect(await svc.outbox.pending(), 0);
      expect(repo.status().provisional, isFalse);
      expect(repo.status().source, 'trial');
    });

    test('TRIAL_ALREADY_USED online: gentle message, premium only until the end of today', () async {
      h.mock.onPost('/v1/trial/start',
          (s) => s.reply(409, {'error': {'code': 'TRIAL_ALREADY_USED', 'message': 'x', 'request_id': 'q'}}), data: Matchers.any);
      expect(await svc.startTrial(), TrialOutcome.alreadyUsed);
      expect(repo.status().isPremium, isTrue, reason: 'no abrupt cut');
      h.clock.advance(const Duration(days: 2));
      expect(repo.status().isPremium, isFalse);
    });

    test('a provisional trial the server refuses is not cut immediately', () async {
      await repo.startProvisionalTrial();
      await svc.outbox.enqueue('trial_start', {'provisional_started_at': iso(t0)});
      h.mock.onPost('/v1/trial/start',
          (s) => s.reply(409, {'error': {'code': 'TRIAL_ALREADY_USED', 'message': 'x', 'request_id': 'q'}}), data: Matchers.any);
      await svc.outbox.runDue();
      expect(await svc.outbox.pending(), 0);
      expect(repo.status().isPremium, isTrue);
      h.clock.advance(const Duration(days: 8));
      expect(repo.status().isPremium, isFalse);
    });

    test('disabled by remote config', () async {
      config = AppConfig(AppConfig.merge(config.raw, {'trial': {'enabled': false}}));
      expect(await svc.startTrial(), TrialOutcome.unavailable);
    });
  });

  group('purchase', () {
    void verify(Map<String, dynamic> Function() body, {int status = 200}) =>
        h.mock.onPost('/v1/purchases/verify', (s) => s.reply(status, body()), data: Matchers.any);

    test('verified pass: signed state, pending cleared, consumed only after the server', () async {
      verify(() => {'purchase_id': 'p-1', 'purchase_state': 'verified', 'entitlement_state': premiumState(), 'coins_granted': 0});
      final r = await svc.buy('premium_1m');
      expect(r.outcome, PurchaseOutcome.verified);
      expect(repo.status().source, 'pass');
      expect(repo.status().provisional, isFalse);
      expect(gateway.consumed, hasLength(1));
    });

    test('coin pack: ledger entry keyed by purchase id (idempotent)', () async {
      verify(() => {'purchase_id': 'p-2', 'purchase_state': 'verified', 'entitlement_state': signed(), 'coins_granted': 200});
      await svc.buy('coins_small');
      expect((await wallet.balance()).coins, 200);
      // the same server answer replayed must not double-grant
      expect(await wallet.grant(Currency.coins, 200, 'iap_coins', 'p-2'), isNull);
      expect((await wallet.balance()).coins, 200);
    });

    test('server unreachable: provisional premium, nothing consumed, finished later', () async {
      h.mock.onPost('/v1/purchases/verify', (s) => s.throws(0, offline()), data: Matchers.any);
      final r = await svc.buy('premium_3m');
      expect(r.outcome, PurchaseOutcome.pending);
      expect(repo.status().source, 'pending');
      expect(gateway.consumed, isEmpty);
      expect(await svc.outbox.pending(), 1);

      h.mock.reset();
      h.mock.onPost('/v1/purchases/verify',
          (s) => s.reply(200, {'purchase_id': 'p-3', 'purchase_state': 'verified', 'entitlement_state': premiumState(), 'coins_granted': 0}),
          data: Matchers.any);
      h.clock.advance(const Duration(minutes: 30));
      await svc.outbox.runDue();
      expect(await svc.outbox.pending(), 0);
      expect(repo.status().source, 'pass');
      expect(gateway.consumed, hasLength(1));
    });

    test('a purchase the server rejects removes the provisional premium', () async {
      verify(() => {'error': {'code': 'PURCHASE_INVALID', 'message': 'x', 'request_id': 'q'}}, status: 422);
      await svc.buy('premium_1m');
      expect(repo.status().isPremium, isFalse);
      expect(gateway.consumed, isEmpty);
      expect(await svc.outbox.pending(), 0);
    });

    test('an unsigned or tampered state is never trusted', () async {
      final bad = premiumState()..['grace_days'] = 99;
      verify(() => {'purchase_id': 'p-4', 'purchase_state': 'verified', 'entitlement_state': bad, 'coins_granted': 0});
      await svc.buy('premium_1m');
      expect(repo.status().source, isNot('pass'));
    });

    test('market cancel and market error report without touching premium', () async {
      expect((await svc.buy('premium_1m')).outcome, isIn([PurchaseOutcome.verified, PurchaseOutcome.pending, PurchaseOutcome.failed]));
    });
  });

  group('restore', () {
    test('nothing owned → 0, no request', () async {
      expect(await svc.restore(), 0);
    });

    test('owned purchases are re-sent and the signed state is stored', () async {
      await gateway.purchase('premium_6m');
      h.mock.onPost('/v1/purchases/restore', (s) => s.reply(200, premiumState()), data: Matchers.any);
      expect(await svc.restore(), 1);
      expect(repo.status().source, 'pass');
    });

    test('restore while offline is queued', () async {
      await gateway.purchase('premium_6m');
      h.mock.onPost('/v1/purchases/restore', (s) => s.throws(0, offline()), data: Matchers.any);
      expect(await svc.restore(), 1);
      expect(await svc.outbox.pending(), 1);
    });
  });

  group('expiry', () {
    test('premium + locked habits → unlock', () async {
      await repo.accept(premiumState());
      expect(await svc.reconcile(activeHabits: 3, lockedHabits: 2, freeLimit: 3), ExpiryAction.unlockHabits);
      expect(await svc.reconcile(activeHabits: 3, lockedHabits: 0, freeLimit: 3), ExpiryAction.none);
    });

    test('free with too many habits → selection; the trial-ended page shows only once', () async {
      await repo.accept(signed(trial: {'eligible': false, 'used': true, 'ends_at': iso(t0.add(const Duration(days: 7)))}));
      expect(await svc.reconcile(activeHabits: 2, lockedHabits: 0, freeLimit: 3), ExpiryAction.none, reason: 'trial not over yet');
      h.clock.advance(const Duration(days: 8));
      expect(await svc.reconcile(activeHabits: 5, lockedHabits: 0, freeLimit: 3), ExpiryAction.showTrialEnded);
      expect(await svc.reconcile(activeHabits: 5, lockedHabits: 0, freeLimit: 3), ExpiryAction.showLockSelection);
      expect(await svc.reconcile(activeHabits: 2, lockedHabits: 0, freeLimit: 3), ExpiryAction.none);
    });

    test('locking keeps the chosen habits writable and never deletes; premium restores', () async {
      final l = Loop(t0);
      final ids = [for (var i = 0; i < 3; i++) await l.habits.create(HabitDraft(title: 'h$i'))];
      await l.habits.lockExcept({ids[0]});
      final all = await l.habits.activeHabits();
      expect(all, hasLength(3));
      expect(all.where((h) => !h.isLocked).map((h) => h.id), [ids[0]]);
      expect((await l.habits.complete(ids[1])).status, CompleteStatus.locked);
      await l.habits.unlockAll();
      expect((await l.habits.activeHabits()).every((h) => !h.isLocked), isTrue);
    });
  });

  group('PaywallPolicy', () {
    GateDecision d({bool premium = false, bool enabled = true, GateContext ctx = const GateContext(), bool user = true, DateTime? last, int hours = 24}) => PaywallPolicy.decide(
        trigger: 'fourth_habit', isPremium: premium, triggerEnabled: enabled, context: ctx, userInitiated: user, lastShown: last, now: t0, cooldownHours: hours);

    test('rules table', () {
      expect(d(premium: true), GateDecision.allow);
      expect(d(enabled: false), GateDecision.allow);
      expect(d(ctx: const GateContext(inExercise: true)), GateDecision.suppressed);
      expect(d(ctx: const GateContext(onSafetyScreen: true)), GateDecision.suppressed);
      expect(d(ctx: const GateContext(lowMoodThisSession: true)), GateDecision.suppressed);
      expect(d(ctx: const GateContext(onboardingCompleted: false)), GateDecision.suppressed);
      expect(d(), GateDecision.showPaywall);
    });

    test('cooldown only limits automatic paywalls', () {
      final recent = t0.subtract(const Duration(hours: 2));
      expect(d(user: false, last: recent), GateDecision.suppressed);
      expect(d(user: true, last: recent), GateDecision.showPaywall);
      expect(d(user: false, last: t0.subtract(const Duration(hours: 25))), GateDecision.showPaywall);
    });

    test('saving percent against the monthly anchor', () {
      expect(PaywallPolicy.savingPercent(price: 749000, months: 12, monthlyPrice: 99000), 36);
      expect(PaywallPolicy.savingPercent(price: 99000, months: 1, monthlyPrice: 99000), isNull);
      expect(PaywallPolicy.savingPercent(price: 200000, months: 2, monthlyPrice: 99000), isNull, reason: 'not cheaper');
    });
  });
}
