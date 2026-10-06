import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/config/config_repository.dart';
import 'package:pashmak_app/core/content/content_repository.dart';
import 'package:pashmak_app/core/providers.dart';
import 'package:pashmak_app/core/theme/app_theme.dart';
import 'package:pashmak_app/core/widgets/chunky_button.dart';
import 'package:pashmak_app/features/bag/presentation/bag_screen.dart';
import 'package:pashmak_app/features/cat/presentation/cat_profile_screen.dart';
import 'package:pashmak_app/features/core_loop_providers.dart';
import 'package:pashmak_app/features/discoveries/presentation/discoveries_screen.dart';
import 'package:pashmak_app/features/exercises/presentation/exercises_screens.dart';
import 'package:pashmak_app/features/goals/presentation/goal_screens.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/home/presentation/home_screen.dart';
import 'package:pashmak_app/features/menu/presentation/menu_screens.dart';
import 'package:pashmak_app/features/quests/presentation/quests_screen.dart';
import 'package:pashmak_app/features/assessments/presentation/assessment_screens.dart';
import 'package:pashmak_app/features/journal/presentation/journal_screens.dart';
import 'package:pashmak_app/features/settings/presentation/info_screens.dart';
import 'package:pashmak_app/features/settings/presentation/settings_screens.dart';
import 'package:pashmak_app/features/sounds/presentation/sounds_screen.dart';
import 'package:pashmak_app/features/shop/presentation/shop_screens.dart';

import 'helpers.dart';

/// Every redesigned screen builds without overflow at text scale 1.0 and 1.3 (docs/22 acceptance), in RTL.
void main() {
  final t0 = DateTime(2026, 10, 5, 9);

  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'quests': const QuestsScreen(),
    'reflect': const ReflectScreen(),
    'shops': const ShopScreen(),
    'shop outfit': const ShopDetailScreen(shop: 'outfit'),
    'shop furniture': const ShopDetailScreen(shop: 'furniture'),
    'bag': const BagScreen(),
    'cat': const CatProfileScreen(),
    'cat edit': const CatEditScreen(),
    'discoveries': const DiscoveriesScreen(),
    'menu': const MenuScreen(),
    'areas': const AreasScreen(),
    'retake': const RetakeScreen(),
    'history': const HistoryScreen(),
    'goals': const GoalsScreen(),
    'goal editor': const GoalEditorScreen(),
    'exercises': const ExercisesScreen(),
    'settings': const SettingsScreen(),
    'help': const HelpScreen(),
    'journal': const JournalScreen(),
    'journal write': const JournalWriteScreen(templateKey: 'reframe'),
    'sounds': const SoundsScreen(),
    'terms': const TermsScreen(),
    'rest mode': const RestModeScreen(),
    'assessments': const AssessmentsScreen(),
    'assessment phq9': const AssessmentRunScreen(assessmentKey: 'phq9'),
  };

  for (final scale in [1.0, 1.3]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} @ $scale: no overflow, RTL, has semantics', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (d) {
          debugPrint('FERR ${d.toString()}');
          prevOnError?.call(d);
        };
        addTearDown(() => FlutterError.onError = prevOnError);
        final h = ApiHarness(t0);
        final content = ContentRepository(h.db, realAssets(), h.api, appVersion: '1.0.0');
        final config = ConfigRepository(h.db, realAssets(), h.api, h.clock);
        await tester.runAsync(() async {
          await content.load();
          await config.load();
        });
        final c = ProviderContainer(overrides: [
          databaseProvider.overrideWithValue(h.db),
          apiClientProvider.overrideWithValue(h.api),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          contentRepositoryProvider.overrideWithValue(content),
          configRepositoryProvider.overrideWithValue(config),
          clockProvider.overrideWithValue(h.clock),
          appVersionProvider.overrideWithValue('1.0.0'),
          tickProvider.overrideWith((ref) => Stream.value(h.clock.now())),
          analyticsProvider.overrideWithValue(const NoopAnalytics()),
        ]);
        addTearDown(c.dispose);
        // data so lists are not empty
        await tester.runAsync(() async {
          await c.read(habitServiceProvider).create(const HabitDraft(templateKey: 'calm_five_breaths', areaKey: 'calm', timeOfDay: 'morning'));
          await c.read(habitServiceProvider).create(const HabitDraft(templateKey: 'home_bed_make', areaKey: 'home', timeOfDay: 'evening'));
        });
        final router = GoRouter(initialLocation: '/x', routes: [GoRoute(path: '/x', builder: (_, _) => e.value), GoRoute(path: '/:rest(.*)', builder: (_, _) => const SizedBox())]);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            locale: const Locale('fa', 'IR'),
            builder: (ctx, w) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)), child: Directionality(textDirection: TextDirection.rtl, child: w!)),
          ),
        ));
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
          await tester.pump(const Duration(milliseconds: 300));
        }
        final ex = tester.takeException();
        if (ex is FlutterError) debugPrint(ex.toStringDeep());
        expect(ex, isNull);
        final sem = tester.ensureSemantics();
        expect(find.byType(Semantics), findsWidgets);
        sem.dispose();
      });
    }
  }

  Future<ProviderContainer> bootInteractive(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final h = ApiHarness(t0);
    final content = ContentRepository(h.db, realAssets(), h.api, appVersion: '1.0.0');
    final config = ConfigRepository(h.db, realAssets(), h.api, h.clock);
    await tester.runAsync(() async {
      await content.load();
      await config.load();
    });
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(h.db),
      apiClientProvider.overrideWithValue(h.api),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      contentRepositoryProvider.overrideWithValue(content),
      configRepositoryProvider.overrideWithValue(config),
      clockProvider.overrideWithValue(h.clock),
      appVersionProvider.overrideWithValue('1.0.0'),
      tickProvider.overrideWith((ref) => Stream.value(h.clock.now())),
      analyticsProvider.overrideWithValue(const NoopAnalytics()),
    ]);
    addTearDown(c.dispose);
    final router = GoRouter(initialLocation: '/x', routes: [GoRoute(path: '/x', builder: (_, _) => screen), GoRoute(path: '/:rest(.*)', builder: (_, _) => const SizedBox())]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light, locale: const Locale('fa', 'IR'), builder: (ctx, w) => Directionality(textDirection: TextDirection.rtl, child: w!)),
    ));
    return c;
  }

  Future<void> settle(WidgetTester tester, [int n = 3]) async {
    for (var i = 0; i < n; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('quests: the claim quest is ready, tapping "دریافت" pays coins once', (tester) async {
    final c = await bootInteractive(tester, const QuestsScreen());
    await settle(tester);
    expect(find.text('دریافت پاداش امروز'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChunkyButton, 'دریافت').first);
    await settle(tester);
    final coins = (await tester.runAsync(() => c.read(walletServiceProvider).balance()))!.coins;
    expect(coins, c.read(appConfigProvider).questsDailyRewardCoins);
    expect(find.text('دریافت'), findsNothing, reason: 'claimed quests show a done state, not the button again');
  });

  testWidgets('reflect: submit stays disabled until an answer is picked, then the daily question counts as done', (tester) async {
    final c = await bootInteractive(tester, const ReflectScreen());
    await settle(tester);
    expect(find.widgetWithText(ChunkyButton, 'ثبت جواب'), findsNothing, reason: 'no answer picked yet');
    final prompt = c.read(todayReflectionProvider)!;
    await tester.tap(find.text(c.read(copyProvider).t(prompt['c_key'] as String)));
    await settle(tester, 1);
    await tester.tap(find.widgetWithText(ChunkyButton, 'ثبت جواب'));
    await settle(tester);
    final m = (await tester.runAsync(() => c.read(questServiceProvider).metrics()))!;
    expect(m['reflection_today'], 1);
  });

  testWidgets('goal editor: pick a suggestion, save → a goal with its area and time of day', (tester) async {
    final c = await bootInteractive(tester, const GoalEditorScreen());
    await settle(tester);
    // the page list, not the horizontal tab strip
    final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await tester.tap(find.text('بُردهای آسون'));
    await settle(tester, 1);
    await tester.scrollUntilVisible(find.text('یه لیوان آب بخور'), 200, scrollable: vertical);
    await tester.tap(find.text('یه لیوان آب بخور'));
    await settle(tester, 1);
    await tester.scrollUntilVisible(find.text('ذخیره'), -200, scrollable: vertical);
    await tester.tap(find.text('ذخیره'));
    await settle(tester);
    final goals = (await tester.runAsync(() => c.read(habitServiceProvider).activeHabits()))!;
    expect(goals.single.goalKey, 'food_water_glass');
    expect(goals.single.areaKey, 'nutrition');
    expect(goals.single.timeOfDay, 'morning');
  });

  testWidgets('shop: refresh button shows the price from config and refuses kindly without coins', (tester) async {
    await bootInteractive(tester, const ShopDetailScreen(shop: 'furniture'));
    await settle(tester);
    // the refresh pill carries the config price and is labelled with it for screen readers
    final btn = find.byKey(const ValueKey('shop-refresh'));
    expect(find.descendant(of: btn, matching: find.text('۳۰')), findsOneWidget, reason: 'price from config');
    await tester.tap(btn);
    await settle(tester, 1);
    expect(find.text('سکه‌ات کمه؛ با ماجراجویی جمع می‌شه.'), findsOneWidget);
  });
}
