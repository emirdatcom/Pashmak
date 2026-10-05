import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/config/app_config.dart';
import 'package:pashmak_app/features/goals/domain/goal_recommender.dart';

List<GoalDef> _library() {
  final doc = jsonDecode(File('assets/content/goal_library.json').readAsStringSync()) as Map<String, dynamic>;
  return (doc['entries'] as List).cast<Map<String, dynamic>>().map(GoalDef.fromJson).toList();
}

void main() {
  final goals = _library();
  final rec = GoalRecommender(goals: goals, weights: const RecommenderWeights());
  const seed = 1234;

  test('library has at least 80 goals across 8 areas', () {
    expect(goals.length, greaterThanOrEqualTo(80));
    expect(goals.map((g) => g.areaKey).toSet().length, 8);
  });

  test('low energy + rarely: all picks are difficulty 1 and cover both chosen areas', () {
    const p = OnboardingProfile(
      energyLevel: 2,
      areas: ['sleep', 'calm'],
      areaAnswers: {'sleep': AreaAnswer.rarely, 'calm': AreaAnswer.rarely},
    );
    final out = rec.recommend(p, count: 3, seed: seed);
    expect(out.length, 3);
    expect(out.every((g) => g.difficulty == 1), isTrue);
    expect(out.map((g) => g.areaKey).toSet(), containsAll(['sleep', 'calm']));
  });

  test('difficulty ceiling follows energy and still includes an easy win', () {
    expect(rec.maxDifficulty(const OnboardingProfile(energyLevel: 1)), 1);
    expect(rec.maxDifficulty(const OnboardingProfile(energyLevel: 3)), 2);
    expect(rec.maxDifficulty(const OnboardingProfile(energyLevel: 5)), 3);
    const p = OnboardingProfile(energyLevel: 5, areas: ['movement', 'focus'], areaAnswers: {'movement': AreaAnswer.often});
    final out = rec.recommend(p, count: 4, seed: seed);
    expect(out.any((g) => g.difficulty == 1), isTrue);
    expect(out.length, 4);
  });

  test('5 minutes a day caps difficulty at 1', () {
    const p = OnboardingProfile(energyLevel: 5, dailyTime: DailyTime.five, areas: ['movement']);
    expect(rec.recommend(p, count: 3, seed: seed).every((g) => g.difficulty == 1), isTrue);
  });

  test('deterministic for the same seed, different for another', () {
    const p = OnboardingProfile(areas: ['home', 'connection'], areaAnswers: {'home': AreaAnswer.sometimes});
    expect(rec.recommend(p, count: 3, seed: seed).map((g) => g.key), rec.recommend(p, count: 3, seed: seed).map((g) => g.key));
  });

  test('no areas chosen: falls back to easy wins', () {
    final out = rec.recommend(const OnboardingProfile(), count: 3, seed: seed);
    expect(out.length, 3);
    expect(out.every((g) => g.difficulty == 1), isTrue);
  });

  test('existing goals are excluded', () {
    const p = OnboardingProfile(areas: ['sleep']);
    final first = rec.recommend(p, count: 3, seed: seed);
    final again = rec.recommend(p, count: 3, seed: seed, exclude: {first.first.key});
    expect(again.map((g) => g.key), isNot(contains(first.first.key)));
  });

  test('"suggest another" never repeats a current, existing or rejected goal', () {
    const p = OnboardingProfile(areas: ['sleep', 'calm'], areaAnswers: {'sleep': AreaAnswer.rarely});
    var current = rec.recommend(p, count: 3, seed: seed);
    final seen = <String>{...current.map((g) => g.key)};
    for (var i = 0; i < 20; i++) {
      final r = rec.replacement(p, current, 0, seed: seed, exclude: {'home_bed_make'}, rejected: seen);
      expect(r, isNotNull);
      expect(seen.contains(r!.key), isFalse);
      expect(r.key, isNot('home_bed_make'));
      seen.add(r.key);
      current = [r, ...current.skip(1)];
    }
  });

  test('time of day follows the chronotype for "any" goals', () {
    final any = goals.firstWhere((g) => g.defaultTimeOfDay == 'any');
    expect(rec.resolvedTimeOfDay(any, Chronotype.morning), 'morning');
    expect(rec.resolvedTimeOfDay(any, Chronotype.night), 'evening');
    expect(rec.resolvedTimeOfDay(any, Chronotype.flexible), 'any');
  });

  test('weekday repeat parses to a mask', () {
    final g = goals.firstWhere((x) => x.defaultRepeat == 'weekdays:0,2,4');
    expect(g.weekdaysMask, 1 | 4 | 16);
    expect(g.repeatType, 'weekly');
  });
}
