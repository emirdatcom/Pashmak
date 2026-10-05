import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/db/app_database.dart';
import 'package:pashmak_app/core/config/config_repository.dart';
import 'package:pashmak_app/core/content/content_repository.dart';
import 'package:pashmak_app/core/providers.dart';
import 'package:pashmak_app/core/theme/app_theme.dart';
import 'package:pashmak_app/features/safety/presentation/safety_screen.dart';
import 'package:pashmak_app/features/support/data/support_socket.dart';
import 'package:pashmak_app/features/support/presentation/support_screen.dart';
import 'package:pashmak_app/features/support/support_providers.dart';

import 'helpers.dart';

/// A socket whose connection attempts never finish (the chat must work from the HTTP cache alone).
SupportSocket idleSocket(Future<void> Function() onPoll) => SupportSocket(
      baseUri: Uri.parse('wss://x'),
      tokenProvider: () async => 't',
      onPoll: onPoll,
      connector: (u) => Completer<SocketConnection>().future,
    );

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 8);

  Future<void> seed(ApiHarness h, List<(String, String, String)> rows) async {
    var t = 1000;
    for (final r in rows) {
      await h.db.into(h.db.supportMessagesCache).insert(SupportMessagesCacheCompanion.insert(
          id: r.$1, sender: r.$2, body: r.$3, createdAt: t += 60000, status: r.$1.startsWith('f') ? 'failed' : 'sent'));
    }
  }

  Future<(ProviderContainer, ApiHarness)> boot(WidgetTester tester, Widget home, {double scale = 1.0, bool enabled = true, Map<String, dynamic>? info, List<(String, String, String)> rows = const [], bool unverifiedHotlines = false}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 5)), refresh: 'r', userId: 'u1'));
    h.mock.onGet('/v1/support/conversation', (s) => s.reply(200, info ?? {'status': 'none', 'unread_count': 0, 'online': true}));
    h.mock.onGet('/v1/support/messages', (s) => s.reply(200, {'messages': <dynamic>[], 'has_more': false}), queryParameters: {'limit': 50});
    await tester.runAsync(() => seed(h, rows)); // before the screen exists: no concurrent queries
    final assets = realAssets();
    if (!unverifiedHotlines) {
      // The shipped pack keeps verified_at null until the owner confirms the numbers (V9); simulate a confirmed pack.
      const key = 'assets/content/safety.json';
      assets.files[key] = assets.files[key]!.replaceAll('"verified_at": null', '"verified_at": "2026-10-05T00:00:00Z"');
    }
    final content = ContentRepository(h.db, assets, h.api, appVersion: '1.0.0');
    final config = ConfigRepository(h.db, realAssets(), h.api, h.clock);
    await tester.runAsync(() async {
      await content.load();
      await config.load();
    });
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(h.db),
      apiClientProvider.overrideWithValue(h.api),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      contentRepositoryProvider.overrideWithValue(content),
      configRepositoryProvider.overrideWithValue(config),
      clockProvider.overrideWithValue(h.clock),
      appVersionProvider.overrideWithValue('1.0.0'),
      analyticsProvider.overrideWithValue(const NoopAnalytics()),
      supportSocketFactoryProvider.overrideWithValue(idleSocket),
      if (!enabled) supportEnabledProvider.overrideWithValue(false),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(path: '/start', builder: (_, _) => home),
      GoRoute(path: '/safety', builder: (_, _) => const SafetyScreen()),
      GoRoute(path: '/support', builder: (_, _) => const SupportScreen()),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        locale: const Locale('fa', 'IR'),
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(textDirection: TextDirection.rtl, child: w!),
        ),
      ),
    ));
    return (container, h);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('empty chat: friendly prompt, hours banner outside working hours, consent box off by default', (tester) async {
    await boot(tester, const SupportScreen(), info: {'status': 'none', 'unread_count': 0, 'online': false, 'next_online_at': '2026-10-10T05:30:00Z'});
    await settle(tester);
    expect(find.text('سلام! هر سؤال یا مشکلی درباره‌ی اپ داری، همین‌جا بنویس.'), findsOneWidget);
    expect(find.textContaining('الان آنلاین نیستیم'), findsOneWidget);
    expect(find.textContaining('جایگزین مشاوره یا کمک فوری نیست'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse, reason: 'technical info only with an explicit tick');
    expect(tester.takeException(), isNull);
  });

  testWidgets('messages render RTL with long text and a failed message offers retry', (tester) async {
    await boot(tester, const SupportScreen(), scale: 1.3, rows: [
      ('m1', 'user', 'سلام ' * 80),
      ('m2', 'operator', 'سلام! الان بررسی می‌کنم.'),
      ('f3', 'user', 'پیام ارسال نشده'),
    ]);
    await settle(tester);
    expect(find.text('سلام! الان بررسی می‌کنم.'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);
    expect(find.textContaining('ارسال نشد'), findsWidgets);
    expect(Directionality.of(tester.element(find.byType(SupportScreen))), TextDirection.rtl);
    expect(tester.takeException(), isNull, reason: 'no overflow at text scale 1.3 with a very long message');
  });

  testWidgets('kill switch: the chat shows an unavailable message instead of a form', (tester) async {
    await boot(tester, const SupportScreen(), enabled: false);
    await settle(tester);
    expect(find.text('الان گفتگو در دسترس نیست. بعداً دوباره سر بزن.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('safety page: only verified hotlines get a call button; support button + "not a substitute" line', (tester) async {
    await boot(tester, const SafetyScreen());
    await settle(tester);
    expect(find.text('اورژانس اجتماعی'), findsOneWidget);
    expect(find.text('اورژانس'), findsOneWidget);
    expect(find.text('مشاوره بهزیستی'), findsOneWidget);
    expect(find.byIcon(Icons.call), findsNWidgets(3));
    expect(find.text('گفتگو با پشتیبانی'), findsOneWidget);
    expect(find.textContaining('جایگزین مشاوره یا کمک فوری نیست'), findsOneWidget);
  });

  testWidgets('safety page: numbers without verified_at are never shown (kind fallback text instead)', (tester) async {
    await boot(tester, const SafetyScreen(), unverifiedHotlines: true);
    await settle(tester);
    expect(find.byIcon(Icons.call), findsNothing);
    expect(find.text('اورژانس اجتماعی'), findsNothing);
    expect(find.textContaining('همین الان با یه آدم مورد اعتمادت تماس بگیر'), findsOneWidget);
    expect(find.text('گفتگو با پشتیبانی'), findsOneWidget, reason: 'the chat entry does not depend on hotline verification');
  });

  testWidgets('safety page: the support button follows the kill switch', (tester) async {
    await boot(tester, const SafetyScreen(), enabled: false);
    await settle(tester);
    expect(find.text('گفتگو با پشتیبانی'), findsNothing);
    expect(find.byIcon(Icons.call), findsNWidgets(3), reason: 'emergency numbers stay');
  });
}
