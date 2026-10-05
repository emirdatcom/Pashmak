import '../../goals/domain/goal_recommender.dart' show stableHash;

enum QuestState { inProgress, ready, claimed }

/// A quest definition (`quests_daily` / `quests_special` entry).
class QuestDef {
  const QuestDef({required this.key, required this.titleKey, required this.metric, required this.target, required this.route, this.hintKey, this.rewardCoins, this.fixed = false});
  factory QuestDef.fromJson(Map<String, dynamic> j) => QuestDef(
        key: j['key'] as String,
        titleKey: j['title_key'] as String,
        metric: j['metric'] as String,
        target: j['target'] as int,
        route: j['route'] as String,
        hintKey: j['hint_key'] as String?,
        rewardCoins: j['reward_coins'] as int?,
        fixed: (j['fixed'] as bool?) ?? false,
      );
  final String key, titleKey, metric, route;
  final String? hintKey;
  final int target;
  final int? rewardCoins; // null = daily reward from config
  final bool fixed;
}

class QuestView {
  const QuestView({required this.def, required this.progress, required this.state});
  final QuestDef def;
  final int progress;
  final QuestState state;
  int get shown => progress > def.target ? def.target : progress;
}

/// Pure quest logic (docs/22 §10): which daily quests a day gets, and the state of a quest given local metrics.
class QuestEngine {
  const QuestEngine();

  /// The `claim` metric is always satisfied: the first daily quest only needs a tap.
  static const claimMetric = 'claim';

  /// Daily quests for [localDay]: fixed ones first, then a deterministic pick from the pool. Pause mode generates none.
  List<String> selectDaily(List<QuestDef> pool, {required int count, required String localDay, required int seed, bool paused = false}) {
    if (paused) return const [];
    final fixed = pool.where((q) => q.fixed).map((q) => q.key).toList();
    final rest = pool.where((q) => !q.fixed).toList()
      ..sort((a, b) => stableHash('$seed:$localDay:${a.key}').compareTo(stableHash('$seed:$localDay:${b.key}')));
    return [...fixed, ...rest.map((q) => q.key)].take(count).toList();
  }

  QuestView evaluate(QuestDef q, Map<String, int> metrics, {required bool claimed}) {
    final progress = q.metric == claimMetric ? q.target : (metrics[q.metric] ?? 0);
    final state = claimed ? QuestState.claimed : (progress >= q.target ? QuestState.ready : QuestState.inProgress);
    return QuestView(def: q, progress: progress, state: state);
  }
}
