import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/entitlement/premium_gate.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../adventure/presentation/adventure_card.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../../habits/domain/habit_service.dart';
import '../../monetization/domain/monetization_service.dart';
import '../../monetization/monetization_providers.dart';
import '../../monetization/presentation/entitlement_screens.dart';
import '../../wallet/presentation/wallet_bar.dart';

/// Home: greeting, cat, wallet, streak, today's habits, check-in, adventure and the kind safety card.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onOpen();
  }

  /// New day / app open: streak evaluation, adventure promotion, last-seen clock.
  Future<void> _onOpen() async {
    final today = ref.read(todayProvider);
    await ref.read(streakServiceProvider).evaluate(today);
    await ref.read(adventureServiceProvider).current();
    await ref.read(analyticsProvider).track(AnalyticsEvent.appOpened, {'source': 'launcher'});
    await _syncEntitlements();
    final scheduler = ref.read(notificationSchedulerProvider);
    await scheduler.recordOpen();
    await scheduler.replan();
  }

  /// Delivers queued trial/purchase calls, refreshes the signed state (at most every 6h) and reacts to expiry.
  Future<void> _syncEntitlements() async {
    final repo = ref.read(entitlementRepositoryProvider);
    if (repo == null) return;
    final svc = ref.read(monetizationServiceProvider);
    await svc.outbox.runDue();
    await repo.refresh();
    final habits = ref.read(habitServiceProvider);
    final all = await habits.activeHabits();
    final action = await svc.reconcile(
      activeHabits: all.where((h) => !h.isLocked).length,
      lockedHabits: all.where((h) => h.isLocked).length,
      freeLimit: ref.read(appConfigProvider).freeActiveHabits,
    );
    if (!mounted) return;
    switch (action) {
      case ExpiryAction.unlockHabits:
        await habits.unlockAll();
      case ExpiryAction.showTrialEnded:
        unawaited(context.push(Routes.trialEnded));
      case ExpiryAction.showLockSelection:
        unawaited(context.push(Routes.lockSelect));
      case ExpiryAction.none:
        break;
    }
  }

  String _greetingKey(int hour) {
    if (hour >= 5 && hour < 12) return 'home.greeting.morning';
    if (hour >= 12 && hour < 17) return 'home.greeting.afternoon';
    if (hour >= 17 && hour < 22) return 'home.greeting.evening';
    return 'home.greeting.night';
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final now = ref.watch(clockProvider).now();
    final today = ref.watch(todayProvider);
    final habits = ref.watch(todayHabitsProvider).value ?? const <TodayHabit>[];
    final streak = ref.watch(streakProvider).value;
    final lastMood = ref.watch(lastMoodTodayProvider);
    final checkedIn = lastMood.value != null;
    final cardVisible = ref.watch(safetyCardVisibleProvider).value ?? false;
    final doneCount = habits.where((h) => h.done).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(JalaliFormatter.weekdayDate(today), style: Theme.of(context).textTheme.bodyMedium),
        actions: [IconButton(tooltip: copy.t('settings.title'), icon: const Icon(Icons.settings_outlined), onPressed: () => context.push(Routes.settings))],
      ),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Text(copy.t(_greetingKey(now.hour)), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const Center(child: CatView()),
        const SizedBox(height: AppSpacing.md),
        const WalletBar(),
        const SizedBox(height: AppSpacing.md),
        const TrialEndingBanner(),
        if (cardVisible) _SafetyCard(),
        _StreakCard(current: streak?.current ?? 0),
        const SizedBox(height: AppSpacing.md),
        if (!checkedIn)
          FilledButton.icon(icon: const Icon(Icons.favorite_border), onPressed: () => context.push(Routes.checkin), label: Text(copy.t('home.checkin_cta'))),
        const SizedBox(height: AppSpacing.md),
        const AdventureCard(),
        const SizedBox(height: AppSpacing.md),
        Text(copy.t('home.habits.title'), style: Theme.of(context).textTheme.titleMedium),
        if (habits.isNotEmpty) Text(copy.t('home.habits.progress', {'n': doneCount})),
        if (habits.isEmpty) _EmptyHabits(),
        for (final h in habits) _HabitTile(item: h),
      ]),
    );
  }
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard({required this.current});
  final int current;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_fire_department_outlined, color: AppColors.orangeDark),
        title: Text(current > 0 ? copy.t('streak.continue', {'n': current}) : copy.t('home.streak.none')),
      ),
    );
  }
}

class _SafetyCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Card(
      color: AppColors.creamDeep,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(copy.t('checkin.low_mood_card')),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            TextButton(
              onPressed: () {
                unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.safetyScreenViewed, {'source': 'auto_card'}));
                context.push(Routes.safety);
              },
              child: Text(copy.t('checkin.low_mood_card.action')),
            ),
            const Spacer(),
            TextButton(onPressed: () => ref.read(safetyServiceProvider).dismissCard(), child: Text(copy.t('common.close'))),
          ]),
        ]),
      ),
    );
  }
}

class _EmptyHabits extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(children: [
        Text(copy.t('home.empty_habits.title'), style: Theme.of(context).textTheme.titleMedium),
        Text(copy.t('home.empty_habits.body'), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: () => context.push(Routes.habitNew), child: Text(copy.t('habit.add.title'))),
      ]),
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.item});
  final TodayHabit item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final h = item.habit;
    final title = h.templateKey != null ? copy.t('habit.template.${h.templateKey}.title') : (h.title ?? '');
    final service = ref.read(habitServiceProvider);
    return Semantics(
      label: title,
      checked: item.done,
      child: CheckboxListTile(
        value: item.done,
        enabled: !h.isLocked,
        title: Text(title),
        subtitle: h.isLocked ? Text(copy.t('habit.locked.hint')) : (h.targetPerDay > 1 ? Text('${toPersianDigits(item.count)}/${toPersianDigits(h.targetPerDay)}') : null),
        onChanged: (v) async {
          if (v == true) {
            final r = await service.complete(h.id);
            if (r.status == CompleteStatus.completed && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(copy.t('habit.completed')),
                action: SnackBarAction(label: copy.t('habit.undo'), onPressed: () => service.undo(h.id)),
              ));
            }
          } else {
            await service.undo(h.id);
          }
        },
        secondary: IconButton(icon: const Icon(Icons.chevron_left), tooltip: title, onPressed: () => context.push(Routes.habit(h.id))),
      ),
    );
  }
}

/// Used by other screens: runs the gate and routes to the paywall or shows a gentle message.
Future<bool> passGate(BuildContext context, WidgetRef ref, String trigger) async {
  final decision = await ref.read(premiumGateProvider).evaluate(trigger, isPremium: ref.read(premiumProvider), context: ref.read(gateContextProvider));
  if (!context.mounted) return false;
  switch (decision) {
    case GateDecision.allow:
      return true;
    case GateDecision.showPaywall:
      await ref.read(premiumGateProvider).markShown();
      if (context.mounted) unawaited(context.push(Routes.paywall(trigger)));
      return false;
    case GateDecision.suppressed:
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(copyProvider).t('gate.suppressed'))));
      return false;
  }
}
