import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import 'snapshot_upgraders.dart';

/// `app_meta` keys that belong to the user (the rest — install id, tokens' flags, caches — are per device).
const backedUpMetaKeys = ['cat_name', 'onboarding_completed'];

class SnapshotSummary {
  const SnapshotSummary({required this.exportedAt, required this.habits, required this.checkins, required this.logs});
  final DateTime? exportedAt;
  final int habits;
  final int checkins;
  final int logs;
}

/// Exports every user table except `outbox`, `analytics_queue`, `content_cache`, `entitlement_cache` and
/// `notification_log` (docs/30 §10) as JSON, then gzips it.
class SnapshotExporter {
  SnapshotExporter(this._db, this._clock);
  final AppDatabase _db;
  final Clock _clock;

  Future<Map<String, dynamic>> export() async {
    List<Map<String, dynamic>> rows(List<DataClass> r) => [for (final x in r) Map<String, dynamic>.from(x.toJson() as Map)];
    return {
      'schema_version': currentSnapshotSchema,
      'exported_at': _clock.now().toUtc().toIso8601String(),
      'habits': rows(await _db.select(_db.habits).get()),
      'habit_logs': rows(await _db.select(_db.habitLogs).get()),
      'checkins': rows(await _db.select(_db.checkins).get()),
      'exercise_sessions': rows(await _db.select(_db.exerciseSessions).get()),
      'wallet': rows(await _db.select(_db.wallet).get()),
      'wallet_ledger': rows(await _db.select(_db.walletLedger).get()),
      'adventures': rows(await _db.select(_db.adventures).get()),
      'inventory': rows(await _db.select(_db.inventory).get()),
      'streak_state': rows(await _db.select(_db.streakState).get()),
      'safety_flags': rows(await _db.select(_db.safetyFlags).get()),
      'user_settings': rows(await _db.select(_db.userSettings).get()),
      'meta': {for (final k in backedUpMetaKeys) if (await _db.meta(k) != null) k: await _db.meta(k)},
    };
  }

  Future<List<int>> exportGzip() async => gzip.encode(utf8.encode(jsonEncode(await export())));
}

/// Reads a decrypted snapshot, upgrades old formats and replaces local data in one transaction.
class SnapshotImporter {
  SnapshotImporter(this._db, {SnapshotUpgraders? upgraders}) : _upgraders = upgraders ?? SnapshotUpgraders();
  final AppDatabase _db;
  final SnapshotUpgraders _upgraders;

  static Map<String, dynamic> decodeGzip(List<int> gz) => jsonDecode(utf8.decode(gzip.decode(gz))) as Map<String, dynamic>;

  Map<String, dynamic> upgrade(Map<String, dynamic> raw) => _upgraders.upgrade(Map<String, dynamic>.of(raw), (raw['schema_version'] as int?) ?? 1);

  SnapshotSummary summarize(Map<String, dynamic> s) => SnapshotSummary(
        exportedAt: DateTime.tryParse((s['exported_at'] as String?) ?? ''),
        habits: ((s['habits'] as List?) ?? const []).where((h) => (h as Map)['deletedAt'] == null && h['archivedAt'] == null).length,
        checkins: ((s['checkins'] as List?) ?? const []).where((c) => (c as Map)['deletedAt'] == null).length,
        logs: ((s['habit_logs'] as List?) ?? const []).length,
      );

  /// **Replaces** the user tables with the snapshot (no merge, docs/30 §9). Device-specific tables
  /// (outbox, caches, analytics queue, entitlement) are left untouched. All-or-nothing.
  Future<void> restore(Map<String, dynamic> snapshot) async {
    final s = upgrade(snapshot);
    List<Map<String, dynamic>> list(String k) => ((s[k] as List?) ?? const []).cast<Map<String, dynamic>>();
    await _db.transaction(() async {
      // children before parents
      for (final t in <TableInfo>[_db.habitLogs, _db.exerciseSessions, _db.walletLedger, _db.checkins, _db.adventures, _db.inventory, _db.safetyFlags, _db.habits, _db.wallet, _db.streakState, _db.userSettings]) {
        await _db.delete(t).go();
      }
      Future<void> put<D extends DataClass>(TableInfo<Table, D> t, String key, D Function(Map<String, dynamic>) from) async {
        for (final j in list(key)) {
          await _db.into(t).insert(from(j) as Insertable<D>);
        }
      }

      await put(_db.habits, 'habits', Habit.fromJson);
      await put(_db.habitLogs, 'habit_logs', HabitLog.fromJson);
      await put(_db.checkins, 'checkins', Checkin.fromJson);
      await put(_db.exerciseSessions, 'exercise_sessions', ExerciseSession.fromJson);
      await put(_db.wallet, 'wallet', WalletData.fromJson);
      await put(_db.walletLedger, 'wallet_ledger', WalletLedgerData.fromJson);
      await put(_db.adventures, 'adventures', Adventure.fromJson);
      await put(_db.inventory, 'inventory', InventoryData.fromJson);
      await put(_db.streakState, 'streak_state', StreakStateData.fromJson);
      await put(_db.safetyFlags, 'safety_flags', SafetyFlag.fromJson);
      await put(_db.userSettings, 'user_settings', UserSetting.fromJson);
      // singleton rows must exist even for a very old snapshot
      if ((await _db.select(_db.wallet).get()).isEmpty) await _db.into(_db.wallet).insert(WalletCompanion.insert(id: const Value(1), updatedAt: 0));
      if ((await _db.select(_db.streakState).get()).isEmpty) await _db.into(_db.streakState).insert(StreakStateCompanion.insert(id: const Value(1)));
      final meta = (s['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
      for (final k in backedUpMetaKeys) {
        if (meta[k] is String) await _db.setMeta(k, meta[k] as String);
      }
    });
  }
}
