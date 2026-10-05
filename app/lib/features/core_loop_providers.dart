import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/db/app_database.dart';
import '../core/entitlement/premium_gate.dart';
import '../core/providers.dart';
import '../core/safety/distress_detector.dart';
import '../core/widget_snapshot.dart';
import '../core/widgets/cat_renderer.dart';
import '../core/screen_awake.dart';
import 'adventure/domain/adventure_service.dart';
import 'notifications/data/notification_scheduler.dart';
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
    ));

final widgetSnapshotPublisherProvider = Provider<WidgetSnapshotPublisher>((ref) => DataChangedPublisher(() async {
      await ref.read(notificationSchedulerProvider).replan();
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
      energyPerHabit: () => cfg().energyPerHabit,
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

final adventureServiceProvider = Provider<AdventureService>((ref) {
  final content = ref.watch(contentRepositoryProvider);
  return AdventureService(ref.watch(databaseProvider), ref.watch(clockProvider), ref.watch(walletServiceProvider), ref.watch(analyticsProvider),
      ref.watch(widgetSnapshotPublisherProvider),
      configs: () => ref.read(appConfigProvider).adventureLocations,
      adventuresPack: () => (content.entries('adventures') as Map<String, dynamic>?) ?? const {},
      shopItems: () => (content.entries('shop_items') as List?) ?? const [],
      freeLocations: () => ref.read(appConfigProvider).freeAdventureLocations);
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
    freeExercises: () => ref.read(appConfigProvider).freeExercises));

final shopServiceProvider = Provider<ShopService>((ref) {
  final content = ref.watch(contentRepositoryProvider);
  return ShopService(ref.watch(databaseProvider), ref.watch(clockProvider), ref.watch(walletServiceProvider), ref.watch(analyticsProvider),
      ref.watch(widgetSnapshotPublisherProvider),
      items: () => [for (final j in ((content.entries('shop_items') as List?) ?? const []).cast<Map<String, dynamic>>()) ShopItem.fromJson(j)]);
});

final ownedItemsProvider = StreamProvider<List<InventoryData>>((ref) => ref.watch(shopServiceProvider).watchOwned());
