import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pashmak_app/core/config/config_repository.dart';
import 'package:pashmak_app/core/content/content_repository.dart';
import 'package:pashmak_app/core/providers.dart';
import 'package:pashmak_app/core/router/routes.dart';
import 'package:pashmak_app/core/theme/app_theme.dart';
import 'package:pashmak_app/features/checkin/presentation/checkin_screen.dart';
import 'package:pashmak_app/features/core_loop_providers.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/home/presentation/home_screen.dart';

import 'helpers.dart';

void main() {
  Future<(ProviderContainer, Widget)> setup(WidgetTester tester, {required Widget home}) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = ApiHarness(DateTime(2026, 10, 5, 9));
    final content = ContentRepository(h.db, realAssets(), h.api, appVersion: '1.0.0');
    final config = ConfigRepository(h.db, realAssets(), h.api, h.clock);
    await tester.runAsync(() async {
      await content.load();
      await config.load();
    });
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(h.db),
      contentRepositoryProvider.overrideWithValue(content),
      configRepositoryProvider.overrideWithValue(config),
      clockProvider.overrideWithValue(h.clock),
      appVersionProvider.overrideWithValue('1.0.0'),
      tickProvider.overrideWith((ref) => Stream.value(h.clock.now())),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(path: '/start', builder: (_, _) => home),
      GoRoute(path: Routes.checkin, builder: (_, _) => const CheckinScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SizedBox()),
      GoRoute(path: Routes.habitNew, builder: (_, _) => const SizedBox()),
      GoRoute(path: Routes.adventure, builder: (_, _) => const SizedBox()),
      GoRoute(path: Routes.safety, builder: (_, _) => const SizedBox()),
      GoRoute(path: '/habits/:id', builder: (_, _) => const SizedBox()),
    ]);
    final app = UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        locale: const Locale('fa', 'IR'),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
      ),
    );
    return (container, app);
  }

  testWidgets('home: greeting, Jalali date, empty state, check-in CTA', (tester) async {
    final (_, app) = await setup(tester, home: const HomeScreen());
    await tester.pumpWidget(app);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('دوشنبه، ۱۳ مهر ۱۴۰۵'), findsOneWidget);
    expect(find.text('هنوز عادتی نداری'), findsOneWidget);
    expect(find.text('چک‌این امروز'), findsOneWidget);
    expect(find.text('۰/۱۰۰'), findsOneWidget, reason: 'energy shown with Persian digits');
    expect(Directionality.of(tester.element(find.byType(HomeScreen))), TextDirection.rtl);
  });

  testWidgets('ticking a habit grants energy and shows the kind snackbar with undo', (tester) async {
    final (c, app) = await setup(tester, home: const HomeScreen());
    await tester.runAsync(() => c.read(habitServiceProvider).create(const HabitDraft(templateKey: 'water')));
    await tester.pumpWidget(app);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('آب خوردن'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('۵/۱۰۰'), findsOneWidget);
    expect(find.text('برگردون'), findsOneWidget);
  });

  testWidgets('check-in: five moods, submit, kind reply; no mood in analytics queue', (tester) async {
    final (c, app) = await setup(tester, home: const CheckinScreen());
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('امروز چه حالی داری؟'), findsOneWidget);
    for (var i = 1; i <= 5; i++) {
      expect(find.text(c.read(copyProvider).t('checkin.mood.$i')), findsWidgets);
    }
    final submit = find.widgetWithText(FilledButton, 'ثبت');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull, reason: 'needs a mood first');
    await tester.tap(find.text('خوب').first);
    await tester.pump();
    await tester.tap(submit);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('چه خوب'), findsOneWidget);
    final queue = await tester.runAsync(() => c.read(databaseProvider).select(c.read(databaseProvider).analyticsQueue).get());
    expect(queue!.map((r) => r.props).join(), isNot(contains('mood')));
  });
}
