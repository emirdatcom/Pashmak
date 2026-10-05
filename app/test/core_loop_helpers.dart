import 'dart:convert';

import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/config/app_config.dart';
import 'package:pashmak_app/core/db/app_database.dart';
import 'package:pashmak_app/core/safety/distress_detector.dart';
import 'package:pashmak_app/core/time/clock.dart';
import 'package:pashmak_app/core/time/local_day.dart';
import 'package:pashmak_app/core/widget_snapshot.dart';
import 'package:pashmak_app/features/adventure/domain/adventure_service.dart';
import 'package:pashmak_app/features/checkin/domain/checkin_service.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/safety/domain/safety_service.dart';
import 'package:pashmak_app/features/streak/domain/streak_service.dart';
import 'package:pashmak_app/features/wallet/domain/wallet_service.dart';

import 'helpers.dart';

/// All core-loop services wired on an in-memory DB, a fake clock and the real bundled config/content.
class Loop {
  Loop(DateTime start, {AppDatabase? database, this.dayStartHour = 4})
      : db = database ?? memoryDb(),
        clock = FakeClock(start) {
    final assets = realAssets().files;
    config = AppConfig(jsonDecode(assets['assets/config/default.json']!) as Map<String, dynamic>);
    adventuresPack = (jsonDecode(assets['assets/content/adventures.json']!)['entries'] as Map<String, dynamic>);
    shopPack = (jsonDecode(assets['assets/content/shop_items.json']!)['entries'] as List);
    keywords = ((jsonDecode(assets['assets/content/safety.json']!)['entries'] as Map)['keywords'] as List).cast<String>();
    analytics = QueueAnalytics(db, clock, sessionId: () => 's1');
    wallet = WalletService(db, clock, energyCap: () => config.energyCap);
    streak = StreakService(db, freezesPerMonth: () => config.streakFreezesPerMonth);
    safety = SafetyService(db, clock, cooldownHours: () => config.safetyCardCooldownHours);
    habits = HabitService(db, clock, wallet, streak, analytics, const NoopWidgetSnapshotPublisher(),
        energyPerHabit: () => config.energyPerHabit,
        freeActiveHabits: () => config.freeActiveHabits,
        freeCustomHabits: () => config.freeCustomHabits,
        today: today);
    checkins = CheckinService(db, clock, wallet, streak, safety, analytics, const NoopWidgetSnapshotPublisher(),
        energyPerCheckin: () => config.energyPerCheckin,
        today: today,
        detector: () => DistressDetector(
            keywords: keywords,
            lowMoodLevel: config.safetyLowMoodLevel,
            lowMoodCount: config.safetyLowMoodCount,
            windowDays: config.safetyLowMoodWindowDays));
    adventures = AdventureService(db, clock, wallet, analytics, const NoopWidgetSnapshotPublisher(),
        configs: () => config.adventureLocations,
        adventuresPack: () => adventuresPack,
        shopItems: () => shopPack,
        freeLocations: () => config.freeAdventureLocations);
  }

  final AppDatabase db;
  final FakeClock clock;
  final int dayStartHour;
  late final AppConfig config;
  late final Map<String, dynamic> adventuresPack;
  late final List<dynamic> shopPack;
  late final List<String> keywords;
  late final QueueAnalytics analytics;
  late final WalletService wallet;
  late final StreakService streak;
  late final SafetyService safety;
  late final HabitService habits;
  late final CheckinService checkins;
  late final AdventureService adventures;

  LocalDay today() => LocalDay.today(clock, dayStartHour: dayStartHour);
}
