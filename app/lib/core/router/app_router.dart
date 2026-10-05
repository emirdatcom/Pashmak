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
import '../../features/habits/presentation/habits_screens.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/stats/presentation/deep_stats_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/safety/presentation/safety_screen.dart';
import '../../features/shop/presentation/shop_screens.dart';
import '../../features/settings/presentation/settings_screens.dart';
import '../../features/system/force_update_screen.dart';
import '../../features/system/placeholder_screen.dart';
import '../../features/system/splash_screen.dart';
import '../providers.dart';
import '../util/version.dart';
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
        builder: (context, state, child) => _TabShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(path: Routes.habits, builder: (_, _) => const HabitsScreen(), routes: [
            GoRoute(path: 'new', builder: (_, _) => const HabitEditorScreen()),
            GoRoute(path: ':id', builder: (_, s) => HabitDetailScreen(habitId: s.pathParameters['id']!), routes: [
              GoRoute(path: 'edit', builder: (_, s) => HabitEditorScreen(habitId: s.pathParameters['id'])),
            ]),
          ]),
          GoRoute(path: Routes.exercises, builder: (_, _) => const ExercisesScreen(), routes: [
            GoRoute(path: ':id/run', builder: (_, s) => ExerciseRunScreen(exerciseKey: s.pathParameters['id']!)),
          ]),
          GoRoute(path: Routes.shop, builder: (_, _) => const ShopScreen(), routes: [
            GoRoute(path: 'closet', builder: (_, _) => const ClosetScreen()),
          ]),
        ],
      ),
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
        GoRoute(path: ':section', builder: (_, s) => ph('settings/${s.pathParameters['section']}')),
      ]),
      GoRoute(path: Routes.safety, builder: (_, _) => const SafetyScreen()),
    ],
  );
});

class _TabShell extends ConsumerWidget {
  const _TabShell({required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = [Routes.home, Routes.habits, Routes.exercises, Routes.shop];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final config = ref.watch(appConfigProvider);
    final app = ref.watch(appVersionProvider);
    final showSoft = !ref.watch(softUpdateDismissedProvider) && config.recommendedVersion.isNotEmpty && _older(app, config.recommendedVersion);
    final index = _tabs.indexWhere(location.startsWith).clamp(0, _tabs.length - 1);
    return Scaffold(
      body: Column(children: [
        if (showSoft) const SoftUpdateBanner(),
        Expanded(child: child),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: copy.t('nav.home')),
          NavigationDestination(icon: const Icon(Icons.check_circle_outline), label: copy.t('nav.habits')),
          NavigationDestination(icon: const Icon(Icons.self_improvement), label: copy.t('nav.exercises')),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: copy.t('nav.shop')),
        ],
      ),
    );
  }

  bool _older(String a, String b) => a != b && compareVersions(a, b) < 0;
}
