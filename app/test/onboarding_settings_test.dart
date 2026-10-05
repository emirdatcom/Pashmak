import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/config/config_repository.dart';
import 'package:pashmak_app/core/content/content_repository.dart';
import 'package:pashmak_app/core/db/app_database.dart';
import 'package:pashmak_app/core/providers.dart';
import 'package:pashmak_app/core/router/routes.dart';
import 'package:pashmak_app/core/theme/app_theme.dart';
import 'package:pashmak_app/core/time/local_day.dart';
import 'package:pashmak_app/features/checkin/presentation/checkin_screen.dart';
import 'package:pashmak_app/features/core_loop_providers.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/home/presentation/home_screen.dart';
import 'package:pashmak_app/features/onboarding/domain/onboarding_service.dart';
import 'package:pashmak_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pashmak_app/features/settings/domain/data_service.dart';
import 'package:pashmak_app/features/settings/presentation/settings_screens.dart';
import 'package:pashmak_app/features/stats/domain/stats_service.dart';
import 'package:pashmak_app/features/stats/presentation/stats_screen.dart';

import 'core_loop_helpers.dart';
import 'helpers.dart';

void main() {
  final t0 = DateTime(2026, 10, 5, 9); // a Monday

  group('checkCatName', () {
    const block = ['احمق', 'bitch'];
    test('rules table', () {
      expect(checkCatName('ملوس', block), NameCheck.ok);
      expect(checkCatName('  ملوس  ', block), NameCheck.ok);
      expect(checkCatName('   ', block), NameCheck.empty);
      expect(checkCatName('a' * 17, block), NameCheck.tooLong);
      expect(checkCatName('a' * 16, block), NameCheck.ok);
      expect(checkCatName('گربه‌ی احمق', block), NameCheck.blocked);
      expect(checkCatName('BiTcH', block), NameCheck.blocked, reason: 'case-insensitive');
      expect(checkCatName('احمــق'.replaceAll('ـ', ''), block), NameCheck.blocked);
    });
  });

  group('OnboardingService', () {
    late Loop l;
    late OnboardingService svc;
    setUp(() {
      l = Loop(t0);
      svc = OnboardingService(l.db, l.habits, l.analytics, defaultCatName: 'ملوس');
    });

    test('progress survives a restart; install is tracked once', () async {
      expect(await svc.currentStep(), 1);
      await svc.setStep(3);
      expect(await OnboardingService(l.db, l.habits, l.analytics, defaultCatName: 'ملوس').currentStep(), 3);
      await svc.trackInstallOnce();
      await svc.trackInstallOnce();
      final installs = await (l.db.select(l.db.analyticsQueue)..where((e) => e.name.equals('app_installed'))).get();
      expect(installs, hasLength(1));
    });

    test('complete creates at most three template habits and marks onboarding done', () async {
      final n = await svc.complete(habits: {'water': 600, 'sleep': null, 'walk': null, 'medicine': null}, notifPermission: true, catNameChanged: false);
      expect(n, 3);
      expect((await l.habits.activeHabits()).map((h) => h.templateKey), ['water', 'sleep', 'walk']);
      expect(await l.db.meta('onboarding_completed'), 'true');
      final ev = (await (l.db.select(l.db.analyticsQueue)..where((e) => e.name.equals('onboarding_completed'))).getSingle()).props;
      expect(jsonDecode(ev), {'habits_selected_count': 3, 'notif_permission': 'granted', 'cat_name_changed': false});
    });

    test('the default name is stored as empty; a custom one is kept', () async {
      await svc.saveCatName('ملوس');
      expect(await svc.savedCatName(), '');
      await svc.saveCatName(' پشمک ');
      expect(await svc.savedCatName(), 'پشمک');
    });
  });

  group('DataService', () {
    late ApiHarness h;
    late TokenStore tokens;
    late DataService data;
    setUp(() async {
      h = ApiHarness(t0);
      tokens = h.tokens;
      await tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 1)), refresh: 'r', userId: 'u1'));
      data = DataService(h.db, h.api, tokens, h.clock);
    });

    Future<void> seed() async {
      final l = Loop(t0, database: h.db);
      final id = await l.habits.create(const HabitDraft(templateKey: 'water'));
      await l.habits.complete(id);
      await l.checkins.submit(3, note: 'یادداشت من');
    }

    test('export has habits, logs, check-ins and notes but no token or install id', () async {
      await seed();
      await h.db.setMeta('install_id', 'install-secret');
      final json = await data.exportJson();
      final m = jsonDecode(json) as Map<String, dynamic>;
      expect((m['habits'] as List), hasLength(1));
      expect((m['habit_logs'] as List), hasLength(1));
      expect((m['checkins'] as List).single['note'], 'یادداشت من');
      expect(json, isNot(contains('"a"')));
      expect(json, isNot(contains('install-secret')));
      expect(json.toLowerCase(), isNot(contains('token')));
      expect(m.keys, isNot(contains('app_meta')));
    });

    test('erase online: server delete, tokens cleared, database empty but usable', () async {
      await seed();
      h.mock.onDelete('/v1/me', (s) => s.reply(204, null));
      expect(await data.eraseAll(), EraseOutcome.serverDeleted);
      expect(await tokens.read(), isNull);
      expect(await h.db.select(h.db.habits).get(), isEmpty);
      expect(await h.db.select(h.db.checkins).get(), isEmpty);
      expect(await h.db.select(h.db.outbox).get(), isEmpty);
      expect(await h.db.select(h.db.wallet).get(), hasLength(1), reason: 'singleton rows are re-seeded');
      expect(await h.db.select(h.db.streakState).get(), hasLength(1));
    });

    test('erase offline: local data gone at once, the delete request waits in the outbox with the tokens', () async {
      await seed();
      h.mock.onDelete('/v1/me', (s) => s.throws(0, DioException.connectionError(requestOptions: RequestOptions(path: '/v1/me'), reason: 'offline')));
      expect(await data.eraseAll(), EraseOutcome.serverQueued);
      expect(await h.db.select(h.db.habits).get(), isEmpty);
      expect((await h.db.select(h.db.outbox).get()).single.kind, 'account_delete');
      expect(await tokens.read(), isNotNull);

      h.mock.reset();
      h.mock.onDelete('/v1/me', (s) => s.reply(204, null));
      expect(await data.handlers['account_delete']!({}), isNotNull);
      expect(await tokens.read(), isNull);
    });

    test('an already-deleted account (401) counts as done', () async {
      h.mock.onDelete('/v1/me', (s) => s.reply(401, {'error': {'code': 'UNAUTHENTICATED', 'message': 'x', 'request_id': 'q'}}));
      h.mock.onPost('/v1/auth/refresh', (s) => s.reply(401, {'error': {'code': 'TOKEN_INVALID', 'message': 'x', 'request_id': 'q'}}), data: Matchers.any);
      h.mock.onPost('/v1/auth/device', (s) => s.reply(500, {'error': {'code': 'X', 'message': 'x', 'request_id': 'q'}}), data: Matchers.any);
      final o = await data.eraseAll();
      expect(o, anyOf(EraseOutcome.serverDeleted, EraseOutcome.serverQueued));
      expect(await h.db.select(h.db.habits).get(), isEmpty);
    });
  });

  group('StatsService', () {
    test('Saturday-first week, active days and per-habit counts', () async {
      final l = Loop(t0); // Monday 1405-07-13; week starts Saturday 2026-10-03
      final water = await l.habits.create(const HabitDraft(templateKey: 'water'));
      final walk = await l.habits.create(const HabitDraft(templateKey: 'walk'));
      await l.habits.complete(water); // Monday
      l.clock.set(DateTime(2026, 10, 3, 12));
      await l.habits.complete(walk); // Saturday
      l.clock.set(t0);
      final w = await StatsService(l.db, l.streak).week(LocalDay.of(t0, dayStartHour: 4));
      expect(w.days.map((d) => d.day.value).first, '2026-10-03');
      expect(w.days.map((d) => d.day.value).last, '2026-10-09');
      expect(w.days.where((d) => d.active).map((d) => d.day.value), ['2026-10-03', '2026-10-05']);
      expect(w.days.where((d) => d.isToday).single.day.value, '2026-10-05');
      expect(w.days.where((d) => d.isFuture), hasLength(4));
      expect({for (final p in w.perHabit) p.habit.templateKey: p.count}, {'water': 1, 'walk': 1});
    });
  });

  group('screens', () {
    Future<(ProviderContainer, ApiHarness)> boot(WidgetTester tester, {double scale = 1.0, Widget? home, String initial = '/start', bool onboarded = false, Future<void> Function(AppDatabase)? seed}) async {
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
      if (seed != null) await tester.runAsync(() => seed(h.db));
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(h.db),
        apiClientProvider.overrideWithValue(h.api),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        contentRepositoryProvider.overrideWithValue(content),
        configRepositoryProvider.overrideWithValue(config),
        clockProvider.overrideWithValue(h.clock),
        appVersionProvider.overrideWithValue('1.0.0'),
        tickProvider.overrideWith((ref) => Stream.value(h.clock.now())),
        analyticsProvider.overrideWithValue(const NoopAnalytics()),
        if (onboarded) onboardingCompletedProvider.overrideWith(_Onboarded.new),
      ]);
      addTearDown(container.dispose);
      final router = GoRouter(initialLocation: initial, routes: [
        GoRoute(path: '/start', builder: (_, _) => home ?? const SizedBox()),
        GoRoute(path: '/onboarding/:step', builder: (_, s) => OnboardingScreen(step: int.parse(s.pathParameters['step']!))),
        GoRoute(path: Routes.home, builder: (_, _) => const Scaffold(body: Text('HOME'))),
        GoRoute(path: Routes.checkin, builder: (_, _) => const CheckinScreen()),
        GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
        GoRoute(path: Routes.stats, builder: (_, _) => const StatsScreen()),
        GoRoute(path: Routes.habitNew, builder: (_, _) => const SizedBox()),
        GoRoute(path: Routes.adventure, builder: (_, _) => const SizedBox()),
        GoRoute(path: Routes.safety, builder: (_, _) => const SizedBox()),
        GoRoute(path: '/habits/:id', builder: (_, _) => const SizedBox()),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (c, ref, _) {
          return MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            themeMode: ref.watch(themeModeProvider),
            darkTheme: AppTheme.dark,
            locale: const Locale('fa', 'IR'),
            builder: (c, w) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
              child: Directionality(textDirection: TextDirection.rtl, child: w!),
            ),
          );
        }),
      ));
      return (container, h);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('onboarding: four steps end on home with the chosen habits and cat name', (tester) async {
      final (c, h) = await boot(tester, initial: '/onboarding/1');
      await settle(tester);
      expect(find.text('سلام! من ملوسام'), findsOneWidget);
      expect(find.textContaining('جای درمان'), findsOneWidget, reason: 'non-medical disclaimer on step 1');
      await tester.tap(find.text('بعدی'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'پشمک');
      await tester.tap(find.text('بعدی'));
      await settle(tester);
      expect(c.read(catNameProvider), 'پشمک');

      await tester.tap(find.text('آب خوردن'));
      await settle(tester);
      await tester.tap(find.text('خواب').first);
      await settle(tester);
      await tester.tap(find.text('بعدی'));
      await settle(tester);

      expect(find.text('یادآوری‌های مهربون'), findsOneWidget);
      await tester.tap(find.text('بعداً'));
      await settle(tester);
      expect(find.text('هفت روز پریمیوم، رایگان'), findsOneWidget);
      await tester.tap(find.text('بعداً'));
      await settle(tester);

      expect(c.read(onboardingCompletedProvider), isTrue);
      final habits = await tester.runAsync(() => c.read(habitServiceProvider).activeHabits());
      expect(habits!.map((x) => x.templateKey).toSet(), {'water', 'sleep'});
      expect(await tester.runAsync(() => h.db.meta('onboarding_completed')), 'true');
    });

    testWidgets('onboarding: a blocked or empty name is refused kindly; at most three habits', (tester) async {
      final (_, _) = await boot(tester, initial: '/onboarding/2');
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'احمق');
      await tester.tap(find.text('بعدی'));
      await settle(tester);
      expect(find.text('این اسم مناسب نیست؛ یه اسم دیگه امتحان کن.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('بعدی'));
      await settle(tester);
      expect(find.text('یه اسم بنویس.'), findsOneWidget);
    });

    testWidgets('onboarding resumes where a killed app stopped', (tester) async {
      await boot(tester, initial: '/onboarding/1', seed: (db) => db.setMeta('onboarding_step', '3'));
      await settle(tester);
      expect(find.text('از کجا شروع کنیم؟'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('key screens have no overflow at text scale $scale (light and dark)', (tester) async {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          for (final screen in <Widget>[const HomeScreen(), const StatsScreen(), const SettingsScreen(), const CheckinScreen(), const PrivacyScreen()]) {
            final (c, _) = await boot(tester, scale: scale, home: screen);
            await tester.runAsync(() => c.read(themeModeProvider.notifier).save(mode));
            await settle(tester);
            expect(tester.takeException(), isNull, reason: '${screen.runtimeType} @ $scale $mode');
          }
        }
      });
    }

    testWidgets('onboarding steps 1-4 fit at text scale 1.3', (tester) async {
      for (final step in [1, 2, 3, 4]) {
        await boot(tester, scale: 1.3, initial: '/onboarding/$step');
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'step $step');
      }
    });

    testWidgets('your data: two-step confirm erases everything and returns to onboarding state', (tester) async {
      final (c, h) = await boot(tester, home: const PrivacyScreen(), onboarded: true);
      await tester.runAsync(() async {
        final l = Loop(t0, database: h.db);
        await l.habits.create(const HabitDraft(templateKey: 'water'));
      });
      h.mock.onDelete('/v1/me', (s) => s.reply(204, null));
      await settle(tester);
      expect(c.read(onboardingCompletedProvider), isTrue);

      await tester.tap(find.text('حذف همه‌ی داده‌ها'));
      await settle(tester);
      expect(find.text('همه‌ی داده‌ها پاک بشه؟'), findsOneWidget);
      await tester.tap(find.text('ادامه'));
      await settle(tester);
      expect(find.text('مطمئنی؟'), findsOneWidget);
      expect(c.read(onboardingCompletedProvider), isTrue, reason: 'nothing is erased after the first confirmation');
      await tester.tap(find.text('آره، پاک کن'));
      await settle(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));

      expect(c.read(onboardingCompletedProvider), isFalse);
      expect(await tester.runAsync(() => h.db.select(h.db.habits).get()), isEmpty);
    });

    testWidgets('theme and day-start are saved', (tester) async {
      final (c, h) = await boot(tester, home: const SettingsScreen());
      await settle(tester);
      await tester.runAsync(() async {
        await c.read(themeModeProvider.notifier).save(ThemeMode.dark);
        await c.read(dayStartHourProvider.notifier).save(5);
      });
      expect(await tester.runAsync(() => h.db.setting('theme_mode')), 'dark');
      expect(await tester.runAsync(() => h.db.setting('day_start_hour')), '5');
      expect(c.read(todayProvider).value, LocalDay.of(t0, dayStartHour: 5).value);
    });
  });
}

class _Onboarded extends OnboardingCompletedNotifier {
  @override
  bool build() => true;
}
