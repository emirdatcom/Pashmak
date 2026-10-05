import 'dart:async';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/time/clock.dart';
import '../../../core/widgets/cat_renderer.dart';
import '../../goals/domain/goal_recommender.dart';
import '../../habits/domain/habit_service.dart';
import 'onboarding_answers.dart';

enum NameCheck { ok, empty, tooLong, blocked }

/// Cat-name rules (docs/20 §6): 1..16 characters after trimming, no blocklisted word.
NameCheck checkCatName(String raw, Iterable<String> blocklist) {
  final name = raw.trim();
  if (name.isEmpty) return NameCheck.empty;
  if (name.runes.length > 16) return NameCheck.tooLong;
  final n = normalizePersianText(name).toLowerCase();
  for (final w in blocklist) {
    final b = normalizePersianText(w).toLowerCase();
    if (b.isNotEmpty && n.contains(b)) return NameCheck.blocked;
  }
  return NameCheck.ok;
}

/// A goal of the plan preview with its resolved time of day.
class PlannedGoal {
  const PlannedGoal(this.def, this.timeOfDay);
  final GoalDef def;
  final String timeOfDay;
}

/// Snake-case key of a fur option (copy keys `onboarding.fur.*`).
String furKey(CatFur f) => switch (f) { CatFur.orangeCream => 'orange_cream', CatFur.smokeGray => 'smoke_gray', CatFur.tricolor => 'tricolor' };

/// Persists onboarding progress so a killed app resumes at the same step (docs/20 §4, docs/22 §5).
class OnboardingService {
  OnboardingService(this._db, this._habits, this._analytics, this._clock, {required this.defaultCatName}) : answers = OnboardingAnswers(_db);

  final AppDatabase _db;
  final HabitService _habits;
  final AnalyticsService _analytics;
  final Clock _clock;
  final String defaultCatName;
  final OnboardingAnswers answers;

  static const totalSteps = 11;
  static const _kStep = 'onboarding_step';

  Future<int> currentStep() async => (int.tryParse(await _db.meta(_kStep) ?? '') ?? 1).clamp(1, totalSteps);
  Future<void> setStep(int step) => _db.setMeta(_kStep, '${step.clamp(1, totalSteps)}');

  /// First run only.
  Future<void> trackInstallOnce() async {
    if (await _db.meta('install_tracked') == 'true') return;
    await _db.setMeta('install_tracked', 'true');
    unawaited(_analytics.track(AnalyticsEvent.appInstalled));
  }

  Future<void> trackStep(int step) => _analytics.track(AnalyticsEvent.onboardingStepViewed, {'step': step});

  /// Stores the (already validated) name; an empty value keeps the default.
  Future<void> saveCatName(String raw) => _db.setMeta('cat_name', raw.trim() == defaultCatName ? '' : raw.trim());

  Future<String> savedCatName() async => await _db.meta('cat_name') ?? '';

  Future<void> saveUserName(String raw) => _db.setMeta('user_name', raw.trim());

  Future<void> saveCatLook({required CatFur fur, required String trait}) async {
    await _db.setMeta('cat_fur', fur.name);
    await _db.setMeta('cat_trait', trait);
  }

  /// The plan preview selection (goal keys in order), kept so a restart keeps the choice.
  Future<void> saveGoalSelection(List<String> keys) => _db.setMeta('onboarding_goals', keys.join(','));

  Future<List<String>> loadGoalSelection() async => (await _db.meta('onboarding_goals') ?? '').split(',').where((s) => s.isNotEmpty).toList();

  /// How many goals the preview should offer: free users are capped by the free limit (docs/22 §7).
  int recommendCount({required bool premiumOrTrial, required int free, required int trial, required int freeActiveLimit}) =>
      premiumOrTrial ? trial : (free < freeActiveLimit ? free : freeActiveLimit);

  /// Creates the chosen goals and finishes onboarding. Returns the number of goals created.
  Future<int> complete({
    required List<PlannedGoal> goals,
    required bool notifPermission,
    required bool catNameChanged,
    required OnboardingProfile profile,
    int replacedCount = 0,
  }) async {
    var n = 0;
    for (final g in goals) {
      await _habits.create(HabitDraft(
        templateKey: g.def.key,
        icon: g.def.icon,
        areaKey: g.def.areaKey,
        timeOfDay: g.timeOfDay,
        repeatType: g.def.repeatType == 'once' ? 'daily' : g.def.repeatType,
        scheduleType: g.def.repeatType == 'weekly' ? 'weekly' : 'daily',
        weekdaysMask: g.def.weekdaysMask,
        source: 'suggested',
      ));
      n++;
    }
    await _db.setMeta('onboarding_completed', 'true');
    await _db.setMeta('onboarding_goals', '');
    await _db.setMeta('cat_arrived_at', '${_clock.now().millisecondsSinceEpoch}');
    unawaited(_analytics.track(AnalyticsEvent.goalRecommendedAccepted, {'accepted_count': n, 'replaced_count': replacedCount}));
    unawaited(_analytics.track(AnalyticsEvent.onboardingCompleted, {
      'habits_selected_count': n,
      'notif_permission': notifPermission ? 'granted' : 'denied',
      'cat_name_changed': catNameChanged,
    }));
    return n;
  }

  /// Counts and area keys only: never the answers or the energy level (docs/22 §5).
  Future<void> trackAreas(List<String> areas) =>
      _analytics.track(AnalyticsEvent.onboardingAreasSelected, {'areas_count': areas.length, 'area_keys': areas.join(',')});
}
