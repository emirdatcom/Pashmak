import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pashmak_app/core/config/config_repository.dart';
import 'package:pashmak_app/core/content/content_repository.dart';
import 'package:pashmak_app/core/providers.dart';
import 'package:pashmak_app/core/router/routes.dart';
import 'package:pashmak_app/core/screen_awake.dart';
import 'package:pashmak_app/core/theme/app_theme.dart';
import 'package:pashmak_app/features/core_loop_providers.dart';
import 'package:pashmak_app/features/exercises/presentation/exercises_screens.dart';
import 'package:pashmak_app/features/shop/presentation/shop_screens.dart';
import 'package:pashmak_app/features/wallet/domain/wallet_service.dart';

import 'helpers.dart';

void main() {
  Future<(ProviderContainer, ApiHarness, Widget)> setup(WidgetTester tester, String start) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = ApiHarness(DateTime(2026, 10, 5, 9));
    final content = ContentRepository(h.db, realAssets(), h.api, appVersion: '1.0.0');
    final config = ConfigRepository(h.db, realAssets(), h.api, h.clock);
    await tester.runAsync(() async {
      await content.load();
      await config.load();
    });
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(h.db),
      contentRepositoryProvider.overrideWithValue(content),
      configRepositoryProvider.overrideWithValue(config),
      clockProvider.overrideWithValue(h.clock),
      appVersionProvider.overrideWithValue('1.0.0'),
      screenAwakeProvider.overrideWithValue(const NoopScreenAwake()),
      onboardingCompletedProvider.overrideWith(_Onboarded.new),
      tickProvider.overrideWith((ref) => Stream.value(h.clock.now())),
    ]);
    addTearDown(c.dispose);
    final router = GoRouter(initialLocation: start, routes: [
      GoRoute(path: Routes.exercises, builder: (_, _) => const ExercisesScreen(), routes: [
        GoRoute(path: ':id/run', builder: (_, s) => ExerciseRunScreen(exerciseKey: s.pathParameters['id']!)),
      ]),
      GoRoute(path: Routes.shop, builder: (_, _) => const ShopScreen(), routes: [GoRoute(path: 'outfit', builder: (_, _) => const ShopDetailScreen(shop: 'outfit'))]),
      GoRoute(path: Routes.quests, builder: (_, _) => const SizedBox()),
      GoRoute(path: '/paywall', builder: (_, s) => Text('paywall:${s.uri.queryParameters['trigger']}')),
      GoRoute(path: Routes.adventure, builder: (_, _) => const SizedBox()),
    ]);
    return (
      c,
      h,
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light, locale: const Locale('fa', 'IR'), builder: (x, w) => Directionality(textDirection: TextDirection.rtl, child: w!)),
      )
    );
  }

  testWidgets('free user: locked exercise leads to the paywall with the right trigger; free one opens', (tester) async {
    final (_, _, app) = await setup(tester, Routes.exercises);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    await tester.tap(find.text('شکرگزاری'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('paywall:premium_exercise'), findsOneWidget);
  });

  testWidgets('breathing exercise: intro shows the disclaimer, steps advance with the clock, finish grants energy', (tester) async {
    final (c, h, app) = await setup(tester, '/exercises/breathing_basic/run');
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('این تمرین جایگزین کمک تخصصی نیست.'), findsOneWidget);
    await tester.tap(find.text('شروع'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('راحت بشین. شونه‌هات رو شل کن.'), findsOneWidget);
    h.clock.advance(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('نفس بکش تو…'), findsOneWidget);
    h.clock.advance(const Duration(seconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('تموم شد'), findsWidgets);
    expect((await tester.runAsync(() => c.read(walletServiceProvider).balance()))!.energy, 10);
    expect(find.textContaining('پریمیوم'), findsNothing, reason: 'no upsell after an exercise');
  });

  testWidgets('shop: buy from the permanent collection shows "داری"; too few coins gives a kind message', (tester) async {
    final (c, _, app) = await setup(tester, Routes.shopOutfit);
    await tester.runAsync(() => c.read(walletServiceProvider).grant(Currency.coins, 50, 'promo', 'seed'));
    await tester.pumpWidget(app);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 300));
    final tile = find.text('گردنبند فیروزه‌ای'); // permanent, 60 coins
    await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(tile);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('سکه‌ات کمه؛ با ماجراجویی جمع می‌شه.'), findsOneWidget);
    await tester.runAsync(() => c.read(walletServiceProvider).grant(Currency.coins, 100, 'promo', 'more'));
    await tester.tap(tile);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('داری'), findsOneWidget);
  });
}

class _Onboarded extends OnboardingCompletedNotifier {
  @override
  bool build() => true;
}
