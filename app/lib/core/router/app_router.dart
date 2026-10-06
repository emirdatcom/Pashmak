import '../../features/monetization/presentation/entitlement_screens.dart';
import '../../features/monetization/presentation/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/adventure/presentation/adventure_screens.dart';
import '../../features/account/phone_screens.dart';
import '../../features/backup/presentation/backup_screens.dart';
import '../../features/checkin/presentation/checkin_screen.dart';
import '../../features/exercises/presentation/exercises_screens.dart';
import '../../features/bag/presentation/bag_screen.dart';
import '../../features/cat/presentation/cat_profile_screen.dart';
import '../../features/discoveries/presentation/discoveries_screen.dart';
import '../../features/goals/presentation/goal_screens.dart';
import '../../features/menu/presentation/menu_screens.dart';
import '../../features/quests/presentation/quests_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/stats/presentation/deep_stats_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/safety/presentation/safety_screen.dart';
import '../../features/shop/presentation/closet_screen.dart';
import '../../features/shop/presentation/inventory_screen.dart';
import '../../features/shop/presentation/item_screen.dart';
import '../../features/shop/presentation/shop_screens.dart';
import '../../features/settings/presentation/settings_screens.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/system/force_update_screen.dart';
import '../../features/system/placeholder_screen.dart';
import '../../features/system/splash_screen.dart';
import '../providers.dart';
import 'redirect.dart';
import 'routes.dart';

/// Notifies go_router when redirect inputs change.
class _RouterRefresh extends ChangeNotifier {
  void poke() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(onboardingCompletedProvider, (_, _) => refresh.poke());
  ref.listen(appConfigProvider, (_, _) => refresh.poke());
  ref.onDispose(refresh.dispose);

  PlaceholderScreen ph(String n) => PlaceholderScreen(n);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      location: state.uri.path,
      onboardingCompleted: ref.read(onboardingCompletedProvider),
      appVersion: ref.read(appVersionProvider),
      minSupportedVersion: ref.read(appConfigProvider).minSupportedVersion,
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding/:step', builder: (_, s) => OnboardingScreen(step: int.tryParse(s.pathParameters['step'] ?? '') ?? 1)),
      GoRoute(path: Routes.update, builder: (_, _) => const ForceUpdateScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(path: Routes.quests, builder: (_, _) => const QuestsScreen(), routes: [
            GoRoute(path: 'reflect', builder: (_, _) => const ReflectScreen()),
          ]),
          GoRoute(path: Routes.shop, builder: (_, _) => const ShopScreen(), routes: [
            GoRoute(path: 'outfit', builder: (_, _) => const ShopDetailScreen(shop: 'outfit'), routes: [
              GoRoute(path: 'item/:key', builder: (_, s) => ShopItemScreen(shop: 'outfit', itemKey: s.pathParameters['key']!, keys: (s.extra as List?)?.cast<String>())),
              GoRoute(path: 'catalog', builder: (_, _) => const ShopInventoryScreen(shop: 'outfit', sell: false)),
              GoRoute(path: 'sell', builder: (_, _) => const ShopInventoryScreen(shop: 'outfit', sell: true)),
            ]),
            GoRoute(path: 'closet', builder: (_, s) => ClosetScreen(shop: s.uri.queryParameters['shop'] ?? 'outfit')),
            GoRoute(path: 'furniture', builder: (_, _) => const ShopDetailScreen(shop: 'furniture'), routes: [
              GoRoute(path: 'item/:key', builder: (_, s) => ShopItemScreen(shop: 'furniture', itemKey: s.pathParameters['key']!, keys: (s.extra as List?)?.cast<String>())),
              GoRoute(path: 'catalog', builder: (_, _) => const ShopInventoryScreen(shop: 'furniture', sell: false)),
              GoRoute(path: 'sell', builder: (_, _) => const ShopInventoryScreen(shop: 'furniture', sell: true)),
            ]),
          ]),
          GoRoute(path: Routes.bag, builder: (_, _) => const BagScreen()),
          GoRoute(path: Routes.cat, builder: (_, _) => const CatProfileScreen(), routes: [
            GoRoute(path: 'discoveries', builder: (_, _) => const DiscoveriesScreen()),
            GoRoute(path: 'edit', builder: (_, _) => const CatEditScreen()),
          ]),
        ],
      ),
      GoRoute(path: Routes.menu, builder: (_, _) => const MenuScreen(), routes: [
        GoRoute(path: 'areas', builder: (_, _) => const AreasScreen(), routes: [
          GoRoute(path: 'retake', builder: (_, _) => const RetakeScreen()),
        ]),
        GoRoute(path: 'history', builder: (_, _) => const HistoryScreen()),
      ]),
      GoRoute(path: Routes.goals, builder: (_, _) => const GoalsScreen(), routes: [
        GoRoute(path: 'new', builder: (_, _) => const GoalEditorScreen()),
        GoRoute(path: ':id', builder: (_, s) => GoalDetailScreen(goalId: s.pathParameters['id']!), routes: [
          GoRoute(path: 'edit', builder: (_, s) => GoalEditorScreen(goalId: s.pathParameters['id'])),
        ]),
      ]),
      GoRoute(path: Routes.exercises, builder: (_, s) => ExercisesScreen(initialTab: s.uri.queryParameters['tab']), routes: [
        GoRoute(path: ':id/run', builder: (_, s) => ExerciseRunScreen(exerciseKey: s.pathParameters['id']!)),
      ]),
      GoRoute(path: Routes.checkin, builder: (_, _) => const CheckinScreen()),
      GoRoute(path: Routes.adventure, builder: (_, _) => const AdventureScreen(), routes: [
        GoRoute(path: 'result/:id', builder: (_, s) => AdventureResultScreen(adventureId: s.pathParameters['id']!)),
      ]),
      GoRoute(path: Routes.stats, builder: (_, _) => const StatsScreen(), routes: [
        GoRoute(path: 'deep', builder: (_, _) => const DeepStatsScreen()),
      ]),
      GoRoute(path: '/paywall', builder: (_, s) => PaywallScreen(trigger: s.uri.queryParameters['trigger'] ?? 'settings')),
      GoRoute(path: Routes.trialEnded, builder: (_, _) => const TrialEndedScreen()),
      GoRoute(path: Routes.lockSelect, builder: (_, _) => const LockSelectionScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen(), routes: [
        GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsScreen()),
        GoRoute(path: 'backup', builder: (_, _) => const BackupScreen()),
        GoRoute(path: 'restore', builder: (_, _) => const RestoreScreen()),
        GoRoute(path: 'phone', builder: (_, _) => const PhoneLinkScreen()),
        GoRoute(path: 'privacy', builder: (_, _) => const PrivacyScreen()),
        GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
        GoRoute(path: 'subscription', builder: (_, _) => const SubscriptionScreen()),
        GoRoute(path: 'help', builder: (_, _) => const HelpScreen()),
        GoRoute(path: ':section', builder: (_, s) => ph('settings/${s.pathParameters['section']}')),
      ]),
      GoRoute(path: Routes.safety, builder: (_, _) => const SafetyScreen()),
      GoRoute(path: Routes.supportBase, builder: (_, s) => SupportScreen(source: s.uri.queryParameters['source'] ?? 'settings')),
    ],
  );
});
