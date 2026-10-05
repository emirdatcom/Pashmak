import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../config/asset_source.dart';
import '../db/app_database.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';

/// Highest `pack_schema_version` this app understands; newer packs are ignored (docs/30 §11).
const supportedPackSchemaVersion = 1;

const bundledPackKeys = ['brand', 'copy_fa', 'habit_templates', 'exercises', 'adventures', 'shop_items', 'safety'];

/// Bundled packs (assets/content) plus downloaded ones (content_cache, sha256-verified).
class ContentRepository {
  ContentRepository(this._db, this._assets, this._api, {required this.appVersion});

  final AppDatabase _db;
  final AssetSource _assets;
  final ApiClient _api;
  final String appVersion;

  static const _kManifestEtag = 'content_manifest_etag';

  final Map<String, Map<String, dynamic>> _bundled = {};
  final Map<String, Map<String, dynamic>> _downloaded = {};

  Future<void> load() async {
    for (final k in bundledPackKeys) {
      final path = 'assets/content/$k.json';
      if (await _assets.exists(path)) {
        _bundled[k] = jsonDecode(await _assets.load(path)) as Map<String, dynamic>;
      }
    }
    for (final row in await _db.select(_db.contentCache).get()) {
      try {
        final doc = jsonDecode(row.payload) as Map<String, dynamic>;
        if ((doc['pack_schema_version'] as int? ?? 1) <= supportedPackSchemaVersion &&
            (doc['version'] as int) >= ((_bundled[row.packKey]?['version'] as int?) ?? 0)) {
          _downloaded[row.packKey] = doc;
        }
      } catch (_) {
        // corrupt cache row: ignore, bundled pack still works
      }
    }
  }

  /// The effective `entries` of a pack: downloaded when newer-or-equal, else bundled.
  dynamic entries(String packKey) => (_downloaded[packKey] ?? _bundled[packKey])?['entries'];

  Map<String, dynamic> bundledEntries(String packKey) =>
      (_bundled[packKey]?['entries'] as Map<String, dynamic>?) ?? const {};

  Map<String, dynamic> downloadedEntries(String packKey) =>
      (_downloaded[packKey]?['entries'] as Map<String, dynamic>?) ?? const {};

  int version(String packKey) => (_downloaded[packKey] ?? _bundled[packKey])?['version'] as int? ?? 0;

  /// Downloads changed packs listed in the manifest. Returns the pack keys that were updated.
  Future<List<String>> refresh() async {
    final updated = <String>[];
    try {
      final etag = await _db.meta(_kManifestEtag);
      final m = await _api.request<Map<String, dynamic>>('GET', '/v1/content/manifest',
          auth: false,
          headers: {'If-None-Match': ?etag},
          validateStatus: (s) => s == 200 || s == 304);
      if (m.statusCode == 304) return updated;
      for (final p in (m.data!['packs'] as List).cast<Map<String, dynamic>>()) {
        final key = p['pack_key'] as String;
        final ver = p['version'] as int;
        if (ver <= version(key)) continue;
        final r = await _api.request<List<int>>('GET', p['url'] as String, auth: false, responseType: ResponseType.bytes);
        final bytes = r.data!;
        if (sha256.convert(bytes).toString() != p['sha256']) continue; // corrupted or tampered: skip
        final doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        if ((doc['pack_schema_version'] as int? ?? 1) > supportedPackSchemaVersion) continue;
        await _db.into(_db.contentCache).insertOnConflictUpdate(ContentCacheCompanion.insert(
            packKey: key, version: ver, sha256: p['sha256'] as String, payload: utf8.decode(bytes)));
        _downloaded[key] = doc;
        updated.add(key);
      }
      final newEtag = m.headers.value('etag');
      if (newEtag != null) await _db.setMeta(_kManifestEtag, newEtag);
    } on ApiError {
      // offline: bundled/cached content keeps working
    } on DioException {
      // same
    }
    return updated;
  }
}
