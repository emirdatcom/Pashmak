import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/db/app_database.dart';
import 'package:pashmak_app/core/db/connection.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

void main() {
  final key = List.filled(32, 'ab').join();

  test('in-memory DB creates every table and seeds wallet/streak', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tables = (await db.customSelect("select name from sqlite_master where type='table'").get())
        .map((r) => r.read<String>('name'))
        .toSet();
    for (final t in [
      'app_meta', 'user_settings', 'habits', 'habit_logs', 'checkins', 'exercise_sessions', 'wallet',
      'wallet_ledger', 'adventures', 'inventory', 'streak_state', 'safety_flags', 'notification_log',
      'entitlement_cache', 'outbox', 'analytics_queue', 'content_cache', //
    ]) {
      expect(tables, contains(t));
    }
    expect((await db.select(db.wallet).get()).single.id, 1);
    expect((await db.select(db.streakState).get()).single.freezesLeft, 1);
    await db.setMeta('install_id', 'x');
    expect(await db.meta('install_id'), 'x');
    await db.setSetting('day_start_hour', '4');
    expect(await db.setting('day_start_hour'), '4');
  });

  test('wallet_ledger enforces idempotency (unique reason+ref_id)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> add(String id) => db.into(db.walletLedger).insert(WalletLedgerCompanion.insert(
        id: id, currency: 'coins', delta: 5, reason: 'iap_coins', refId: 'p1', createdAt: 1));
    await add('a');
    expect(() => add('b'), throwsA(anything));
  });

  test('database file is really encrypted (SQLCipher)', () async {
    final dir = Directory.systemTemp.createTempSync('db_enc');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/app.db');

    final db = AppDatabase(openEncrypted(file, key));
    await db.setMeta('secret', 'my private note');
    await db.close();

    // Raw bytes contain neither the SQLite header nor the plaintext.
    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
    expect(String.fromCharCodes(bytes), isNot(contains('my private note')));

    // Opening without a key (plain SQLite API) fails.
    final plain = s3.sqlite3.open(file.path);
    expect(() => plain.select('select * from app_meta'), throwsA(isA<s3.SqliteException>()));
    plain.close();

    // A wrong key fails; the right key reads the data back.
    final wrong = AppDatabase(openEncrypted(file, List.filled(32, 'cd').join()));
    await expectLater(wrong.meta('secret'), throwsA(anything));
    final ok = AppDatabase(openEncrypted(file, key));
    addTearDown(ok.close);
    expect(await ok.meta('secret'), 'my private note');
  });
}
