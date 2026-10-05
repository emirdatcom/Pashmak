import 'dart:convert';

import 'package:dio/dio.dart';

import '../db/app_database.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';
import '../time/clock.dart';
import 'app_config.dart';
import 'asset_source.dart';

/// Bundled default config + server override cached in app_meta (ETag, refreshed at most every 6h).
class ConfigRepository {
  ConfigRepository(this._db, this._assets, this._api, this._clock);

  static const defaultAsset = 'assets/config/default.json';
  static const refreshInterval = Duration(hours: 6);
  static const _kCache = 'config_cache'; // {"etag":..., "version":..., "payload":{...}}
  static const _kFetchedAt = 'config_fetched_at';

  final AppDatabase _db;
  final AssetSource _assets;
  final ApiClient _api;
  final Clock _clock;

  AppConfig? _current;
  int? servedVersion;
  Map<String, String> experiments = const {};

  AppConfig get current => _current ?? (throw StateError('ConfigRepository.load() not called'));

  Future<Map<String, dynamic>> _bundled() async =>
      jsonDecode(await _assets.load(defaultAsset)) as Map<String, dynamic>;

  /// Loads bundled defaults merged with the cached server config. Works fully offline.
  Future<AppConfig> load() async {
    final base = await _bundled();
    var merged = base;
    final cached = await _db.meta(_kCache);
    if (cached != null) {
      try {
        final c = jsonDecode(cached) as Map<String, dynamic>;
        merged = AppConfig.merge(base, c['payload'] as Map<String, dynamic>);
        servedVersion = c['version'] as int?;
        experiments = (c['experiments'] as Map<String, dynamic>? ?? {}).cast<String, String>();
      } catch (_) {
        merged = base; // corrupted cache must never break startup
      }
    }
    return _current = AppConfig(merged);
  }

  /// Fetches the config unless fetched within [refreshInterval] (or [force]). Returns true if it changed.
  Future<bool> refresh({bool force = false}) async {
    final lastMs = int.tryParse(await _db.meta(_kFetchedAt) ?? '');
    final now = _clock.now();
    if (!force && lastMs != null && now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) < refreshInterval) {
      return false;
    }
    String? etag;
    final cached = await _db.meta(_kCache);
    if (cached != null) etag = (jsonDecode(cached) as Map<String, dynamic>)['etag'] as String?;
    try {
      final r = await _api.request<Map<String, dynamic>>('GET', '/v1/config',
          headers: {'If-None-Match': ?etag},
          validateStatus: (s) => s != null && (s == 200 || s == 304));
      await _db.setMeta(_kFetchedAt, '${now.millisecondsSinceEpoch}');
      if (r.statusCode == 304) return false;
      final body = r.data!;
      final newEtag = r.headers.value('etag') ?? body['etag'] as String?;
      await _db.setMeta(
          _kCache,
          jsonEncode({
            'etag': newEtag,
            'version': body['version'],
            'payload': body['payload'],
            'experiments': body['experiments'] ?? {},
          }));
      await load();
      return true;
    } on ApiError {
      return false; // offline or server down: keep what we have
    } on DioException {
      return false;
    }
  }
}
