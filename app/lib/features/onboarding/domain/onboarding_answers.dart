import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../goals/domain/goal_recommender.dart';

/// Local store of the questionnaire answers (`onboarding_answers`, never synced or sent to analytics; docs/22 §5).
class OnboardingAnswers {
  OnboardingAnswers(this._db);
  final AppDatabase _db;

  Future<String?> _get(String key) async => (await (_db.select(_db.onboardingAnswers)..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _set(String key, String value) =>
      _db.into(_db.onboardingAnswers).insertOnConflictUpdate(OnboardingAnswersCompanion.insert(key: key, value: value));

  Future<void> save(OnboardingProfile p) async {
    await _set('energy_level', '${p.energyLevel}');
    await _set('areas', p.areas.join(','));
    await _set('area_answers', jsonEncode({for (final e in p.areaAnswers.entries) e.key: e.value.name}));
    await _set('chronotype', p.chronotype.name);
    await _set('daily_time', p.dailyTime.name);
  }

  /// Neutral defaults for skipped steps.
  Future<OnboardingProfile> load() async {
    final areas = (await _get('areas') ?? '').split(',').where((s) => s.isNotEmpty).toList();
    final raw = jsonDecode(await _get('area_answers') ?? '{}') as Map<String, dynamic>;
    return OnboardingProfile(
      energyLevel: (int.tryParse(await _get('energy_level') ?? '') ?? 3).clamp(1, 5),
      areas: areas,
      areaAnswers: {
        for (final e in raw.entries)
          if (AreaAnswer.values.any((a) => a.name == e.value)) e.key: AreaAnswer.values.firstWhere((a) => a.name == e.value),
      },
      chronotype: await _chrono(),
      dailyTime: await _time(),
    );
  }

  Future<Chronotype> _chrono() async {
    final v = await _get('chronotype');
    return Chronotype.values.where((c) => c.name == v).firstOrNull ?? Chronotype.flexible;
  }

  Future<DailyTime> _time() async {
    final v = await _get('daily_time');
    return DailyTime.values.where((c) => c.name == v).firstOrNull ?? DailyTime.fifteen;
  }

  Future<void> clear() => _db.delete(_db.onboardingAnswers).go();
}
