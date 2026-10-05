import '../db/app_database.dart';
import '../time/clock.dart';
import 'paywall_policy.dart';

enum GateDecision {
  /// The user may proceed (premium, trigger disabled remotely, or nothing to gate).
  allow,

  /// Navigate to `/paywall?trigger=...`.
  showPaywall,

  /// A paywall would be inappropriate right now (docs/60 §5); the UI shows a gentle message instead.
  suppressed,
}

/// Where the user currently is; forbidden contexts never show a paywall.
class GateContext {
  const GateContext({this.inExercise = false, this.onSafetyScreen = false, this.lowMoodThisSession = false, this.onboardingCompleted = true});
  final bool inExercise;
  final bool onSafetyScreen;

  /// A check-in with mood_level <= 2 happened in this session.
  final bool lowMoodThisSession;
  final bool onboardingCompleted;
}

/// Decides whether a premium-only action leads to the paywall (docs/60 §5).
class PremiumGate {
  PremiumGate(this._db, this._clock, {required this.cooldownHours, required this.triggerEnabled});

  final AppDatabase _db;
  final Clock _clock;
  final int Function() cooldownHours;
  final bool Function(String trigger) triggerEnabled;

  static const _kLastShown = 'paywall_last_shown_at';

  /// [userInitiated]: the user tapped something premium (always allowed to see the paywall unless a
  /// forbidden context applies). Automatic paywalls also respect `paywall.cooldown_hours`.
  Future<GateDecision> evaluate(String trigger, {required bool isPremium, GateContext context = const GateContext(), bool userInitiated = true}) async {
    final last = userInitiated ? null : int.tryParse(await _db.meta(_kLastShown) ?? '');
    return PaywallPolicy.decide(
      trigger: trigger,
      isPremium: isPremium,
      triggerEnabled: triggerEnabled(trigger),
      context: context,
      userInitiated: userInitiated,
      lastShown: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
      now: _clock.now(),
      cooldownHours: cooldownHours(),
    );
  }

  Future<void> markShown() => _db.setMeta(_kLastShown, '${_clock.now().millisecondsSinceEpoch}');
}
