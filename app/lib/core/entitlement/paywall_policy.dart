import 'premium_gate.dart';

/// Pure paywall decision (docs/60 §5): no I/O, so every rule is table-testable.
class PaywallPolicy {
  const PaywallPolicy._();

  static GateDecision decide({
    required String trigger,
    required bool isPremium,
    required bool triggerEnabled,
    required GateContext context,
    bool userInitiated = true,
    DateTime? lastShown,
    DateTime? now,
    int cooldownHours = 24,
  }) {
    if (isPremium || !triggerEnabled) return GateDecision.allow;
    if (context.inExercise || context.onSafetyScreen || context.lowMoodThisSession) return GateDecision.suppressed;
    if (!context.onboardingCompleted && trigger != 'trial_offer') return GateDecision.suppressed;
    if (!userInitiated && lastShown != null && now != null && now.difference(lastShown) < Duration(hours: cooldownHours)) {
      return GateDecision.suppressed;
    }
    return GateDecision.showPaywall;
  }

  /// "% cheaper than monthly": (monthly * months - price) / (monthly * months), floored; null if not a saving.
  static int? savingPercent({required int price, required int months, required int monthlyPrice}) {
    if (months <= 1 || monthlyPrice <= 0) return null;
    final full = monthlyPrice * months;
    final pct = ((full - price) * 100 / full).floor();
    return pct > 0 ? pct : null;
  }
}
