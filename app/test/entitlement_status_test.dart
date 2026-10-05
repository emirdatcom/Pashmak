import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/entitlement/entitlement_repository.dart';

DateTime t(int d, [int h = 8]) => DateTime.utc(2026, 10, d, h);
String iso(DateTime d) => d.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');

EntitlementState state({List<(String, DateTime, DateTime)> entries = const [], DateTime? serverTime, DateTime? validUntil, int grace = 3}) {
  final st = serverTime ?? t(5);
  final ends = entries.isEmpty ? st : entries.map((e) => e.$3).reduce((a, b) => a.isAfter(b) ? a : b);
  final cap = st.add(const Duration(days: 7));
  return EntitlementState({
    'entitlements': [for (final e in entries) {'key': 'premium', 'source': e.$1, 'starts_at': iso(e.$2), 'ends_at': iso(e.$3)}],
    'trial': {'eligible': false, 'used': true, 'ends_at': null},
    'server_time': iso(st),
    'valid_until': iso(validUntil ?? (ends.isBefore(cap) ? ends : cap)),
    'grace_days': grace,
  });
}

void main() {
  final pass = state(entries: [('pass', t(5), t(5).add(const Duration(days: 90)))]);

  test('active entitlement inside the validity window is premium', () {
    final s = EntitlementSnapshot(state: pass);
    final r = evaluatePremium(s, t(6));
    expect((r.isPremium, r.source, r.provisional), (true, 'pass', false));
    expect(r.endsAt, t(5).add(const Duration(days: 90)));
  });

  test('offline cache: premium until valid_until (fetch + 7 days), then grace (3 days), then free', () {
    final s = EntitlementSnapshot(state: pass);
    expect(evaluatePremium(s, t(12, 7)).isPremium, isTrue, reason: 'just before valid_until');
    final g = evaluatePremium(s, t(13)); // 8 days after the fetch: valid_until passed
    expect((g.isPremium, g.inGrace), (true, true));
    expect(evaluatePremium(s, t(15, 7)).isPremium, isTrue, reason: 'still inside the 3-day grace');
    expect(evaluatePremium(s, t(15, 9)).isPremium, isFalse, reason: 'after valid_until + grace');
  });

  test('no entitlements in the signed state means free, with no grace', () {
    expect(evaluatePremium(EntitlementSnapshot(state: state()), t(5, 9)).isPremium, isFalse);
  });

  test('entitlement not started yet or already ended is not premium', () {
    final future = state(entries: [('pass', t(8), t(20))]);
    expect(evaluatePremium(EntitlementSnapshot(state: future), t(6)).isPremium, isFalse);
    expect(evaluatePremium(EntitlementSnapshot(state: future), t(9)).isPremium, isTrue, reason: 'queued pass started');
  });

  test('device clock drift is corrected with the server time', () {
    // Device clock is 2 days ahead of the server; after the entitlement ended on the server it must not stay premium.
    final st = state(entries: [('pass', t(1), t(6))], serverTime: t(5));
    final ahead = EntitlementSnapshot(state: st, drift: const Duration(days: -2));
    expect(evaluatePremium(ahead, t(7)).isPremium, isTrue, reason: 'device says Oct 7 = server Oct 5');
    expect(evaluatePremium(const EntitlementSnapshot(state: null), t(7)).isPremium, isFalse);
    // A device clock rolled far forward cannot extend beyond valid_until + grace.
    final far = EntitlementSnapshot(state: pass);
    expect(evaluatePremium(far, t(5).add(const Duration(days: 60))).isPremium, isFalse);
  });

  test('pending verification keeps premium for the window, then it lapses', () {
    final s = EntitlementSnapshot(pendingUntil: t(5, 8).add(const Duration(hours: 72)));
    final r = evaluatePremium(s, t(7));
    expect((r.isPremium, r.source, r.provisional), (true, 'pending', true));
    expect(evaluatePremium(s, t(8, 9)).isPremium, isFalse);
  });

  test('offline trial: premium for trial.days from the local start, until the server answers', () {
    final s = EntitlementSnapshot(provisionalTrialStart: t(5), trialDays: 7);
    expect(evaluatePremium(s, t(11)).isPremium, isTrue);
    expect(evaluatePremium(s, t(12, 9)).isPremium, isFalse);
    expect(evaluatePremium(s, t(11)).provisional, isTrue);
  });

  test('TRIAL_ALREADY_USED keeps premium until the end of that day only', () {
    final s = EntitlementSnapshot(trialUsedUntil: DateTime.utc(2026, 10, 5, 23, 59));
    expect(evaluatePremium(s, t(5, 20)).isPremium, isTrue);
    expect(evaluatePremium(s, t(6, 1)).isPremium, isFalse);
  });
}
