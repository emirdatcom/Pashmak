import 'dart:convert';

import '../../../core/auth/token_store.dart';
import '../../../core/db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/outbox/outbox_worker.dart';
import '../../../core/time/clock.dart';

enum EraseOutcome { serverDeleted, serverQueued }

/// "Your data" (docs/80 §4): JSON export and complete erase.
class DataService {
  DataService(this._db, this._api, this._tokens, this._clock);

  final AppDatabase _db;
  final ApiClient _api;
  final TokenStore _tokens;
  final Clock _clock;

  Map<String, OutboxHandler> get handlers => {'account_delete': _deleteHandler};

  /// Everything the user created, as plain JSON. Never contains tokens, keys or ids of the device.
  Future<Map<String, dynamic>> exportData() async {
    List<Map<String, dynamic>> rows(Iterable<dynamic> r) => [for (final x in r) Map<String, dynamic>.from(x.toJson() as Map)];
    return {
      'format_version': 1,
      'exported_at': _clock.now().toUtc().toIso8601String(),
      'habits': rows(await _db.select(_db.habits).get()),
      'habit_logs': rows(await _db.select(_db.habitLogs).get()),
      'checkins': rows(await _db.select(_db.checkins).get()),
      'exercise_sessions': rows(await _db.select(_db.exerciseSessions).get()),
      'wallet': rows(await _db.select(_db.wallet).get()),
      'wallet_ledger': rows(await _db.select(_db.walletLedger).get()),
      'adventures': rows(await _db.select(_db.adventures).get()),
      'inventory': rows(await _db.select(_db.inventory).get()),
      'streak': rows(await _db.select(_db.streakState).get()),
      'settings': rows(await _db.select(_db.userSettings).get()),
    };
  }

  Future<String> exportJson() async => const JsonEncoder.withIndent('  ').convert(await exportData());

  /// Wipes the device and asks the server to delete the account. Offline: the request waits in the outbox
  /// (tokens are kept only until it succeeds).
  Future<EraseOutcome> eraseAll() async {
    var serverDone = false;
    try {
      await _api.request<void>('DELETE', '/v1/me');
      serverDone = true;
    } on ApiError catch (e) {
      // 401 = no account / already gone; nothing more to delete there.
      serverDone = e.status == 401;
    }
    await _db.wipeAll();
    if (serverDone) {
      await _tokens.clear();
      return EraseOutcome.serverDeleted;
    }
    final now = _clock.now().millisecondsSinceEpoch;
    await _db.into(_db.outbox).insert(OutboxCompanion.insert(
        id: 'account_delete', kind: 'account_delete', payload: '{}', nextAttemptAt: now, createdAt: now));
    return EraseOutcome.serverQueued;
  }

  Future<OutboxResult> _deleteHandler(Map<String, dynamic> _) async {
    try {
      await _api.request<void>('DELETE', '/v1/me');
    } on ApiError catch (e) {
      if (e.status != 401) rethrow;
    }
    await _tokens.clear();
    return OutboxResult.done;
  }
}
