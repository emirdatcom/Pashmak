import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../../core/time/local_day.dart';
import '../../wallet/domain/wallet_service.dart';

/// A multi-day program. Each day has a tip (copy `journey.<key>.day.<n>.tip`) and steps:
/// `ex:<exercise key>`, `journal:<template>` or `sound:<preset>`. Copy: `journey.<key>.name|desc|day.<n>.title`.
class Journey {
  const Journey(this.key, this.icon, this.days, {this.premium = false});
  final String key;
  final String icon;
  final List<List<String>> days;
  final bool premium;

  static const all = [
    Journey('calm_start', 'calm/meditation', [['ex:breathing_basic'], ['ex:ground_feet', 'journal:gratitude'], ['journal:talk'], ['ex:sleep_wind_down', 'sound:rainy_night'], ['journal:gratitude', 'ex:joy_list']]),
    Journey('self_kindness', 'hearts/sparkling_heart', [['ex:self_compassion'], ['ex:body_thanks', 'ex:body_scan'], ['ex:mistake_learning'], ['ex:proud_moment'], ['ex:boundaries'], ['ex:joy_list'], ['ex:future_self', 'journal:gratitude']], premium: true),
    Journey('better_sleep', 'time/bedtime', [['ex:timer_sunlight'], ['ex:sleep_wind_down'], ['ex:muscle_relax', 'ex:stretch_bedtime'], ['ex:timer_read'], ['ex:breathing_count_down', 'sound:summer_night'], ['sound:cat_nap', 'ex:breathing_ocean'], ['ex:week_review']], premium: true),
    Journey('less_worry', 'misc/hourglass', [['ex:breathing_sigh', 'journal:worry'], ['ex:ground_54321'], ['journal:reframe'], ['journal:worry', 'ex:ground_safe_place'], ['ex:values_check'], ['ex:move_shake', 'ex:move_mindful_walk'], ['ex:what_helped']], premium: true),
    Journey('energy_up', 'ui/bolt', [['ex:timer_water', 'ex:timer_sunlight'], ['ex:stretch_morning', 'ex:breathing_energy'], ['ex:energy_givers'], ['ex:timer_tidy'], ['ex:joy_list', 'journal:highlight']], premium: true),
    Journey('focus_flow', 'misc/target', [['ex:thoughts_dump', 'ex:breathing_triangle'], ['ex:focus_timer'], ['ex:move_eye_rest', 'ex:move_posture'], ['ex:timer_phone_free'], ['ex:reflect_afternoon']], premium: true),
  ];

  static Journey byKey(String key) => all.firstWhere((j) => j.key == key);
}

/// Where the user is in a journey. A day opens once the previous one was finished on an earlier calendar day
/// (one day per day, like a real program).
class JourneyProgress {
  const JourneyProgress({required this.journey, this.started, this.done = const {}, this.completedOn = const {}});
  final Journey journey;
  final String? started;
  final Map<int, Set<int>> done; // day index -> finished step indices
  final Map<int, String> completedOn; // day index -> LocalDay.value

  bool get isStarted => started != null;
  int get daysDone => completedOn.length;
  bool get finished => daysDone >= journey.days.length;

  /// The first day not finished yet (null when the journey is finished).
  int? get currentDay => finished ? null : List.generate(journey.days.length, (i) => i).firstWhere((i) => !completedOn.containsKey(i));

  /// Whether [day] can be worked on [today].
  bool isOpen(int day, LocalDay today) {
    if (!isStarted || day != currentDay) return false;
    if (day == 0) return true;
    final prev = completedOn[day - 1];
    return prev != null && prev.compareTo(today.value) < 0;
  }

  bool stepDone(int day, int step) => done[day]?.contains(step) ?? false;
}

/// Journey progress in app_meta (`journey:<key>`, part of the backup). Finishing a journey pays [rewardCoins] once
/// per run.
class JourneyService {
  JourneyService(this._db, this._wallet, {required this.today, this.rewardCoins = 30});
  final AppDatabase _db;
  final WalletService _wallet;
  final LocalDay Function() today;
  final int rewardCoins;

  static const prefix = 'journey:';

  Future<JourneyProgress> progress(Journey j) async {
    final raw = await _db.meta('$prefix${j.key}');
    if (raw == null || raw.isEmpty) return JourneyProgress(journey: j);
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return JourneyProgress(
      journey: j,
      started: m['started'] as String?,
      done: {for (final e in ((m['done'] as Map?) ?? const {}).entries) int.parse(e.key as String): {for (final s in e.value as List) s as int}},
      completedOn: {for (final e in ((m['completed'] as Map?) ?? const {}).entries) int.parse(e.key as String): e.value as String},
    );
  }

  Future<void> _save(JourneyProgress p) => _db.setMeta('$prefix${p.journey.key}', jsonEncode({
        'started': p.started,
        'done': {for (final e in p.done.entries) '${e.key}': e.value.toList()..sort()},
        'completed': {for (final e in p.completedOn.entries) '${e.key}': e.value},
      }));

  /// Starts (or restarts) [j] today.
  Future<JourneyProgress> start(Journey j) async {
    final p = JourneyProgress(journey: j, started: today().value);
    await _save(p);
    return p;
  }

  /// Marks a step of the open day; finishing the day records it, finishing the last day pays the reward.
  /// Returns the new progress (unchanged when the day is not open).
  Future<JourneyProgress> completeStep(Journey j, int day, int step) async {
    final p = await progress(j);
    final t = today();
    if (!p.isOpen(day, t) || step < 0 || step >= j.days[day].length) return p;
    final done = {for (final e in p.done.entries) e.key: {...e.value}};
    (done[day] ??= {}).add(step);
    final completed = {...p.completedOn};
    if (done[day]!.length == j.days[day].length) completed[day] = t.value;
    final next = JourneyProgress(journey: j, started: p.started, done: done, completedOn: completed);
    await _save(next);
    if (next.finished) await _wallet.grant(Currency.coins, rewardCoins, 'journey_done', '${j.key}:${p.started}');
    return next;
  }
}
