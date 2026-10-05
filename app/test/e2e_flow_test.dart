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
import 'package:pashmak_app/features/goals/domain/goal_recommender.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/quests/domain/quest_service.dart';
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

    // 1. onboarding: questionnaire answers → 3 suggested goals → the cat arrives
    final onboarding = OnboardingService(l.db, l.habits, l.analytics, l.clock, defaultCatName: 'ملوس');
    expect(await onboarding.currentStep(), 1);
    await onboarding.saveCatName('پشمک');
    const profile = OnboardingProfile(
        energyLevel: 2, areas: ['sleep', 'calm'], areaAnswers: {'sleep': AreaAnswer.rarely, 'calm': AreaAnswer.rarely});
    await onboarding.answers.save(profile);
    final library = (jsonDecode(realAssets().files['assets/content/goal_library.json']!)['entries'] as List).cast<Map<String, dynamic>>().map(GoalDef.fromJson).toList();
    final rec = GoalRecommender(goals: library, weights: l.config.recommenderWeights);
    final plan = rec.recommend(await onboarding.answers.load(), count: l.config.recommendCountFree, seed: 7);
    expect(plan.length, 3);
    expect(plan.every((g) => g.difficulty == 1), isTrue, reason: 'low energy: only easy wins');
    await onboarding.complete(
        goals: [for (final g in plan) PlannedGoal(g, rec.resolvedTimeOfDay(g, profile.chronotype))],
        notifPermission: false,
        catNameChanged: true,
        profile: profile);
    expect(await l.db.meta('onboarding_completed'), 'true');
    expect((await l.habits.activeHabits()).length, 3);

    // 2. tick the goals → energy toward the daily target, plus a check-in to fill the bar
    for (final g in await l.habits.activeHabits()) {
      expect((await l.habits.complete(g.id)).status, CompleteStatus.completed);
    }
    expect((await l.wallet.balance()).energy, 3 * l.config.energyPerGoal);
    await l.wallet.grant(Currency.energy, 5, 'promo', 'e2e'); // 20 = the daily target

    // 3. the day's adventure starts by itself once the bar is full; wait (FakeClock), claim → coins + discovery
    final start = (await l.adventures.maybeAutoStart(isPremium: false))!;
    expect(start.status, StartStatus.started);
    expect(await l.adventures.maybeAutoStart(isPremium: false), isNull, reason: 'one adventure a day');
    l.clock.advance(const Duration(minutes: 31));
    final cur = (await l.adventures.current())!;
    expect(cur.status, 'returned');
    final claim = (await l.adventures.claim(cur.id))!;
    expect(claim.discoveryKey, isNotNull);
    expect((await l.wallet.balance()).coins, claim.coins);

    // 3b. a daily quest pays coins once
    final before = (await l.wallet.balance()).coins;
    expect((await l.quests.claim('daily_claim', special: false)).status, ClaimStatus.claimed);
    expect((await l.wallet.balance()).coins, before + l.config.questsDailyRewardCoins);

    // 4. buy an item from today's rotating stock (top up so the test does not depend on the reward roll)
    await l.wallet.grant(Currency.coins, 900, 'promo', 'e2e-coins');
    final stock = await l.shop.stock('outfit');
    expect(stock, isNotEmpty);
    final pick = stock.firstWhere((i) => !i.premiumOnly);
    expect(await l.shop.buy(pick.itemKey, isPremium: false), BuyStatus.bought);

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
