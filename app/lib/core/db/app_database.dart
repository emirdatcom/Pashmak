import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Old `habit_templates` keys → goal-library keys (prompt 22 content migration). `medicine` has no
/// library equivalent and stays as a legacy key; its title still resolves through the legacy copy key.
const legacyTemplateToGoal = {
  'water': 'food_water_glass',
  'sleep': 'sleep_window_open',
  'short_break': 'focus_break_walk',
  'walk': 'move_walk_alley',
  'healthy_food': 'food_fruit_one',
  'loved_ones': 'conn_short_message',
};

/// Local database (docs/30 §3). Encryption is applied by the executor (see connection.dart).
@DriftDatabase(tables: [
  AppMeta,
  UserSettings,
  Habits,
  HabitLogs,
  Checkins,
  ExerciseSessions,
  Wallet,
  WalletLedger,
  Adventures,
  Inventory,
  StreakState,
  SafetyFlags,
  NotificationLog,
  EntitlementCache,
  Outbox,
  AnalyticsQueue,
  ContentCache,
  SupportMessagesCache,
  OnboardingAnswers,
  DiscoveriesFound,
  QuestProgress,
  QuestDailyState,
  ShopRotation,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(wallet).insert(WalletCompanion.insert(id: const Value(1), updatedAt: 0));
          await into(streakState).insert(StreakStateCompanion.insert(id: const Value(1)));
        },
        // v1 has no upgrades. From v2 on use stepByStep(...) generated from drift_schemas/ (docs/30 §11);
        // never ship a destructive migration without an export.
        onUpgrade: (m, from, to) async {
          // v1 → v2 (prompt 21): the support chat cache. Additive only, nothing is rewritten.
          if (from < 2) await m.createTable(supportMessagesCache);
          // v2 → v3 (prompt 22): goal fields on habits (old rows keep working; goal_key is filled from template_key
          // through the legacy → goal-library mapping) and the new local tables. Additive only.
          if (from < 3) {
            await m.addColumn(habits, habits.goalKey);
            await m.addColumn(habits, habits.areaKey);
            await m.addColumn(habits, habits.timeOfDay);
            await m.addColumn(habits, habits.repeatType);
            await m.addColumn(habits, habits.dueDay);
            await m.createTable(onboardingAnswers);
            await m.createTable(discoveriesFound);
            await m.createTable(questProgress);
            await m.createTable(questDailyState);
            await m.createTable(shopRotation);
            for (final e in legacyTemplateToGoal.entries) {
              await customStatement('UPDATE habits SET goal_key = ?, template_key = ? WHERE template_key = ?', [e.value, e.value, e.key]);
            }
            await customStatement('UPDATE habits SET goal_key = template_key WHERE goal_key IS NULL AND template_key IS NOT NULL');
          }
          if (to > 3) throw StateError('No migration from $from to $to');
        },
      );

  /// Deletes every row of every table and re-seeds the singleton rows: the app then behaves like a fresh install.
  Future<void> wipeAll() => transaction(() async {
        for (final t in allTables.toList().reversed) {
          await delete(t).go();
        }
        await into(wallet).insert(WalletCompanion.insert(id: const Value(1), updatedAt: 0));
        await into(streakState).insert(StreakStateCompanion.insert(id: const Value(1)));
      });

  // --- app_meta / user_settings key-value helpers ---------------------------------------------
  Future<String?> meta(String key) async =>
      (select(appMeta)..where((t) => t.key.equals(key))).map((r) => r.value).getSingleOrNull();

  Future<void> setMeta(String key, String value) =>
      into(appMeta).insertOnConflictUpdate(AppMetaCompanion.insert(key: key, value: value));

  Future<String?> setting(String key) async =>
      (select(userSettings)..where((t) => t.key.equals(key))).map((r) => r.value).getSingleOrNull();

  Future<void> setSetting(String key, String value) =>
      into(userSettings).insertOnConflictUpdate(UserSettingsCompanion.insert(key: key, value: value));
}
