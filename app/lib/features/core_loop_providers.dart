import 'goals/domain/goal_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/content_repository.dart';
import 'goals/domain/goal_recommender.dart';
import 'quests/domain/quest_engine.dart';
import 'quests/domain/quest_service.dart';
import 'settings/domain/pause_service.dart';
import 'shop/seasonal/seasonal.dart';
import 'notifications/domain/notification_planner.dart' show SeasonalEvent;

import '../core/config/app_config.dart';
import '../core/db/app_database.dart';
import '../core/entitlement/premium_gate.dart';
import '../core/providers.dart';
import '../core/safety/distress_detector.dart';
import '../core/widget_snapshot.dart';
import '../core/widgets/cat_renderer.dart';
import '../core/screen_awake.dart';
import '../core/widgets_home/widget_snapshot.dart';
import '../core/widgets_home/widget_snapshot_publisher.dart';
import 'adventure/domain/adventure_service.dart';
import 'notifications/data/notification_scheduler.dart';
import 'cat/domain/cat_growth.dart';
import 'cat/domain/cat_mood_resolver.dart';
import 'checkin/domain/checkin_service.dart';
import 'exercises/domain/exercise_service.dart';
import 'habits/domain/habit_service.dart';
import 'safety/domain/safety_service.dart';
import 'shop/domain/shop_service.dart';
import 'streak/domain/streak_service.dart';
import 'wallet/domain/wallet_service.dart';

/// Data-changed hook: services call `refresh()` after writes. It replans notifications (and, with
/// prompt 13B/16, republishes the widget snapshot). Calls made while a replan runs are coalesced.
class DataChangedPublisher implements WidgetSnapshotPublisher {
  DataChangedPublisher(this._onChange);
  final Future<void> Function() _onChange;
  bool _running = false;
  bool _again = false;

  @override
  Future<void> refresh() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _onChange();
      } while (_again);
    } finally {
      _running = false;
    }
  }
}

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) => NotificationScheduler(
      db: ref.watch(databaseProvider),
      clock: ref.watch(clockProvider),
      service: ref.watch(notificationServiceProvider),
      config: () => ref.read(appConfigProvider),
      copy: () => ref.read(copyProvider),
      analytics: ref.watch(analyticsProvider),
      dayStartHour: ref.watch(dayStartHourProvider),
      seasonal: () {
        final hour = 10; // a calm mid-morning moment on the first day of the season
        return [
          for (final p in ref.read(seasonalCatalogProvider).packs)
            if (p.notifBody != null) SeasonalEvent(id: '${p.key}_${p.from ~/ 10000}', at: p.startDate.add(Duration(hours: hour)), copyKey: 'seasonal.${p.key}.notif_body'),
        ];
      },
    ));

/// Kotlin package of the AppWidgetProviders (android/app/src/main/kotlin/.../widget).
const widgetAndroidPackage = 'ir.example.pashmak_app.widget';

final homeWidgetPublisherProvider = Provider<HomeWidgetPublisher>((ref) => HomeWidgetPublisher(
      WidgetSnapshotBuilder(
        ref.watch(databaseProvider),
        ref.watch(clockProvider),
        dayStartHour: ref.watch(dayStartHourProvider),
        habitTitle: (h) => goalTitle(ref.read(copyProvider), h.goalKey ?? h.templateKey, h.title),
        streakLabel: (n) => n > 0 ? ref.read(copyProvider).t('streak.continue', {'n': n}) : ref.read(copyProvider).t('home.streak.none'),
        progressLabel: (d, t) => ref.read(copyProvider).t('home.habits.progress', {'n': d}),
      ),
      const HomeWidgetBridge(widgetAndroidPackage),
      enabled: () => ref.read(appConfigProvider).feature('widgets'),
    ));

final Provider<WidgetSnapshotPublisher> widgetSnapshotPublisherProvider = Provider<WidgetSnapshotPublisher>((ref) => DataChangedPublisher(() async {
      // When today's energy bar is full the day's adventure starts by itself (docs/22 §9).
      try {
        await ref.read(adventureServiceProvider).maybeAutoStart(isPremium: ref.read(premiumProvider));
      } catch (_) {}
      await ref.read(notificationSchedulerProvider).replan();
      await ref.read(homeWidgetPublisherProvider).refresh();
    }));

final walletServiceProvider = Provider<WalletService>((ref) =>
    WalletService(ref.watch(databaseProvider), ref.watch(clockProvider), energyCap: () => ref.read(appConfigProvider).energyCap));

final streakServiceProvider = Provider<StreakService>(
    (ref) => StreakService(ref.watch(databaseProvider), freezesPerMonth: () => ref.read(appConfigProvider).streakFreezesPerMonth));

final safetyServiceProvider = Provider<SafetyService>((ref) =>
    SafetyService(ref.watch(databaseProvider), ref.watch(clockProvider), cooldownHours: () => ref.read(appConfigProvider).safetyCardCooldownHours));

final habitServiceProvider = Provider<HabitService>((ref) {
  AppConfig cfg() => ref.read(appConfigProvider);
  return HabitService(ref.watch(databaseProvider), ref.watch(clockProvider), ref.watch(walletServiceProvider), ref.watch(streakServiceProvider),
      ref.watch(analyticsProvider), ref.watch(widgetSnapshotPublisherProvider),
      energyPerGoal: () => cfg().energyPerGoal,
      freeActiveHabits: () => cfg().freeActiveHabits,
      freeCustomHabits: () => cfg().freeCustomHabits,
      today: () => ref.read(todayProvider));
});

DistressDetector _detector(Ref ref) {
  final cfg = ref.read(appConfigProvider);
  final entries = ref.read(contentRepositoryProvider).entries('safety');
  final keywords = (entries is Map ? (entries['keywords'] as List?)?.cast<String>() : null) ?? const <String>[];
  return DistressDetector(
      keywords: keywords, lowMoodLevel: cfg.safetyLowMoodLevel, lowMoodCount: cfg.safetyLowMoodCount, windowDays: cfg.safetyLowMoodWindowDays);
}

final checkinServiceProvider = Provider<CheckinService>((ref) => CheckinService(ref.watch(databaseProvider), ref.watch(clockProvider),
    ref.watch(walletServiceProvider), ref.watch(streakServiceProvider), ref.watch(safetyServiceProvider), ref.watch(analyticsProvider),
    ref.watch(widgetSnapshotPublisherProvider),
    energyPerCheckin: () => ref.read(appConfigProvider).energyPerCheckin, today: () => ref.read(todayProvider), detector: () => _detector(ref)));

final Provider<AdventureService> adventureServiceProvider = Provider<AdventureService>((ref) {
  final content = ref.watch(contentRepositoryProvider);
  return AdventureService(ref.watch(databaseProvider), ref.watch(clockProvider), ref.watch(walletServiceProvider), ref.watch(analyticsProvider),
      ref.watch(widgetSnapshotPublisherProvider),
      configs: () => ref.read(appConfigProvider).adventureLocations,
      adventuresPack: () => (content.entries('adventures') as Map<String, dynamic>?) ?? const {},
      shopItems: () => (content.entries('shop_items') as List?) ?? const [],
      freeLocations: () => ref.read(appConfigProvider).freeAdventureLocations,
      dailyEnergyTarget: () => ref.read(appConfigProvider).dailyEnergyTarget,
      discoveries: () => ((content.entries('discoveries') as List?) ?? const []).cast<Map<String, dynamic>>(),
      growth: () => CatGrowth(young: ref.read(appConfigProvider).growthYoung, adult: ref.read(appConfigProvider).growthAdult),
      today: () => ref.read(todayProvider).value);
});

final premiumGateProvider = Provider<PremiumGate>((ref) => PremiumGate(ref.watch(databaseProvider), ref.watch(clockProvider),
    cooldownHours: () => ref.read(appConfigProvider).paywallCooldownHours, triggerEnabled: (t) => ref.read(appConfigProvider).paywallTrigger(t)));

final gateContextProvider = Provider<GateContext>((ref) => GateContext(
    lowMoodThisSession: ref.watch(lowMoodSessionProvider), onboardingCompleted: ref.watch(onboardingCompletedProvider)));

final walletProvider = StreamProvider<WalletBalance>((ref) => ref.watch(walletServiceProvider).watch());
final streakProvider = StreamProvider<StreakSnapshot>((ref) => ref.watch(streakServiceProvider).watch());
final todayHabitsProvider = StreamProvider<List<TodayHabit>>((ref) {
  ref.watch(todayProvider);
  return ref.watch(habitServiceProvider).watchToday();
});
final allHabitsProvider = StreamProvider<List<Habit>>((ref) => ref.watch(habitServiceProvider).watchAll());
final currentAdventureProvider = StreamProvider<Adventure?>((ref) => ref.watch(adventureServiceProvider).watchCurrent());
final safetyCardVisibleProvider = StreamProvider<bool>((ref) => ref.watch(safetyServiceProvider).watchCardVisible());
final lastMoodTodayProvider = StreamProvider<int?>((ref) => ref.watch(checkinServiceProvider).watchLastMoodToday());

/// Equipped inventory items (accessories drawn on the cat).
final equippedItemsProvider = StreamProvider<List<InventoryData>>(
    (ref) => (ref.watch(databaseProvider).select(ref.watch(databaseProvider).inventory)..where((i) => i.equipped.equals(true))).watch());

/// Ticks every 30s so "adventure returned" and day changes show up without user action.
final tickProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  while (true) {
    yield clock.now();
    await Future<void>.delayed(const Duration(seconds: 30));
  }
});

final catStateProvider = Provider<CatVisualState>((ref) {
  ref.watch(tickProvider);
  final adv = ref.watch(currentAdventureProvider).value;
  final mood = ref.watch(lastMoodTodayProvider).value;
  final habits = ref.watch(todayHabitsProvider).value ?? const [];
  final equipped = ref.watch(equippedItemsProvider).value ?? const [];
  final hour = ref.watch(clockProvider).now().hour;
  return CatMoodResolver.resolve(
    adventureActive: adv != null && adv.status == 'active',
    localHour: hour,
    lastCheckinMoodToday: mood,
    allHabitsDoneToday: habits.isNotEmpty && habits.every((h) => h.done),
    adventureJustClaimed: false,
    accessories: [for (final i in equipped) if (i.slot != 'background') i.itemKey],
    background: equipped.where((i) => i.slot == 'background').map((i) => i.itemKey).firstOrNull,
    stage: ref.watch(catStageProvider),
    fur: ref.watch(catProfileProvider).value?.fur ?? CatFur.orangeCream,
  );
});

// --- exercises & shop (prompt 12) ---------------------------------------------------------------
final screenAwakeProvider = Provider<ScreenAwake>((ref) => const ChannelScreenAwake());

final exerciseServiceProvider = Provider<ExerciseService>((ref) => ExerciseService(
    ref.watch(databaseProvider), ref.watch(clockProvider), ref.watch(walletServiceProvider), ref.watch(streakServiceProvider),
    ref.watch(analyticsProvider), ref.watch(widgetSnapshotPublisherProvider),
    today: () => ref.read(todayProvider),
    energyPerExercise: () => ref.read(appConfigProvider).energyPerExercise,
    rewardsPerDay: () => ref.read(appConfigProvider).exerciseRewardsPerDay,
    freeExercises: () => ref.read(appConfigProvider).freeExercises,
    onCompleted: (key) => ref.read(habitServiceProvider).completeLinked(key)));

/// Base shop items plus every seasonal item (owned seasonal items must stay resolvable after the season).
List<ShopItem> shopCatalog(ContentRepository content, SeasonalCatalog seasonal) => [
      for (final j in ((content.entries('shop_items') as List?) ?? const []).cast<Map<String, dynamic>>()) ShopItem.fromJson(j),
      for (final p in seasonal.packs)
        for (final i in p.items) ShopItem(itemKey: i.itemKey, nameKey: i.nameKey, slot: i.slot, priceCoins: i.priceCoins, premiumOnly: i.premiumOnly, seasonalKey: p.key),
    ];

final shopServiceProvider = Provider<ShopService>((ref) {
  final content = ref.watch(contentRepositoryProvider);
  return ShopService(ref.watch(databaseProvider), ref.watch(clockProvider), ref.watch(walletServiceProvider), ref.watch(analyticsProvider),
      ref.watch(widgetSnapshotPublisherProvider),
      items: () => shopCatalog(content, ref.read(seasonalCatalogProvider)),
      isSeasonActive: (key) => ref.read(seasonalCatalogProvider).active(ref.read(todayProvider)).any((p) => p.key == key),
      today: () => ref.read(todayProvider).value,
      installId: () => ref.read(deviceIdentityProvider).installId(),
      rotationSize: () => ref.read(appConfigProvider).shopRotationSize,
      refreshCost: () => ref.read(appConfigProvider).shopRefreshCost,
      sellRatio: () => ref.read(appConfigProvider).shopSellRatio);
});

// --- prompt 22: quests, rest mode, cat profile -----------------------------------------------------------------
List<QuestDef> _questPack(ContentRepository c, String key) => [for (final j in ((c.entries(key) as List?) ?? const []).cast<Map<String, dynamic>>()) QuestDef.fromJson(j)];

final questServiceProvider = Provider<QuestService>((ref) {
  final content = ref.watch(contentRepositoryProvider);
  return QuestService(ref.watch(databaseProvider), ref.watch(clockProvider), ref.watch(walletServiceProvider), ref.watch(analyticsProvider),
      ref.watch(widgetSnapshotPublisherProvider),
      today: () => ref.read(todayProvider).value,
      dayStart: () {
        final t = ref.read(todayProvider);
        return DateTime(t.year, t.month, t.day, ref.read(dayStartHourProvider));
      },
      dailyPool: () => _questPack(content, 'quests_daily'),
      specialPool: () => _questPack(content, 'quests_special'),
      dailyCount: () => ref.read(appConfigProvider).questsDailyCount,
      dailyRewardCoins: () => ref.read(appConfigProvider).questsDailyRewardCoins,
      seed: () async => stableHash(await ref.read(deviceIdentityProvider).installId()));
});

final pauseServiceProvider = Provider<PauseService>((ref) => PauseService(ref.watch(databaseProvider), ref.watch(clockProvider),
    ref.watch(streakServiceProvider), ref.watch(analyticsProvider), ref.watch(widgetSnapshotPublisherProvider),
    today: () => ref.read(todayProvider)));

final pausedProvider = StreamProvider<bool>((ref) => ref.watch(pauseServiceProvider).watch());

/// Bumps on every local DB write, so derived (non-stream) views can recompute.
final dbTickProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);
  var n = 0;
  yield n;
  await for (final _ in db.tableUpdates()) {
    yield ++n;
  }
});

final dailyQuestsProvider = FutureProvider<List<QuestView>>((ref) {
  ref.watch(dbTickProvider);
  ref.watch(todayProvider);
  return ref.watch(questServiceProvider).daily();
});

final specialQuestsProvider = FutureProvider<List<QuestView>>((ref) {
  ref.watch(dbTickProvider);
  return ref.watch(questServiceProvider).special();
});

/// Goal library entries (the `goal_library` pack).
final goalLibraryProvider = Provider<List<GoalDef>>((ref) =>
    [for (final j in ((ref.watch(contentRepositoryProvider).entries('goal_library') as List?) ?? const []).cast<Map<String, dynamic>>()) GoalDef.fromJson(j)]);

final goalRecommenderProvider = Provider<GoalRecommender>((ref) =>
    GoalRecommender(goals: ref.watch(goalLibraryProvider), weights: ref.watch(appConfigProvider).recommenderWeights));

/// Cat identity chosen at onboarding (stored in app_meta): fur colour and personality trait.
class CatProfile {
  const CatProfile({this.fur = CatFur.orangeCream, this.trait = 'curious', this.userName = '', this.arrivedAt});
  final CatFur fur;
  final String trait; // curious | kind | playful
  final String userName;
  final DateTime? arrivedAt;
}

final catProfileProvider = FutureProvider<CatProfile>((ref) async {
  ref.watch(dbTickProvider);
  final db = ref.watch(databaseProvider);
  final furName = await db.meta('cat_fur');
  final fur = CatFur.values.where((f) => f.name == furName).firstOrNull ?? CatFur.orangeCream;
  final arrived = int.tryParse(await db.meta('cat_arrived_at') ?? '');
  return CatProfile(
      fur: fur,
      trait: await db.meta('cat_trait') ?? 'curious',
      userName: await db.meta('user_name') ?? '',
      arrivedAt: arrived == null ? null : DateTime.fromMillisecondsSinceEpoch(arrived));
});

/// Completed adventures → growth stage.
final adventuresCountProvider = FutureProvider<int>((ref) async {
  ref.watch(dbTickProvider);
  final db = ref.watch(databaseProvider);
  return (await (db.select(db.adventures)..where((a) => a.status.equals('claimed'))).get()).length;
});

final catStageProvider = Provider<CatStage>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return CatGrowth(young: cfg.growthYoung, adult: cfg.growthAdult).stageFor(ref.watch(adventuresCountProvider).value ?? 0);
});

final foundDiscoveriesProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.discoveriesFound).watch().map((r) => {for (final d in r) d.discoveryKey});
});

final ownedItemsProvider = StreamProvider<List<InventoryData>>((ref) => ref.watch(shopServiceProvider).watchOwned());

/// Number of goal completions ever (profile "details" tab).
final goalsDoneTotalProvider = FutureProvider<int>((ref) async {
  ref.watch(dbTickProvider);
  final db = ref.watch(databaseProvider);
  return (await (db.select(db.habitLogs)..where((l) => l.deletedAt.isNull())).get()).length;
});
