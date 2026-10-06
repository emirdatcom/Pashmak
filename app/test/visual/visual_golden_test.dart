import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/config/config_repository.dart';
import 'package:pashmak_app/core/content/content_repository.dart';
import 'package:pashmak_app/core/demo/demo_seed.dart';
import 'package:pashmak_app/core/providers.dart';
import 'package:pashmak_app/core/theme/app_theme.dart';
import 'package:pashmak_app/core/widgets/chunky_button.dart';
import 'package:pashmak_app/features/bag/presentation/bag_screen.dart';
import 'package:pashmak_app/features/cat/presentation/cat_profile_screen.dart';
import 'package:pashmak_app/features/core_loop_providers.dart';
import 'package:pashmak_app/features/discoveries/presentation/discoveries_screen.dart';
import 'package:pashmak_app/features/exercises/presentation/exercises_screens.dart';
import 'package:pashmak_app/features/goals/presentation/goal_screens.dart';
import 'package:pashmak_app/features/home/presentation/home_screen.dart';
import 'package:pashmak_app/features/menu/presentation/menu_screens.dart';
import 'package:pashmak_app/features/quests/presentation/quests_screen.dart';
import 'package:pashmak_app/features/settings/presentation/settings_screens.dart';
import 'package:pashmak_app/features/shell/app_shell.dart';
import 'package:pashmak_app/features/shop/presentation/shop_screens.dart';

import '../helpers.dart';

/// Visual regression of the 15 reference-mapped screens (prompt 23 §1) at the reference size: 450×1000 dp, DPR 2
/// (= 900×2000 px). Same seeded state as the reference: 3 quests done + 1 open, one goal left, 302 coins.
/// Regenerate with `flutter test --update-goldens test/visual` and compose the side-by-side sheets with
/// `python3 tool/visual_compare/compose.py`.
class _Shot {
  const _Shot(this.n, this.name, this.location, this.screen, {this.scroll = 0, this.shell = true, this.tapStart = false});
  final String n, name, location;
  final Widget screen;
  final double scroll; // drag distance (px) to reach the lower part of the page
  final bool shell;
  final bool tapStart; // press the start button first (running state of the breathing screen)
}

Future<void> _loadFont() async {
  final l = FontLoader('Vazirmatn')
    ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Vazirmatn-Regular.ttf').readAsBytesSync())))
    ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Vazirmatn-Bold.ttf').readAsBytesSync())));
  await l.load();
  final b = FontLoader('BalooBhaijaan2')..addFont(Future.value(ByteData.sublistView(File('assets/fonts/BalooBhaijaan2-ExtraBold.ttf').readAsBytesSync())));
  await b.load();
  // flutter_tester does not ship the icon font: load it from the SDK so icons are not boxes.
  final root = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final m = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await m.load();
  }
}

void main() {
  final shots = <_Shot>[
    const _Shot('01', 'quests', '/quests', QuestsScreen()),
    const _Shot('02', 'home', '/home', HomeScreen()),
    const _Shot('03', 'shop-outfit', '/shop/outfit', ShopDetailScreen(shop: 'outfit'), shell: false),
    const _Shot('04', 'quests-special', '/quests', QuestsScreen(), scroll: -700),
    const _Shot('05', 'shop', '/shop', ShopScreen()),
    const _Shot('06', 'bag', '/bag', BagScreen()),
    const _Shot('08', 'shop-outfit-lower', '/shop/outfit', ShopDetailScreen(shop: 'outfit'), scroll: -900, shell: false),
    const _Shot('09', 'goal-new', '/goals/new', GoalEditorScreen(), shell: false),
    const _Shot('10', 'cat', '/cat', CatProfileScreen()),
    const _Shot('11', 'discoveries', '/cat/discoveries', DiscoveriesScreen(), shell: false),
    const _Shot('12', 'settings', '/settings', SettingsScreen(), shell: false),
    const _Shot('13', 'settings-lower', '/settings', SettingsScreen(), scroll: -900, shell: false),
    const _Shot('14', 'menu', '/menu', MenuScreen(), shell: false),
    const _Shot('15', 'breathing-run', '/exercises/x/run', ExerciseRunScreen(exerciseKey: 'breathing_basic'), shell: false, tapStart: true),
    const _Shot('16', 'exercises', '/exercises', ExercisesScreen(), shell: false),
    const _Shot('17', 'reflect', '/quests/reflect', ReflectScreen(), shell: false),
  ];

  setUpAll(_loadFont);

  for (final s in shots) {
    testWidgets('golden ${s.n} ${s.name}', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 2;
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
      await tester.runAsync(() async {
        await h.db.setMeta('install_id', 'golden-install'); // shop rotation and quest picks are seeded from it
        await applyDemoSeed(c);
      });
      final router = GoRouter(initialLocation: s.location, routes: [
        if (s.shell)
          ShellRoute(
            builder: (_, state, child) => AppShell(location: state.uri.path, child: child),
            routes: [GoRoute(path: s.location, builder: (_, _) => s.screen)],
          )
        else
          GoRoute(path: s.location, builder: (_, _) => s.screen),
        GoRoute(path: '/:rest(.*)', builder: (_, _) => const SizedBox()),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: AppTheme.light,
          locale: const Locale('fa', 'IR'),
          builder: (ctx, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        ),
      ));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      if (s.tapStart) {
        await tester.tap(find.byType(ChunkyButton).first);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(milliseconds: 1500));
      }
      if (s.scroll != 0 && find.byType(Scrollable).evaluate().isNotEmpty) {
        await tester.drag(find.byType(Scrollable).first, Offset(0, s.scroll / 2));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${s.n}-${s.name}.png'));
    });
  }
}
