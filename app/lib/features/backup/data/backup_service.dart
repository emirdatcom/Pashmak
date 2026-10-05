import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/time/clock.dart';
import '../domain/crypto.dart';
import '../domain/snapshot.dart';
import '../domain/snapshot_upgraders.dart';

/// What the user must retype to prove they wrote the code down: 4 random positions.
class SetupChallenge {
  SetupChallenge(this.code, this.positions);
  final String code; // formatted, with dashes
  final List<int> positions; // 0-based indexes into the 24 raw characters

  String get raw => code.replaceAll('-', '');

  bool verify(String typed) {
    final t = typed.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    return t.length == positions.length && [for (var i = 0; i < positions.length; i++) raw[positions[i]]].join() == t;
  }
}

class RemoteBackup {
  const RemoteBackup({required this.blob, required this.schema, required this.sha256, required this.kdf, required this.updatedAt});
  final Uint8List blob;
  final int schema;
  final String sha256;
  final KdfParams kdf;
  final DateTime? updatedAt;
}

enum BackupOutcome { done, notEnabled, tooLarge, failed, skippedMetered }

class BackupBlobCorrupt implements Exception {}

/// Encrypted E2E backup (docs/30 §10). The server only ever sees an opaque AES-GCM blob.
class BackupService {
  BackupService({
    required AppDatabase db,
    required ApiClient api,
    required Clock clock,
    required SecretStore secrets,
    AnalyticsService analytics = const NoopAnalytics(),
    Future<KdfParams> Function()? kdf,
  })  : _db = db,
        _api = api,
        _clock = clock,
        _secrets = secrets,
        _analytics = analytics,
        _kdf = kdf ?? KdfParams.calibrate;

  final AppDatabase _db;
  final ApiClient _api;
  final Clock _clock;
  final SecretStore _secrets;
  final AnalyticsService _analytics;
  final Future<KdfParams> Function() _kdf;

  static const _kCode = 'backup_recovery_code';
  static const _kEnabled = 'backup_enabled';
  static const _kLast = 'backup_last_at';
  static const _kKdf = 'backup_kdf';
  static const maxBlobBytes = 5 * 1024 * 1024;
  static const meteredLimitBytes = 1024 * 1024;

  Future<bool> isEnabled() async => await _db.meta(_kEnabled) == 'true' && await _secrets.read(_kCode) != null;

  Future<DateTime?> lastBackupAt() async {
    final v = int.tryParse(await _db.meta(_kLast) ?? '');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  SetupChallenge beginSetup([Random? random]) {
    final r = random ?? Random.secure();
    final positions = <int>{};
    while (positions.length < 4) {
      positions.add(r.nextInt(24));
    }
    return SetupChallenge(RecoveryCode.generate(r), positions.toList()..sort());
  }

  /// Call after the user confirmed the code: stores it in secure storage (needed for automatic backups).
  Future<void> enable(SetupChallenge c) async {
    await _secrets.write(_kCode, c.raw);
    await _db.setMeta(_kEnabled, 'true');
    unawaited(_analytics.track(AnalyticsEvent.backupEnabled));
  }

  Future<void> disable() async {
    await _secrets.delete(_kCode);
    await _db.setMeta(_kEnabled, 'false');
  }

  Future<KdfParams> _params() async {
    final cached = await _db.meta(_kKdf);
    if (cached != null) {
      try {
        return KdfParams.fromHeader(cached);
      } catch (_) {}
    }
    final p = await _kdf();
    await _db.setMeta(_kKdf, p.toHeader());
    return p;
  }

  /// Exports → gzip → AES-256-GCM(Argon2id(code)) → `PUT /v1/backup`.
  Future<BackupOutcome> backupNow({bool auto = false, bool unmetered = true}) async {
    final code = await _secrets.read(_kCode);
    if (code == null || await _db.meta(_kEnabled) != 'true') return BackupOutcome.notEnabled;
    final params = await _params();
    final key = await deriveKey(code, params);
    final plain = await SnapshotExporter(_db, _clock).exportGzip();
    final blob = await BackupCrypto.encrypt(plain, key, currentSnapshotSchema);
    if (blob.length > maxBlobBytes) return BackupOutcome.tooLarge;
    if (auto && !unmetered && blob.length > meteredLimitBytes) return BackupOutcome.skippedMetered;
    try {
      await _api.request<Map<String, dynamic>>('PUT', '/v1/backup', data: blob, headers: {
        'Content-Type': 'application/octet-stream',
        'X-Backup-Schema': '$currentSnapshotSchema',
        'X-Backup-Sha256': BackupCrypto.sha256Hex(blob),
        'X-Kdf-Params': params.toHeader(),
      });
    } on ApiError catch (e) {
      if (e.code == 'BACKUP_TOO_LARGE') return BackupOutcome.tooLarge;
      return BackupOutcome.failed;
    }
    await _db.setMeta(_kLast, '${_clock.now().millisecondsSinceEpoch}');
    unawaited(_analytics.track(AnalyticsEvent.backupCompleted, {'auto': auto}));
    return BackupOutcome.done;
  }

  /// null = the account has no backup (404).
  Future<RemoteBackup?> fetchRemote() async {
    try {
      final r = await _api.request<List<int>>('GET', '/v1/backup', responseType: ResponseType.bytes);
      final blob = Uint8List.fromList(r.data!);
      final sha = r.headers.value('x-backup-sha256') ?? '';
      if (BackupCrypto.sha256Hex(blob) != sha.toLowerCase()) throw BackupBlobCorrupt();
      return RemoteBackup(
        blob: blob,
        schema: int.parse(r.headers.value('x-backup-schema') ?? '1'),
        sha256: sha,
        kdf: KdfParams.fromHeader(r.headers.value('x-kdf-params') ?? ''),
        updatedAt: DateTime.tryParse(r.headers.value('x-backup-updated-at') ?? ''),
      );
    } on ApiError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Decrypts with the code the user typed. Throws [BackupDecryptError] (wrong code / corrupt) and
  /// [SnapshotTooNew] (backup from a newer app). Nothing local changes here.
  Future<Map<String, dynamic>> decrypt(RemoteBackup remote, String codeInput) async {
    final code = RecoveryCode.normalize(codeInput);
    if (code == null) throw const BackupDecryptError('wrong_code');
    if (remote.schema > currentSnapshotSchema) throw SnapshotTooNew(remote.schema);
    final key = await deriveKey(code, remote.kdf);
    final plain = await BackupCrypto.decrypt(remote.blob, key, remote.schema);
    final snap = SnapshotImporter.decodeGzip(plain);
    snap['schema_version'] = remote.schema;
    return snap;
  }

  /// Replaces local data with the (already decrypted) snapshot and remembers the code for future backups.
  Future<void> restore(Map<String, dynamic> snapshot, {String? codeInput}) async {
    await SnapshotImporter(_db).restore(snapshot);
    if (codeInput != null) {
      final code = RecoveryCode.normalize(codeInput);
      if (code != null) {
        await _secrets.write(_kCode, code);
        await _db.setMeta(_kEnabled, 'true');
      }
    }
    unawaited(_analytics.track(AnalyticsEvent.restoreCompletedBackup));
  }

  Future<void> deleteRemote() async {
    await _api.request<void>('DELETE', '/v1/backup');
    await _db.setMeta(_kLast, '');
    await disable();
  }
}
