import 'dart:async';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/digits.dart';
import '../../habits/domain/habit_service.dart';

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

/// Persists onboarding progress so a killed app resumes at the same step (docs/20 §4).
class OnboardingService {
  OnboardingService(this._db, this._habits, this._analytics, {required this.defaultCatName});

  final AppDatabase _db;
  final HabitService _habits;
  final AnalyticsService _analytics;
  final String defaultCatName;

  static const maxHabits = 3;
  static const _kStep = 'onboarding_step';

  Future<int> currentStep() async => (int.tryParse(await _db.meta(_kStep) ?? '') ?? 1).clamp(1, 4);
  Future<void> setStep(int step) => _db.setMeta(_kStep, '${step.clamp(1, 4)}');

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

  /// Step 3 selection, kept so a restart keeps the choice.
  Future<void> saveSelection(Map<String, int?> reminderByTemplate) => _db.setMeta('onboarding_habits', reminderByTemplate.entries.map((e) => '${e.key}:${e.value ?? ''}').join(','));

  Future<Map<String, int?>> loadSelection() async {
    final raw = await _db.meta('onboarding_habits') ?? '';
    return {
      for (final part in raw.split(',').where((s) => s.isNotEmpty)) part.split(':').first: int.tryParse(part.split(':').length > 1 ? part.split(':')[1] : ''),
    };
  }

  /// Creates the chosen habits (≤ 3, template-based so they are inside the free limit) and finishes onboarding.
  /// Returns the number of habits created.
  Future<int> complete({required Map<String, int?> habits, required bool notifPermission, required bool catNameChanged}) async {
    var n = 0;
    for (final e in habits.entries.take(maxHabits)) {
      await _habits.create(HabitDraft(templateKey: e.key, reminderMinutes: e.value));
      n++;
    }
    await _db.setMeta('onboarding_completed', 'true');
    await _db.setMeta('onboarding_habits', '');
    unawaited(_analytics.track(AnalyticsEvent.onboardingCompleted, {
      'habits_selected_count': n,
      'notif_permission': notifPermission ? 'granted' : 'denied',
      'cat_name_changed': catNameChanged,
    }));
    return n;
  }
}
