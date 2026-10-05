import 'package:collection/collection.dart';

/// Typed view over the remote config payload (docs/20 §5, backend schema config.schema.json).
/// Every key has a bundled default, so getters never return null.
class AppConfig {
  AppConfig(this.raw);

  final Map<String, dynamic> raw;

  /// Deep-merges [override] onto [base]: objects merge, everything else (incl. arrays) is replaced.
  static Map<String, dynamic> merge(Map<String, dynamic> base, Map<String, dynamic> override) {
    final out = <String, dynamic>{...base};
    override.forEach((k, v) {
      final b = out[k];
      out[k] = (b is Map<String, dynamic> && v is Map<String, dynamic>) ? merge(b, v) : v;
    });
    return out;
  }

  T _get<T>(String path) {
    dynamic cur = raw;
    for (final p in path.split('.')) {
      cur = (cur as Map<String, dynamic>)[p];
    }
    return cur as T;
  }

  List<String> _strings(String path) => (_get<List<dynamic>>(path)).cast<String>();

  // limits.*
  int get freeActiveHabits => _get('limits.free_active_habits');
  int get freeCustomHabits => _get('limits.free_custom_habits');
  List<String> get freeExercises => _strings('limits.free_exercises');
  List<String> get freeAdventureLocations => _strings('limits.free_adventure_locations');

  // pricing.*
  List<PricingPlan> get plans =>
      _get<List<dynamic>>('pricing.plans').map((e) => PricingPlan.fromJson(e as Map<String, dynamic>)).toList();
  String get monthlyAnchorProduct => _get('pricing.monthly_anchor_product');

  // trial.*
  bool get trialEnabled => _get('trial.enabled');
  int get trialDays => _get('trial.days');
  int get trialReminderDay => _get('trial.reminder_day');

  // paywall.*
  String get paywallVariant => _get('paywall.variant');
  bool paywallTrigger(String name) => (_get<Map<String, dynamic>>('paywall.triggers')[name] as bool?) ?? false;
  int get paywallCooldownHours => _get('paywall.cooldown_hours');

  // entitlement.*
  int get graceDays => _get('entitlement.grace_days');
  int get offlineValidityDays => _get('entitlement.offline_validity_days');
  int get pendingVerificationHours => _get('entitlement.pending_verification_hours');

  // economy.*
  int get energyPerGoal => _get('economy.energy_per_goal');
  int get energyPerCheckin => _get('economy.energy_per_checkin');
  int get energyPerExercise => _get('economy.energy_per_exercise');
  int get exerciseRewardsPerDay => _get('economy.exercise_rewards_per_day');
  int get energyCap => _get('economy.energy_cap');

  // adventure.*
  List<AdventureLocationConfig> get adventureLocations => _get<List<dynamic>>('adventure.locations')
      .map((e) => AdventureLocationConfig.fromJson(e as Map<String, dynamic>))
      .toList();
  AdventureLocationConfig? adventureLocation(String key) =>
      adventureLocations.firstWhereOrNull((l) => l.locationKey == key);

  // adventure.daily_energy_target, growth.*, quests.*, shop.*
  int get dailyEnergyTarget => _get('adventure.daily_energy_target');
  int get growthYoung => _get('growth.thresholds.young');
  int get growthAdult => _get('growth.thresholds.adult');
  int get questsDailyCount => _get('quests.daily_count');
  int get questsDailyRewardCoins => _get('quests.daily_reward_coins');
  int get shopRotationSize => _get('shop.rotation_size');
  int get shopRefreshCost => _get('shop.refresh_cost');
  double get shopSellRatio => (_get<num>('shop.sell_ratio')).toDouble();

  // onboarding.*
  int get recommendCountFree => _get('onboarding.recommend_count_free');
  int get recommendCountTrial => _get('onboarding.recommend_count_trial');
  RecommenderWeights get recommenderWeights => RecommenderWeights.fromJson(_get<Map<String, dynamic>>('onboarding.recommender'));

  // streak.*
  int get streakFreezesPerMonth => _get('streak.freezes_per_month');

  // notifications.*
  int get notifMaxPerDay => _get('notifications.max_per_day');
  String get notifMorningTime => _get('notifications.default_morning_time');
  String get notifEveningTime => _get('notifications.default_evening_time');
  String get notifQuietStart => _get('notifications.default_quiet.start');
  String get notifQuietEnd => _get('notifications.default_quiet.end');
  List<int> get notifComebackDays => (_get<List<dynamic>>('notifications.comeback_days')).cast<int>();
  int get notifIgnoreThreshold => _get('notifications.ignore_threshold');
  bool notifTypeEnabled(String type) =>
      (_get<Map<String, dynamic>>('notifications.types_enabled')[type] as bool?) ?? true;

  // safety.*
  int get safetyLowMoodLevel => _get('safety.low_mood_level');
  int get safetyLowMoodCount => _get('safety.low_mood_count');
  int get safetyLowMoodWindowDays => _get('safety.low_mood_window_days');
  int get safetyCardCooldownHours => _get('safety.card_cooldown_hours');

  // support.*
  bool get supportEnabled => _get('support.enabled');
  int get supportMaxMessageChars => _get('support.max_message_chars');
  String get supportTimezone => _get('support.timezone');
  List<SupportHours> get supportHours =>
      _get<List<dynamic>>('support.hours').map((e) => SupportHours.fromJson(e as Map<String, dynamic>)).toList();
  int get supportPollFirstMinutes => _get('support.poll_schedule.first_interval_minutes');
  int get supportPollFirstWindowHours => _get('support.poll_schedule.first_window_hours');
  int get supportPollSecondHours => _get('support.poll_schedule.second_interval_hours');
  int get supportPollStopDays => _get('support.poll_schedule.stop_after_days');

  // features.*
  bool feature(String name) => (_get<Map<String, dynamic>>('features')[name] as bool?) ?? false;

  // update.*
  String get minSupportedVersion => _get('update.min_supported_version');
  String get recommendedVersion => _get('update.recommended_version');
}

class PricingPlan {
  PricingPlan({required this.productId, required this.marketSku, required this.displayPriceToman, required this.badgeKey, required this.highlight});
  factory PricingPlan.fromJson(Map<String, dynamic> j) => PricingPlan(
        productId: j['product_id'] as String,
        marketSku: (j['market_sku'] as Map<String, dynamic>).cast<String, String>(),
        displayPriceToman: j['display_price_toman'] as int,
        badgeKey: j['badge_key'] as String,
        highlight: j['highlight'] as bool,
      );
  final String productId;
  final Map<String, String> marketSku;
  final int displayPriceToman;
  final String badgeKey;
  final bool highlight;
}

class AdventureLocationConfig {
  AdventureLocationConfig({required this.locationKey, required this.energyCost, required this.durationMinutes, required this.coinsMin, required this.coinsMax, required this.itemDropRate});
  factory AdventureLocationConfig.fromJson(Map<String, dynamic> j) => AdventureLocationConfig(
        locationKey: j['location_key'] as String,
        energyCost: j['energy_cost'] as int,
        durationMinutes: j['duration_minutes'] as int,
        coinsMin: j['coins_min'] as int,
        coinsMax: j['coins_max'] as int,
        itemDropRate: (j['item_drop_rate'] as num).toDouble(),
      );
  final String locationKey;
  final int energyCost;
  final int durationMinutes;
  final int coinsMin;
  final int coinsMax;
  final double itemDropRate;
}

/// One support opening window (`weekday` 0 = Saturday … 6 = Friday, "HH:mm" local time of `support.timezone`).
class SupportHours {
  const SupportHours({required this.weekday, required this.from, required this.to});
  factory SupportHours.fromJson(Map<String, dynamic> j) => SupportHours(weekday: j['weekday'] as int, from: j['from'] as String, to: j['to'] as String);
  final int weekday;
  final String from;
  final String to;
}

/// Coefficients of `GoalRecommender` (config `onboarding.recommender`, A/B-able; docs/70 §6).
class RecommenderWeights {
  const RecommenderWeights({
    this.areaSelected = 2,
    this.answerRarely = 2,
    this.answerSometimes = 1,
    this.needWeight = 10,
    this.tagWeight = 3,
    this.difficultyPenalty = 2,
    this.chronotypeBonus = 2,
  });
  factory RecommenderWeights.fromJson(Map<String, dynamic> j) => RecommenderWeights(
        areaSelected: j['area_selected'] as int,
        answerRarely: j['answer_rarely'] as int,
        answerSometimes: j['answer_sometimes'] as int,
        needWeight: j['need_weight'] as int,
        tagWeight: j['tag_weight'] as int,
        difficultyPenalty: j['difficulty_penalty'] as int,
        chronotypeBonus: j['chronotype_bonus'] as int,
      );
  final int areaSelected, answerRarely, answerSometimes, needWeight, tagWeight, difficultyPenalty, chronotypeBonus;
}
