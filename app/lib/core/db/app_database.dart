import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(wallet).insert(WalletCompanion.insert(id: const Value(1), updatedAt: 0));
          await into(streakState).insert(StreakStateCompanion.insert(id: const Value(1)));
        },
        // v1 has no upgrades. From v2 on use stepByStep(...) generated from drift_schemas/ (docs/30 §11);
        // never ship a destructive migration without an export.
        onUpgrade: (m, from, to) async => throw StateError('No migration from $from to $to'),
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
