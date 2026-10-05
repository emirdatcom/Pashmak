import '../../../core/config/app_config.dart';

/// One entry of the `goal_library` pack.
class GoalDef {
  const GoalDef({
    required this.key,
    required this.titleKey,
    required this.icon,
    required this.areaKey,
    required this.tabs,
    required this.difficulty,
    required this.minutes,
    required this.defaultTimeOfDay,
    required this.defaultRepeat,
    required this.needTags,
  });
  factory GoalDef.fromJson(Map<String, dynamic> j) => GoalDef(
        key: j['key'] as String,
        titleKey: j['title_key'] as String,
        icon: j['icon'] as String,
        areaKey: j['area_key'] as String,
        tabs: (j['tabs'] as List).cast<String>(),
        difficulty: j['difficulty'] as int,
        minutes: j['minutes'] as int,
        defaultTimeOfDay: j['default_time_of_day'] as String,
        defaultRepeat: j['default_repeat'] as String,
        needTags: (j['need_tags'] as List).cast<String>(),
      );
  final String key, titleKey, icon, areaKey, defaultTimeOfDay, defaultRepeat;
  final List<String> tabs, needTags;
  final int difficulty, minutes;

  /// `daily` | `once` | `weekly` (for `weekdays:…`).
  String get repeatType => defaultRepeat.startsWith('weekdays') ? 'weekly' : defaultRepeat;

  /// Weekday mask (bit0 = Saturday … bit6 = Friday) of `weekdays:0,2`; 127 otherwise.
  int get weekdaysMask {
    if (!defaultRepeat.startsWith('weekdays:')) return 127;
    var m = 0;
    for (final d in defaultRepeat.substring('weekdays:'.length).split(',')) {
      m |= 1 << int.parse(d);
    }
    return m;
  }
}

enum Chronotype { morning, night, flexible }

enum AreaAnswer { rarely, sometimes, often }

enum DailyTime { five, fifteen, more }

/// Answers of the onboarding questionnaire (docs/22 §5). All optional: skipped steps use neutral defaults.
class OnboardingProfile {
  const OnboardingProfile({
    this.energyLevel = 3,
    this.areas = const [],
    this.areaAnswers = const {},
    this.chronotype = Chronotype.flexible,
    this.dailyTime = DailyTime.fifteen,
  });
  final int energyLevel; // 1..5
  final List<String> areas;
  final Map<String, AreaAnswer> areaAnswers;
  final Chronotype chronotype;
  final DailyTime dailyTime;
}

/// FNV-1a over [s]; stable across runs and platforms (seeds for recommender/shop rotation).
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Pure goal recommendation (docs/22 §7). No clock, no I/O: the same inputs and seed give the same output.
class GoalRecommender {
  GoalRecommender({required this.goals, this.weights = const RecommenderWeights()});

  final List<GoalDef> goals;
  final RecommenderWeights weights;

  int need(OnboardingProfile p, String area) {
    final a = p.areaAnswers[area];
    return (p.areas.contains(area) ? weights.areaSelected : 0) +
        switch (a) {
          AreaAnswer.rarely => weights.answerRarely,
          AreaAnswer.sometimes => weights.answerSometimes,
          _ => 0,
        };
  }

  int maxDifficulty(OnboardingProfile p) {
    final byEnergy = p.energyLevel <= 2 ? 1 : (p.energyLevel == 3 ? 2 : 3);
    return p.dailyTime == DailyTime.five ? (byEnergy < 1 ? byEnergy : 1) : byEnergy;
  }

  /// Tags the user's answers raise: `low_<area>` for "rarely", `mid_<area>` for "sometimes".
  Set<String> answerTags(OnboardingProfile p) => {
        for (final e in p.areaAnswers.entries)
          if (e.value == AreaAnswer.rarely) 'low_${e.key}' else if (e.value == AreaAnswer.sometimes) 'mid_${e.key}',
      };

  /// `any` goals follow the chronotype; the others keep their own default.
  String resolvedTimeOfDay(GoalDef g, Chronotype c) {
    if (g.defaultTimeOfDay != 'any') return g.defaultTimeOfDay;
    return switch (c) { Chronotype.morning => 'morning', Chronotype.night => 'evening', Chronotype.flexible => 'any' };
  }

  bool _matchesChronotype(GoalDef g, Chronotype c) =>
      (g.defaultTimeOfDay == 'morning' && c == Chronotype.morning) || (g.defaultTimeOfDay == 'evening' && c == Chronotype.night);

  int _score(OnboardingProfile p, GoalDef g, Set<String> tags, int seed) {
    final n = need(p, g.areaKey);
    final matches = g.needTags.where(tags.contains).length;
    // The tie-break is below one point, so it never outweighs a real score difference.
    return (n * weights.needWeight + matches * weights.tagWeight - g.difficulty * weights.difficultyPenalty +
                (_matchesChronotype(g, p.chronotype) ? weights.chronotypeBonus : 0)) *
            1000 +
        (stableHash('$seed:${g.key}') % 1000);
  }

  /// [count] goals for the plan preview. [exclude] holds goals the user already has.
  List<GoalDef> recommend(OnboardingProfile p, {required int count, required int seed, Set<String> exclude = const {}}) {
    final maxD = maxDifficulty(p);
    final tags = answerTags(p);
    final pool = goals.where((g) => g.difficulty <= maxD && !exclude.contains(g.key)).toList();
    final picked = <GoalDef>[];
    final areas = [...p.areas]..sort((a, b) => need(p, b).compareTo(need(p, a)));
    var progressed = true;
    while (picked.length < count && areas.isNotEmpty && progressed) {
      progressed = false;
      for (final a in areas) {
        if (picked.length >= count) break;
        final cand = pool.where((g) => g.areaKey == a && !picked.contains(g)).toList()
          ..sort((x, y) => _score(p, y, tags, seed).compareTo(_score(p, x, tags, seed)));
        if (cand.isNotEmpty) {
          picked.add(cand.first);
          progressed = true;
        }
      }
    }
    _fillEasyWins(picked, pool, count, seed);
    _ensureEasyWin(picked, pool, seed);
    return picked;
  }

  void _fillEasyWins(List<GoalDef> picked, List<GoalDef> pool, int count, int seed) {
    final easy = pool.where((g) => g.difficulty == 1 && g.tabs.contains('easy_wins') && !picked.contains(g)).toList()
      ..sort((a, b) => stableHash('$seed:${a.key}').compareTo(stableHash('$seed:${b.key}')));
    for (final g in easy) {
      if (picked.length >= count) break;
      picked.add(g);
    }
  }

  /// There is always at least one difficulty-1 "easy win" in the result.
  void _ensureEasyWin(List<GoalDef> picked, List<GoalDef> pool, int seed) {
    if (picked.isEmpty || picked.any((g) => g.difficulty == 1)) return;
    final easy = pool.where((g) => g.difficulty == 1 && !picked.contains(g)).toList()
      ..sort((a, b) => stableHash('$seed:${a.key}').compareTo(stableHash('$seed:${b.key}')));
    if (easy.isNotEmpty) picked[picked.length - 1] = easy.first;
  }

  /// "Suggest another" for the goal at [index]: the best unused goal, preferring the same area. Never returns
  /// a goal that is already in [current], in [exclude] or in [rejected].
  GoalDef? replacement(OnboardingProfile p, List<GoalDef> current, int index,
      {required int seed, Set<String> exclude = const {}, Set<String> rejected = const {}}) {
    final maxD = maxDifficulty(p);
    final tags = answerTags(p);
    final taken = {...exclude, ...rejected, for (final g in current) g.key};
    final pool = goals.where((g) => g.difficulty <= maxD && !taken.contains(g.key)).toList();
    if (pool.isEmpty) return null;
    final area = current[index].areaKey;
    pool.sort((a, b) {
      final sameA = a.areaKey == area ? 1 : 0, sameB = b.areaKey == area ? 1 : 0;
      if (sameA != sameB) return sameB.compareTo(sameA);
      return _score(p, b, tags, seed).compareTo(_score(p, a, tags, seed));
    });
    return pool.first;
  }

  /// Suggestions for the "suggested" tab of the goal editor (existing goals removed).
  List<GoalDef> suggestedTab(OnboardingProfile p, {required int seed, required Set<String> existing, int count = 12}) =>
      recommend(p, count: count, seed: seed, exclude: existing);
}
