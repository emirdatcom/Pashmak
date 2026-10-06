import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/db/app_database.dart';
import 'package:pashmak_app/core/analytics/analytics_event.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/features/backup/data/backup_service.dart';
import 'package:pashmak_app/features/backup/domain/crypto.dart';
import 'package:pashmak_app/features/backup/domain/snapshot.dart';
import 'package:pashmak_app/features/backup/domain/snapshot_upgraders.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/wallet/domain/wallet_service.dart';

import 'core_loop_helpers.dart';
import 'helpers.dart';

/// Minimal in-memory `/v1/backup` server that only keeps opaque bytes, like the real one.
class FakeBackupServer implements HttpClientAdapter {
  Uint8List? blob;
  Map<String, String> headers = {};
  Uint8List? lastBody;
  bool corruptSha = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    if (o.path != '/v1/backup') return ResponseBody.fromString('{"error":{"code":"NOT_FOUND","message":"x","request_id":"q"}}', 404, headers: {'content-type': ['application/json']});
    switch (o.method) {
      case 'PUT':
        final b = BytesBuilder();
        await for (final c in body!) {
          b.add(c);
        }
        lastBody = b.toBytes();
        blob = lastBody;
        headers = {for (final k in ['X-Backup-Schema', 'X-Backup-Sha256', 'X-Kdf-Params']) k.toLowerCase(): o.headers[k]?.toString() ?? ''};
        return ResponseBody.fromString('{"updated_at":"2026-10-05T08:00:00Z"}', 200, headers: {'content-type': ['application/json']});
      case 'GET':
        if (blob == null) return ResponseBody.fromString('{"error":{"code":"NOT_FOUND","message":"x","request_id":"q"}}', 404, headers: {'content-type': ['application/json']});
        return ResponseBody.fromBytes(blob!, 200, headers: {
          'x-backup-schema': [headers['x-backup-schema']!],
          'x-backup-sha256': [corruptSha ? 'deadbeef' : headers['x-backup-sha256']!],
          'x-kdf-params': [headers['x-kdf-params']!],
          'x-backup-updated-at': ['2026-10-05T08:00:00Z'],
        });
      default:
        blob = null;
        return ResponseBody.fromString('', 204);
    }
  }
}

final fastKdf = KdfParams(memoryKiB: 64, iterations: 1, parallelism: 1, salt: Uint8List.fromList(List.generate(16, (i) => i + 1)));

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 8);
  late FakeBackupServer server;

  Future<(ApiHarness, Loop, BackupService)> device() async {
    final h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 2)), refresh: 'r', userId: 'u1'));
    h.api.dio.httpClientAdapter = server;
    final l = Loop(t0, database: h.db, dayStartHour: 0);
    final svc = BackupService(db: h.db, api: h.api, clock: h.clock, secrets: MemorySecretStore(), analytics: l.analytics, kdf: () async => fastKdf);
    return (h, l, svc);
  }

  setUp(() => server = FakeBackupServer());

  test('setup challenge: only the right four characters pass', () {
    final c = SetupChallenge('ABCD-EFGH-JKLM-NPQR-STUV-WXYZ', [0, 5, 10, 23]);
    expect(c.verify('AFLz'), isTrue);
    expect(c.verify('A F L Z'), isTrue);
    expect(c.verify('AFLX'), isFalse);
    expect(c.verify('AFL'), isFalse);
  });

  test('device A backs up, device B restores with the recovery code: data identical; server never sees plaintext', () async {
    final (ha, la, a) = await device();
    final water = await la.habits.create(const HabitDraft(templateKey: 'water'));
    await la.habits.complete(water);
    await la.checkins.submit(2, note: 'یادداشت خیلی خصوصی من');
    await la.wallet.grant(Currency.coins, 77, 'promo', 'x');
    await ha.db.setMeta('cat_name', 'پشمک');
    await ha.db.setMeta('cat_fur', 'tricolor');
    await ha.db.setMeta('item_hue:hat_cap', '95');
    await ha.db.into(ha.db.discoveriesFound).insert(DiscoveriesFoundCompanion.insert(discoveryKey: 'd1', foundAt: 1));
    final challenge = a.beginSetup();
    await a.enable(challenge);
    expect(await a.isEnabled(), isTrue);
    expect(await a.backupNow(), BackupOutcome.done);
    expect(await a.lastBackupAt(), isNotNull);

    // server side: opaque, high-entropy, headers per contract
    final body = server.lastBody!;
    expect(utf8.decode(body, allowMalformed: true), isNot(contains('یادداشت')));
    expect(utf8.decode(body, allowMalformed: true), isNot(contains('habit')));
    expect(body.toSet().length, greaterThan(200), reason: 'ciphertext should look random');
    expect(server.headers['x-backup-schema'], '1');
    expect(server.headers['x-backup-sha256'], BackupCrypto.sha256Hex(body));
    expect(jsonDecode(server.headers['x-kdf-params']!), containsPair('alg', 'argon2id'));

    // device B: fresh install with a different habit that the restore must replace
    final (hb, lb, b) = await device();
    await lb.habits.create(const HabitDraft(templateKey: 'walk'));
    final remote = (await b.fetchRemote())!;
    final snap = await b.decrypt(remote, challenge.code.toLowerCase());
    final summary = SnapshotImporter(hb.db).summarize(snap);
    expect((summary.habits, summary.checkins, summary.logs), (1, 1, 1));
    await b.restore(snap, codeInput: challenge.code);

    expect((await lb.habits.activeHabits()).map((h) => h.templateKey), ['water']);
    final c = await hb.db.select(hb.db.checkins).getSingle();
    expect((c.moodLevel, c.note), (2, 'یادداشت خیلی خصوصی من'));
    expect((await lb.wallet.balance()).coins, 77);
    expect(await hb.db.meta('cat_name'), 'پشمک');
    expect(await hb.db.meta('cat_fur'), 'tricolor', reason: 'the cat profile travels with the backup');
    expect(await hb.db.meta('item_hue:hat_cap'), '95');
    expect((await hb.db.select(hb.db.discoveriesFound).get()).map((d) => d.discoveryKey), ['d1']);
    expect(await b.isEnabled(), isTrue, reason: 'the code is kept so automatic backups continue');
  });

  test('wrong or malformed code: clear error and nothing local changes', () async {
    final (_, la, a) = await device();
    await la.habits.create(const HabitDraft(templateKey: 'water'));
    final ch = a.beginSetup();
    await a.enable(ch);
    await a.backupNow();

    final (_, lb, b) = await device();
    await lb.habits.create(const HabitDraft(templateKey: 'walk'));
    final remote = (await b.fetchRemote())!;
    for (final bad in ['AAAA-AAAA-AAAA-AAAA-AAAA-AAAA', 'short', '']) {
      await expectLater(b.decrypt(remote, bad), throwsA(isA<BackupDecryptError>()));
    }
    expect((await lb.habits.activeHabits()).map((h) => h.templateKey), ['walk']);
  });

  test('no backup on the server → null; corrupted download is rejected', () async {
    final (_, la, a) = await device();
    expect(await a.fetchRemote(), isNull);
    await la.habits.create(const HabitDraft(templateKey: 'water'));
    await a.enable(a.beginSetup());
    await a.backupNow();
    server.corruptSha = true;
    await expectLater(a.fetchRemote(), throwsA(isA<BackupBlobCorrupt>()));
  });

  test('backup without setup does nothing; deleting the remote backup disables it', () async {
    final (_, _, a) = await device();
    expect(await a.backupNow(), BackupOutcome.notEnabled);
    await a.enable(a.beginSetup());
    await a.backupNow();
    await a.deleteRemote();
    expect(server.blob, isNull);
    expect(await a.isEnabled(), isFalse);
  });

  test('the snapshot leaves out outbox, analytics, caches and the entitlement cache', () async {
    final (h, l, _) = await device();
    await l.analytics.track(AnalyticsEvent.appOpened);
    await h.db.setMeta('install_id', 'secret-install');
    final snap = await SnapshotExporter(h.db, h.clock).export();
    for (final k in ['outbox', 'analytics_queue', 'content_cache', 'entitlement_cache', 'notification_log', 'app_meta']) {
      expect(snap.containsKey(k), isFalse, reason: k);
    }
    expect(jsonEncode(snap), isNot(contains('secret-install')));
    expect(snap['schema_version'], 1);
  });

  group('snapshot upgraders', () {
    final v1 = {'schema_version': 1, 'exported_at': '2026-01-01T00:00:00Z', 'habits': [], 'checkins': [], 'habit_logs': []};

    test('old schema versions are upgraded step by step', () {
      final up = SnapshotUpgraders(current: 3, chain: {
        1: (s) => {...s, 'habits': <dynamic>[], 'added_in_2': true},
        2: (s) => {...s, 'added_in_3': true},
      });
      final out = up.upgrade(Map<String, dynamic>.of(v1), 1);
      expect(out['schema_version'], 3);
      expect(out['added_in_2'], isTrue);
      expect(out['added_in_3'], isTrue);
    });

    test('a snapshot from a newer app is refused; a missing step is a programming error', () {
      expect(() => SnapshotUpgraders(current: 1).upgrade({}, 2), throwsA(isA<SnapshotTooNew>()));
      expect(() => SnapshotUpgraders(current: 3, chain: {1: (s) => s}).upgrade({}, 1), throwsStateError);
    });

    test('an old-format snapshot restores into a usable database (singletons re-seeded)', () async {
      final (h, l, _) = await device();
      await SnapshotImporter(h.db).restore(Map<String, dynamic>.of(v1));
      expect(await h.db.select(h.db.wallet).get(), hasLength(1));
      expect(await h.db.select(h.db.streakState).get(), hasLength(1));
      expect(await l.habits.activeHabits(), isEmpty);
    });
  });
}
