import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/config/app_config.dart';
import 'package:pashmak_app/core/config/config_repository.dart';
import 'package:pashmak_app/core/content/content_repository.dart';
import 'package:pashmak_app/core/content/copy_resolver.dart';

import 'helpers.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 8);

  group('AppConfig', () {
    test('bundled default.json exposes every typed getter', () async {
      final cfg = AppConfig(jsonDecode(realAssets().files['assets/config/default.json']!) as Map<String, dynamic>);
      expect(cfg.freeActiveHabits, 3);
      expect(cfg.freeExercises, ['breathing_basic', 'breathing_square']);
      expect(cfg.energyPerGoal, 5);
      expect(cfg.dailyEnergyTarget, 20);
      expect((cfg.growthYoung, cfg.growthAdult), (7, 30));
      expect((cfg.questsDailyCount, cfg.questsDailyRewardCoins), (4, 10));
      expect((cfg.shopRotationSize, cfg.shopRefreshCost, cfg.shopSellRatio), (6, 30, 0.5));
      expect((cfg.recommendCountFree, cfg.recommendCountTrial), (3, 4));
      expect(cfg.recommenderWeights.needWeight, 10);
      expect(cfg.feature('pause_mode'), isTrue);
      expect(cfg.plans.map((p) => p.productId), contains('premium_12m'));
      expect(cfg.plans.firstWhere((p) => p.highlight).productId, 'premium_12m');
      expect(cfg.trialEnabled && cfg.trialDays == 7 && cfg.trialReminderDay == 6, isTrue);
      expect(cfg.paywallTrigger('fourth_habit'), isTrue);
      expect(cfg.graceDays, 3);
      expect(cfg.energyCap, 100);
      expect(cfg.adventureLocation('alley')!.energyCost, 20);
      expect(cfg.streakFreezesPerMonth, 1);
      expect(cfg.notifMaxPerDay, 3);
      expect(cfg.notifComebackDays, [3, 7, 14]);
      expect(cfg.notifTypeEnabled('morning'), isTrue);
      expect(cfg.safetyLowMoodCount, 3);
      expect(cfg.feature('rive_cat'), isFalse);
      expect(cfg.minSupportedVersion, '1.0.0');
    });

    test('merge: objects merge, arrays and scalars are replaced', () {
      final m = AppConfig.merge({
        'a': {'x': 1, 'y': 2},
        'list': [1, 2],
        'keep': true,
      }, {
        'a': {'y': 9, 'z': 3},
        'list': [7],
      });
      expect(m, {
        'a': {'x': 1, 'y': 9, 'z': 3},
        'list': [7],
        'keep': true,
      });
    });
  });

  group('ConfigRepository', () {
    test('works offline from bundled assets; refresh failure keeps defaults', () async {
      final h = ApiHarness(t0);
      final repo = ConfigRepository(h.db, realAssets(), h.api, h.clock);
      expect((await repo.load()).freeActiveHabits, 3);
      h.mock.onPost('/v1/auth/device', (s) => s.throws(0, DioException.connectionError(requestOptions: RequestOptions(path: ''), reason: 'x')), data: Matchers.any);
      expect(await repo.refresh(), isFalse);
      expect(repo.current.freeActiveHabits, 3);
    });

    test('override from server is cached with ETag, merged, and 304 keeps it; 6h throttle', () async {
      final h = ApiHarness(t0);
      await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 1)), refresh: 'r', userId: 'u'));
      final repo = ConfigRepository(h.db, realAssets(), h.api, h.clock);
      await repo.load();
      h.mock.onGet('/v1/config', (s) => s.reply(200, {
            'version': 2,
            'payload': {'limits': {'free_active_habits': 5}},
            'experiments': {'paywall_layout': 'b'},
            'etag': '"v2-x"'
          }, headers: {'etag': ['"v2-x"'], 'content-type': ['application/json']}));
      expect(await repo.refresh(), isTrue);
      expect(repo.current.freeActiveHabits, 5);
      expect(repo.current.freeCustomHabits, 0, reason: 'unspecified keys keep bundled defaults');
      expect(repo.experiments['paywall_layout'], 'b');
      // fresh repository instance reads the cache without network
      final again = ConfigRepository(h.db, realAssets(), h.api, h.clock);
      expect((await again.load()).freeActiveHabits, 5);
      // within 6h: no request at all
      expect(await repo.refresh(), isFalse);
      // after 6h: conditional request, 304 -> unchanged
      h.clock.advance(const Duration(hours: 7));
      h.mock.onGet('/v1/config', (s) => s.reply(304, null), headers: {'If-None-Match': '"v2-x"'});
      expect(await repo.refresh(), isFalse);
      expect(repo.current.freeActiveHabits, 5);
    });

    test('a corrupted cache never breaks startup', () async {
      final h = ApiHarness(t0);
      await h.db.setMeta('config_cache', '{not json');
      final repo = ConfigRepository(h.db, realAssets(), h.api, h.clock);
      expect((await repo.load()).freeActiveHabits, 3);
    });
  });

  group('CopyResolver', () {
    CopyResolver make({String day = '2026-10-05', String? cat, bool debug = false, Map<String, dynamic> dl = const {}}) => CopyResolver(
          bundled: {
            'plain': 'سلام',
            'vars': 'تو {n} تا و {CAT_NAME} و {APP_NAME} و {habit}',
            'variants': ['الف', 'ب', 'ج'],
          },
          downloaded: dl,
          appName: 'اپ',
          defaultCatName: 'ملوس',
          catName: cat,
          today: () => day,
          debug: debug,
        );

    test('variables, Persian digits, cat-name fallback', () {
      final c = make();
      expect(c.t('vars', {'n': 3, 'habit': 'آب'}), 'تو ۳ تا و ملوس و اپ و آب');
      expect(make(cat: 'پشمک').t('vars', {'n': 12, 'habit': 'x'}), contains('پشمک'));
      expect(make(cat: '  ').t('vars'), contains('ملوس'));
    });

    test('variants are deterministic per key and day, and vary over days', () {
      final seen = <String>{};
      for (var d = 1; d <= 28; d++) {
        final day = '2026-10-${d.toString().padLeft(2, '0')}';
        final a = make(day: day).t('variants');
        expect(make(day: day).t('variants'), a);
        seen.add(a);
      }
      expect(seen.length, 3);
      expect(CopyResolver.hash('abc'), CopyResolver.hash('abc'));
      expect(CopyResolver.hash('abc'), isNot(CopyResolver.hash('abd')));
    });

    test('downloaded overrides bundled; missing key: debug shows key, release is empty and reports', () {
      expect(make(dl: {'plain': 'تازه'}).t('plain'), 'تازه');
      final missing = <String>[];
      final rel = CopyResolver(bundled: const {}, appName: 'a', defaultCatName: 'c', today: () => 'x', onMissing: missing.add);
      expect(rel.t('nope.key'), '');
      expect(missing, ['nope.key']);
      expect(make(debug: true).t('nope.key'), 'nope.key');
    });

    test('every {variable} in the real copy pack is a known one', () {
      final doc = jsonDecode(realAssets().files['assets/content/copy_fa.json']!) as Map<String, dynamic>;
      final known = {'APP_NAME', 'CAT_NAME', 'n', 'habit', 'place', 'date', 'time', 'item', 'day', 'days'};
      for (final e in (doc['entries'] as Map<String, dynamic>).entries) {
        final texts = e.value is List ? (e.value as List).cast<String>() : [e.value as String];
        for (final t in texts) {
          for (final m in RegExp(r'\{([^{}]*)\}').allMatches(t)) {
            expect(known, contains(m[1]), reason: e.key);
          }
        }
      }
    });
  });

  group('ContentRepository', () {
    String pack(String key, int version, Map<String, dynamic> entries, {int schema = 1}) => jsonEncode({
          'pack_key': key,
          'version': version,
          'pack_schema_version': schema,
          'locale': 'fa',
          'min_app_version': '1.0.0',
          'entries': entries,
        });

    test('bundled packs load offline; copy works through the resolver', () async {
      final h = ApiHarness(t0);
      final repo = ContentRepository(h.db, realAssets(), h.api, appVersion: '1.0.0');
      await repo.load();
      for (final k in bundledPackKeys) {
        expect(repo.entries(k), isNotNull, reason: k);
      }
      final brand = repo.bundledEntries('brand');
      final copy = CopyResolver(
          bundled: repo.bundledEntries('copy_fa'),
          appName: brand['app_name'] as String,
          defaultCatName: brand['cat_default_name'] as String,
          today: () => '2026-10-05');
      expect(copy.t('checkin.prompt'), isNotEmpty);
      expect(copy.t('onboarding.welcome.title'), contains(brand['cat_default_name'] as String));
    });

    test('downloads a newer pack, verifies sha256, caches; tampered pack is skipped', () async {
      final h = ApiHarness(t0);
      final repo = ContentRepository(h.db, realAssets(), h.api, appVersion: '1.0.0');
      await repo.load();
      final good = pack('brand', 2, {'app_name': 'جدید', 'cat_default_name': 'گربه', 'support_contact': {'email': '', 'channel_url': ''}});
      final bad = pack('shop_items', 2, {}).replaceAll('2', '3');
      h.mock.onPost('/v1/auth/device', (s) => s.reply(200, {}), data: Matchers.any);
      h.mock.onGet('/v1/content/manifest', (s) => s.reply(200, {
            'packs': [
              {'pack_key': 'brand', 'version': 2, 'sha256': sha256.convert(utf8.encode(good)).toString(), 'size': good.length, 'min_app_version': '1.0.0', 'url': '/v1/content/packs/brand/2'},
              {'pack_key': 'shop_items', 'version': 2, 'sha256': sha256.convert(utf8.encode('other')).toString(), 'size': bad.length, 'min_app_version': '1.0.0', 'url': '/v1/content/packs/shop_items/2'},
            ]
          }, headers: {'etag': ['"m1"'], 'content-type': ['application/json']}));
      h.mock.onGet('/v1/content/packs/brand/2', (s) => s.reply(200, utf8.encode(good)));
      h.mock.onGet('/v1/content/packs/shop_items/2', (s) => s.reply(200, utf8.encode(bad)));
      expect(await repo.refresh(), ['brand']);
      expect((repo.entries('brand') as Map)['app_name'], 'جدید');
      expect(repo.version('shop_items'), 1, reason: 'sha mismatch must be ignored');
      // survives restart
      final again = ContentRepository(h.db, realAssets(), h.api, appVersion: '1.0.0');
      await again.load();
      expect((again.entries('brand') as Map)['app_name'], 'جدید');
    });

    test('packs with an unknown pack_schema_version are ignored', () async {
      final h = ApiHarness(t0);
      final repo = ContentRepository(h.db, realAssets(), h.api, appVersion: '1.0.0');
      await repo.load();
      final future = pack('brand', 9, {}, schema: 99);
      h.mock.onPost('/v1/auth/device', (s) => s.reply(200, {}), data: Matchers.any);
      h.mock.onGet('/v1/content/manifest', (s) => s.reply(200, {
            'packs': [
              {'pack_key': 'brand', 'version': 9, 'sha256': sha256.convert(utf8.encode(future)).toString(), 'size': 1, 'min_app_version': '1.0.0', 'url': '/p'}
            ]
          }));
      h.mock.onGet('/p', (s) => s.reply(200, utf8.encode(future)));
      expect(await repo.refresh(), isEmpty);
      expect(repo.version('brand'), 1);
    });
  });
}
