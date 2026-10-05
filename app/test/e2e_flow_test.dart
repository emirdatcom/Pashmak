import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/entitlement/canonical_json.dart';
import 'package:pashmak_app/core/entitlement/entitlement_repository.dart';
import 'package:pashmak_app/core/entitlement/signature_verifier.dart';
import 'package:pashmak_app/core/payments/payment_gateway.dart';
import 'package:pashmak_app/features/adventure/domain/adventure_service.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/monetization/domain/monetization_service.dart';
import 'package:pashmak_app/features/onboarding/domain/onboarding_service.dart';
import 'package:pashmak_app/features/shop/domain/shop_service.dart';
import 'package:pashmak_app/features/wallet/domain/wallet_service.dart';

import 'core_loop_helpers.dart';
import 'helpers.dart';

/// docs 15 "integration" flow, driven through the real services (no device needed):
/// fresh install → onboarding → tick a habit → adventure (FakeClock) → claim → buy an item → paywall purchase with FakeGateway.
void main() {
  test('fresh install to premium: the whole MVP loop works offline except the purchase verification', () async {
    final t0 = DateTime.utc(2026, 10, 5, 8);
    final h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 2)), refresh: 'r', userId: 'u1'));
    final l = Loop(t0, database: h.db, dayStartHour: 0);

    // 1. onboarding: name + two habits
    final onboarding = OnboardingService(l.db, l.habits, l.analytics, defaultCatName: 'ملوس');
    expect(await onboarding.currentStep(), 1);
    await onboarding.saveCatName('پشمک');
    await onboarding.complete(habits: {'water': 600, 'walk': null}, notifPermission: false, catNameChanged: true);
    expect(await l.db.meta('onboarding_completed'), 'true');

    // 2. tick a habit → energy
    final water = (await l.habits.activeHabits()).firstWhere((x) => x.templateKey == 'water');
    expect((await l.habits.complete(water.id)).status, CompleteStatus.completed);
    expect((await l.wallet.balance()).energy, l.config.energyPerHabit);
    await l.wallet.grant(Currency.energy, 50, 'promo', 'e2e'); // enough for an adventure

    // 3. adventure: start, wait (FakeClock), claim
    final start = await l.adventures.start('alley', isPremium: false);
    expect(start.status, StartStatus.started);
    l.clock.advance(const Duration(minutes: 31));
    final cur = (await l.adventures.current())!;
    expect(cur.status, 'returned');
    final claim = (await l.adventures.claim(cur.id))!;
    expect((await l.wallet.balance()).coins, claim.coins);

    // 4. buy an item with coins (top up so the test does not depend on the reward roll)
    await l.wallet.grant(Currency.coins, 500, 'promo', 'e2e-coins');
    expect(await l.shop.buy('collar_turquoise', isPremium: false), BuyStatus.bought);

    // 5. paywall: buy a plan with the fake gateway; the server confirms with a signed state
    final priv = ed.newKeyFromSeed(Uint8List.fromList(List.generate(32, (i) => i)));
    final keys = EntitlementKeys({'ent-test': Uint8List.fromList(ed.public(priv).bytes)});
    String iso(DateTime d) => d.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');
    final now = l.clock.now();
    final body = <String, dynamic>{
      'entitlements': [
        {'key': 'premium', 'source': 'pass', 'starts_at': iso(now), 'ends_at': iso(now.add(const Duration(days: 30)))}
      ],
      'trial': {'eligible': false, 'used': true, 'ends_at': null},
      'server_time': iso(now),
      'valid_until': iso(now.add(const Duration(days: 7))),
      'grace_days': 3,
    };
    final state = {...body, 'kid': 'ent-test', 'signature': base64Url.encode(ed.sign(priv, canonicalJson(body))).replaceAll('=', '')};
    h.mock.onPost('/v1/purchases/verify', (s) => s.reply(200, {'purchase_id': 'p-e2e', 'purchase_state': 'verified', 'entitlement_state': state, 'coins_granted': 0}), data: Matchers.any);

    final repo = EntitlementRepository(h.db, h.api, SignatureVerifier(keys), l.clock, trialDays: () => 7);
    await repo.load();
    expect(repo.status().isPremium, isFalse);
    final gateway = FakeGateway();
    final money = MonetizationService(
        repo: repo, api: h.api, gateway: gateway, db: h.db, wallet: l.wallet, analytics: l.analytics, clock: l.clock, config: () => l.config);
    final r = await money.buy('premium_3m');
    expect(r.outcome, PurchaseOutcome.verified);
    expect(repo.status().isPremium, isTrue);
    expect(gateway.consumed, hasLength(1));

    // premium unlocks a fourth habit and the premium location
    expect(await l.habits.gateFor(const HabitDraft(templateKey: 'sleep'), isPremium: true), isNull);
    expect(await l.habits.gateFor(const HabitDraft(title: 'x'), isPremium: false), isNotNull);
  });
}
