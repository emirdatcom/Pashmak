import '../../goals/domain/goal_title.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/entitlement/premium_gate.dart';
import '../../../core/l10n/digits.dart';
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
import '../../../core/content/copy_resolver.dart';
import '../../../core/widgets/widgets.dart';
import '../../goals/domain/goal_recommender.dart';
import '../../goals/presentation/goal_screens.dart' show AreaIcon, goalAreas;

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
    await ref.read(adventureServiceProvider).maybeAutoStart(isPremium: ref.read(premiumProvider));
    await ref.read(analyticsProvider).track(AnalyticsEvent.appOpened, {'source': 'launcher'});
    await _syncEntitlements();
    unawaited(_flushAnalytics());
    final scheduler = ref.read(notificationSchedulerProvider);
    await scheduler.recordOpen();
    await scheduler.replan();
  }

  /// Best effort: analytics must never disturb the screen (offline, no session yet, tests without an API client).
  Future<void> _flushAnalytics() async {
    try {
      await ref.read(analyticsFlusherProvider).flush();
    } catch (_) {}
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
    final habits = ref.watch(todayHabitsProvider).value ?? const <TodayHabit>[];
    final streak = ref.watch(streakProvider).value;
    final checkedIn = ref.watch(lastMoodTodayProvider).value != null;
    final cardVisible = ref.watch(safetyCardVisibleProvider).value ?? false;
    final paused = ref.watch(pausedProvider).value ?? false;
    final profile = ref.watch(catProfileProvider).value;
    final filter = ref.watch(homeAreaFilterProvider);
    final library = {for (final g in ref.watch(goalLibraryProvider)) g.key: g};
    final shown = [for (final h in habits) if (filter == null || h.habit.areaKey == filter) h];
    final left = shown.where((h) => !h.done && !h.habit.isLocked).length;

    return Scaffold(
      backgroundColor: DS.bgHomeGround,
      body: ListView(padding: EdgeInsets.zero, children: [
        SceneHeader(
          time: SceneHeader.timeFor(now.hour),
          height: MediaQuery.sizeOf(context).height * 0.45,
          overlay: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(children: [
                Row(children: [
                  IconButton(
                    tooltip: copy.t('nav.menu'),
                    style: IconButton.styleFrom(backgroundColor: DS.scrim, minimumSize: const Size(48, 48)),
                    icon: const Icon(Icons.menu, color: DS.onDark),
                    onPressed: () => context.push(Routes.menu),
                  ),
                  const Spacer(),
                  const _WalletChips(),
                ]),
                const SizedBox(height: 4),
                Align(alignment: const Alignment(0, 0), child: FractionallySizedBox(widthFactor: 0.7, child: SpeechBubble(text: _dialog(copy, profile?.trait ?? 'curious'))))
              ]),
            ),
          ),
          child: const SizedBox(height: 170, child: FittedBox(child: CatView())),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(copy.t(_greetingKey(now.hour)), style: const TextStyle(color: DS.textDeep, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (paused) _PausedCard(),
            const TrialEndingBanner(),
            const _SeasonBanner(),
            if (cardVisible) _SafetyCard(),
            const _EnergyCard(),
            const SizedBox(height: 12),
            const AdventureCard(),
            _StreakCard(current: streak?.current ?? 0),
            const SizedBox(height: 12),
            if (!checkedIn)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChunkyButton.neutral(icon: Icons.favorite_border, onPressed: () => context.push(Routes.checkin), label: copy.t('home.checkin_cta')),
              ),
            Row(children: [
              Expanded(child: Text(copy.t('home.habits.title'), style: const TextStyle(color: DS.textSecondary, fontWeight: FontWeight.w700))),
              IconButton(
                tooltip: copy.t('home.filter'),
                icon: Icon(filter == null ? Icons.filter_list : Icons.filter_list_off, color: DS.textPrimary),
                onPressed: () => _pickFilter(context),
              ),
              IconButton(tooltip: copy.t('home.areas'), icon: const Icon(Icons.category_outlined, color: DS.textPrimary), onPressed: () => context.push(Routes.areas)),
            ]),
            if (shown.isEmpty) _EmptyGoals(),
            for (final section in const ['morning', 'afternoon', 'evening', 'any'])
              ..._section(context, copy, section, shown, library, lastOne: left == 1),
            const SizedBox(height: 8),
            ChunkyButton.neutral(icon: Icons.add, label: copy.t('home.add_goal'), onPressed: () => context.push(Routes.goalNew)),
          ]),
        ),
      ]),
    );
  }

  String _dialog(CopyResolver copy, String trait) => copy.t('home.dialog.${const ['curious', 'kind', 'playful'].contains(trait) ? trait : 'curious'}');

  Future<void> _pickFilter(BuildContext context) async {
    final copy = ref.read(copyProvider);
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(copy.t('home.filter.all')), onTap: () => Navigator.pop(ctx, '')),
          for (final a in goalAreas) ListTile(leading: AreaIcon(icon: null, area: a, size: 32), title: Text(copy.t('area.$a.name')), onTap: () => Navigator.pop(ctx, a)),
        ]),
      ),
    );
    if (v != null) ref.read(homeAreaFilterProvider.notifier).set(v.isEmpty ? null : v);
  }

  List<Widget> _section(BuildContext context, CopyResolver copy, String section, List<TodayHabit> all, Map<String, GoalDef> library, {required bool lastOne}) {
    final items = [for (final h in all) if (h.habit.timeOfDay == section) h];
    if (items.isEmpty) return const [];
    final highlight = lastOne && items.any((h) => !h.done && !h.habit.isLocked);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(highlight ? copy.t('home.last_goal') : copy.t('home.section.$section'), style: const TextStyle(color: DS.textSecondary, fontWeight: FontWeight.w700)),
      ),
      for (final h in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: _GoalCard(item: h, def: library[h.habit.goalKey ?? h.habit.templateKey])),
    ];
  }
}

/// Home area filter (null = all). Not persisted: it is a view helper.
class HomeAreaFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final homeAreaFilterProvider = NotifierProvider<HomeAreaFilter, String?>(HomeAreaFilter.new);

class _WalletChips extends ConsumerWidget {
  const _WalletChips();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(walletProvider).value;
    final copy = ref.watch(copyProvider);
    Widget chip(IconData icon, Color color, String label, String value) => Semantics(
          label: '$label $value',
          child: ExcludeSemantics(
            child: Container(
              margin: const EdgeInsetsDirectional.only(start: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: DS.scrim, borderRadius: BorderRadius.circular(18)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 4),
                Text(value, style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
    return Row(children: [
      chip(Icons.monetization_on, DS.coin, copy.t('wallet.coins'), toPersianDigits(w?.coins ?? 0)),
      chip(Icons.bolt, DS.energy, copy.t('wallet.energy'), toPersianDigits(w?.energy ?? 0)),
    ]);
  }
}

/// Today's energy bar toward `adventure.daily_energy_target` (docs/22 §9).
class _EnergyCard extends ConsumerWidget {
  const _EnergyCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final target = ref.watch(appConfigProvider).dailyEnergyTarget;
    final energy = ref.watch(walletProvider).value?.energy ?? 0;
    final startedToday = ref.watch(adventureStartedTodayProvider).value ?? false;
    final full = energy >= target && !startedToday;
    return RoundCard(
      semanticLabel: copy.t('home.energy.label'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bolt, color: DS.energy),
          const SizedBox(width: 6),
          Expanded(child: Text(copy.t('home.energy.label'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        ProgressPill(value: startedToday ? target : energy, max: target),
        if (full) Padding(padding: const EdgeInsets.only(top: 6), child: Text(copy.t('home.energy.full'), style: const TextStyle(color: DS.doneText, fontWeight: FontWeight.w600))),
        if (startedToday && energy > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text(copy.t('home.energy.reserve', {'n': energy}), style: const TextStyle(color: DS.textSecondary))),
      ]),
    );
  }
}

/// True once today's adventure has started (the bar then shows "done" and the rest as reserve).
final adventureStartedTodayProvider = FutureProvider<bool>((ref) {
  ref.watch(dbTickProvider);
  ref.watch(todayProvider);
  return ref.watch(adventureServiceProvider).startedToday();
});

class _StreakCard extends ConsumerWidget {
  const _StreakCard({required this.current});
  final int current;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: RoundCard(
        child: Row(children: [
          const Icon(Icons.local_fire_department, color: DS.energy),
          const SizedBox(width: 10),
          Expanded(child: Text(current > 0 ? copy.t('streak.continue', {'n': current}) : copy.t('home.streak.none'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

class _PausedCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RoundCard(
        color: DS.doneBg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(copy.t('home.paused.title'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(copy.t('home.paused.body'), style: const TextStyle(color: DS.textPrimary)),
          const SizedBox(height: 8),
          ChunkyButton(label: copy.t('home.paused.resume'), onPressed: () => ref.read(pauseServiceProvider).set(false)),
        ]),
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

class _EmptyGoals extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(children: [
        Text(copy.t('home.empty_habits.title'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700)),
        Text(copy.t('home.empty_habits.body'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textSecondary)),
      ]),
    );
  }
}

/// One goal: area icon, title, energy, and the 3D tick button. Done goals turn into a calm, struck-through card.
class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.item, required this.def});
  final TodayHabit item;
  final GoalDef? def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final h = item.habit;
    final title = goalTitle(copy, h.goalKey ?? h.templateKey, h.title);
    final service = ref.read(habitServiceProvider);
    final energy = ref.watch(appConfigProvider).energyPerGoal;
    final done = item.done;
    return Semantics(
      label: title,
      checked: done,
      child: AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
        decoration: BoxDecoration(color: done ? DS.doneBg : DS.card, borderRadius: BorderRadius.circular(DS.radiusCard), boxShadow: const [BoxShadow(color: DS.shadow, blurRadius: 6, offset: Offset(0, 2))]),
        child: InkWell(
          borderRadius: BorderRadius.circular(DS.radiusCard),
          onTap: () => context.push(Routes.goal(h.id)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              AreaIcon(icon: def?.icon ?? h.icon, area: h.areaKey ?? def?.areaKey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: TextStyle(
                        color: done ? DS.doneText : DS.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        decoration: done ? TextDecoration.lineThrough : null,
                      )),
                  const SizedBox(height: 2),
                  if (h.isLocked)
                    Text(copy.t('goal.locked.hint'), style: const TextStyle(color: DS.textSecondary, fontSize: 13))
                  else if (h.targetPerDay > 1)
                    Text('${toPersianDigits(item.count)}/${toPersianDigits(h.targetPerDay)}', style: const TextStyle(color: DS.textSecondary, fontSize: 13))
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(toPersianDigits(energy), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 2),
                      const Icon(Icons.bolt, size: 16, color: DS.energy),
                    ]),
                ]),
              ),
              SizedBox(
                width: 64,
                child: h.isLocked
                    ? const Icon(Icons.lock_outline, color: DS.textSecondary)
                    : ChunkyButton(
                        label: '',
                        icon: done ? Icons.undo : Icons.check,
                        height: 44,
                        color: done ? DS.neutralButton : DS.primaryGreen,
                        edgeColor: done ? DS.neutralButtonEdge : DS.primaryGreenEdge,
                        textColor: done ? DS.textPrimary : DS.onPrimary,
                        onPressed: () async {
                          if (done) {
                            await service.undo(h.id);
                            return;
                          }
                          final r = await service.complete(h.id);
                          if (r.status == CompleteStatus.completed && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(copy.t('goal.completed')),
                              action: SnackBarAction(label: copy.t('goal.undo'), onPressed: () => service.undo(h.id)),
                            ));
                          }
                        },
                      ),
              ),
            ]),
          ),
        ),
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

/// Seasonal text/theme on home while a season runs (docs/40 §2). Ramadan has text and theme only.
class _SeasonBanner extends ConsumerWidget {
  const _SeasonBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).feature('seasonal_packs')) return const SizedBox.shrink();
    final active = ref.watch(seasonalCatalogProvider).active(ref.watch(todayProvider));
    if (active.isEmpty) return const SizedBox.shrink();
    final copy = ref.watch(copyProvider);
    final p = active.first;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md), side: BorderSide(color: Color(p.accent ?? 0xFF3FA796), width: 2)),
      child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(copy.t('seasonal.${p.key}.home_banner'))),
    );
  }
}
