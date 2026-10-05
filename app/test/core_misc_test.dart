import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/analytics/analytics_event.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/config/app_config.dart';
import 'package:pashmak_app/core/config/config_repository.dart';
import 'package:pashmak_app/core/content/content_repository.dart';
import 'package:pashmak_app/core/db/app_database.dart';
import 'package:pashmak_app/core/flavor.dart';
import 'package:pashmak_app/core/network/api_error.dart';
import 'package:pashmak_app/core/outbox/outbox_worker.dart';
import 'package:pashmak_app/core/providers.dart';
import 'package:pashmak_app/core/router/redirect.dart';
import 'package:pashmak_app/core/router/routes.dart';
import 'package:pashmak_app/core/theme/app_theme.dart';
import 'package:pashmak_app/core/time/clock.dart';
import 'package:pashmak_app/core/util/version.dart';
import 'package:pashmak_app/features/system/db_error_screen.dart';
import 'package:pashmak_app/features/system/force_update_screen.dart';

import 'helpers.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 8);

  group('outbox', () {
    test('backoff grows exponentially and caps at 6 hours', () {
      expect(outboxBackoff(0), const Duration(seconds: 30));
      expect(outboxBackoff(1), const Duration(minutes: 1));
      expect(outboxBackoff(3), const Duration(minutes: 4));
      expect(outboxBackoff(30), const Duration(hours: 6));
    });

    test('failed operation is retried with backoff and removed after success', () async {
      final db = memoryDb();
      final clock = FakeClock(t0);
      var calls = 0;
      var failing = true;
      final w = OutboxWorker(db, clock, {
        'purchase_verify': (p) async {
          calls++;
          if (failing) throw ApiError(code: 'MARKET_UNAVAILABLE', status: 503);
          expect(p['token'], 't');
          return OutboxResult.done;
        }
      });
      await w.enqueue('purchase_verify', {'token': 't'});
      expect(await w.runDue(), 0);
      expect(calls, 1);
      expect(await w.pending(), 1);
      // not due yet
      expect(await w.runDue(), 0);
      expect(calls, 1);
      final row = (await db.select(db.outbox).get()).single;
      expect(row.attempts, 1);
      expect(row.lastError, contains('MARKET_UNAVAILABLE'));
      // due after the backoff window
      clock.advance(const Duration(minutes: 2));
      failing = false;
      expect(await w.runDue(), 1);
      expect(await w.pending(), 0);
    });

    test('permanent errors (4xx) are dropped; unknown kinds stay queued', () async {
      final db = memoryDb();
      final w = OutboxWorker(db, FakeClock(t0), {
        'trial_start': (_) async => throw ApiError(code: 'TRIAL_ALREADY_USED', status: 409),
      });
      await w.enqueue('trial_start', {});
      await w.enqueue('future_kind', {});
      await w.runDue();
      final kinds = (await db.select(db.outbox).get()).map((r) => r.kind).toList();
      expect(kinds, ['future_kind']);
    });
  });

  group('analytics queue', () {
    test('whitelists props, never stores forbidden ones, honors opt-out and the cap', () async {
      final db = memoryDb();
      final a = QueueAnalytics(db, FakeClock(t0), sessionId: () => 's1', commonProps: () => {'app_version': '1.0.0', 'market': 'bazaar'});
      await a.track(AnalyticsEvent.checkinCompleted, {'has_note': true, 'mood_level': 2, 'note': 'secret', 'bogus': 1, 'exp_paywall': 'b'});
      final row = (await db.select(db.analyticsQueue).get()).single;
      expect(row.name, 'checkin_completed');
      expect(jsonDecode(row.props), {'app_version': '1.0.0', 'market': 'bazaar', 'has_note': true, 'exp_paywall': 'b'});
      expect(row.sessionId, 's1');
      await db.setSetting('analytics_opt_out', 'true');
      await a.track(AnalyticsEvent.appOpened, {'source': 'launcher'});
      expect(await db.select(db.analyticsQueue).get(), isEmpty, reason: 'opt-out empties the queue');
    });

    test('queue is capped at 5000 rows (oldest dropped)', () async {
      final db = memoryDb();
      await db.batch((b) => b.insertAll(db.analyticsQueue, [
            for (var i = 0; i < QueueAnalytics.maxRows; i++)
              AnalyticsQueueCompanion.insert(id: 'e$i', name: 'app_opened', props: '{}', ts: i, sessionId: 's'),
          ]));
      await QueueAnalytics(db, FakeClock(t0), sessionId: () => 's').track(AnalyticsEvent.appOpened);
      final rows = await db.select(db.analyticsQueue).get();
      expect(rows.length, QueueAnalytics.maxRows);
      expect(rows.any((r) => r.id == 'e0'), isFalse);
    });

    test('generated enum matches the shared catalog (client-side events only)', () {
      final cat = jsonDecode(File('../config-data/analytics/events.json').readAsStringSync()) as Map<String, dynamic>;
      final client = (cat['events'] as List).cast<Map<String, dynamic>>().where((e) => e['server_side'] != true).map((e) => e['name']).toSet();
      expect(AnalyticsEvent.values.map((e) => e.wireName).toSet(), client);
      expect(analyticsForbiddenProps, containsAll(['mood_level', 'note']));
    });
  });

  group('router redirect', () {
    String? r(String loc, {bool onboarded = true, String app = '1.0.0', String min = '1.0.0'}) =>
        appRedirect(location: loc, onboardingCompleted: onboarded, appVersion: app, minSupportedVersion: min);

    test('onboarding gate', () {
      expect(r(Routes.home, onboarded: false), '/onboarding/1');
      expect(r('/onboarding/2', onboarded: false), isNull);
      expect(r(Routes.splash, onboarded: false), '/onboarding/1');
      expect(r(Routes.splash), Routes.home);
      expect(r('/onboarding/1'), Routes.home);
      expect(r(Routes.home), isNull);
    });
    test('hard update outranks everything except safety', () {
      expect(r(Routes.home, app: '0.9.0'), Routes.update);
      expect(r(Routes.update, app: '0.9.0'), isNull);
      expect(r(Routes.home, app: '0.9.0', onboarded: false), Routes.update);
      expect(r(Routes.update), Routes.home);
      expect(r(Routes.safety, app: '0.1.0', onboarded: false), isNull, reason: 'safety is never gated');
    });
    test('version compare', () {
      expect(compareVersions('1.10.0', '1.9.9'), 1);
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('0.9.9+3', '1.0.0'), -1);
    });
  });

  group('system screens (RTL)', () {
    Future<Widget> app(Widget child) async {
      final db = memoryDb();
      addTearDown(db.close);
      final h = ApiHarness(t0);
      final content = ContentRepository(db, realAssets(), h.api, appVersion: '1.0.0');
      await content.load();
      final config = ConfigRepository(db, realAssets(), h.api, FakeClock(t0));
      await config.load();
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          contentRepositoryProvider.overrideWithValue(content),
          configRepositoryProvider.overrideWithValue(config),
          flavorProvider.overrideWithValue(Flavor.myket),
          applicationIdProvider.overrideWithValue('ir.example.catcare'),
          appVersionProvider.overrideWithValue('1.0.0'),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('fa', 'IR'),
          builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
          home: child,
        ),
      );
    }

    testWidgets('ForceUpdateScreen shows localized text, RTL, and a store button', (tester) async {
      await tester.pumpWidget(await app(const ForceUpdateScreen()));
      await tester.pumpAndSettle();
      expect(find.text('برای ادامه باید اپ رو به‌روز کنی.'), findsOneWidget);
      expect(find.text('به‌روزرسانی'), findsOneWidget);
      expect(Directionality.of(tester.element(find.byType(FilledButton))), TextDirection.rtl);
      expect(Flavor.myket.storeUri('x').toString(), 'myket://details?id=x');
      expect(Flavor.bazaar.storeUri('x').toString(), 'bazaar://details?id=x');
    });

    testWidgets('DbErrorScreen calls retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(MaterialApp(
        home: DbErrorScreen(title: 't', body: 'b', retryLabel: 'r', onRetry: () => retried++),
      ));
      await tester.tap(find.text('r'));
      expect(retried, 1);
    });
  });

  test('AppConfig soft-update field present', () {
    final cfg = AppConfig(jsonDecode(realAssets().files['assets/config/default.json']!) as Map<String, dynamic>);
    expect(cfg.recommendedVersion, '1.0.0');
  });
}
