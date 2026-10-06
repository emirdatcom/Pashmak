import '../../goals/domain/goal_title.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/entitlement/premium_gate.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../adventure/presentation/adventure_card.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../../habits/domain/habit_service.dart';
import '../../monetization/domain/monetization_service.dart';
import '../../monetization/monetization_providers.dart';
import '../../monetization/presentation/entitlement_screens.dart';
import '../../../core/content/copy_resolver.dart';
import '../../../core/widgets/widgets.dart';
import '../../exercises/presentation/exercise_picker.dart' show exerciseByKey, exerciseTreat;
import '../../goals/domain/goal_recommender.dart';
import '../../goals/presentation/goal_icons.dart';
import '../../goals/presentation/goal_screens.dart' show AreaIcon, goalAreas;
import '../../goals/presentation/goal_sheets.dart' show goalRepeatLabel, weekdaysMask;

/// Home: the cat's scene with the wallet, then the adventure / energy card, today's goals and the two actions
/// (add a goal, check in). The kind safety card and the banners appear above them when they apply.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  bool _scrolled = false; // the top bar turns solid once the page has moved

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final scrolled = _scroll.offset > 8;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    });
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
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
    final action = await svc.reconcile(activeHabits: all.where((h) => !h.isLocked).length, lockedHabits: all.where((h) => h.isLocked).length, freeLimit: ref.read(appConfigProvider).freeActiveHabits);
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

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final now = ref.watch(clockProvider).now();
    final habits = ref.watch(todayHabitsProvider).value ?? const <TodayHabit>[];
    final streak = ref.watch(streakProvider).value;
    final cardVisible = ref.watch(safetyCardVisibleProvider).value ?? false;
    final paused = ref.watch(pausedProvider).value ?? false;
    final filter = ref.watch(homeAreaFilterProvider);
    final library = {for (final g in ref.watch(goalLibraryProvider)) g.key: g};
    final shown = [
      for (final h in habits)
        if (filter == null || h.habit.areaKey == filter) h,
    ];
    final left = shown.where((h) => !h.done && !h.habit.isLocked).length;

    // One flat list, ordered by time of day (the order inside a time of day is the user's own order).
    const order = ['morning', 'afternoon', 'evening', 'bedtime', 'any'];
    final sorted = [
      for (final section in order)
        for (final h in shown)
          if (h.habit.timeOfDay == section) h,
      for (final h in shown)
        if (!order.contains(h.habit.timeOfDay)) h,
    ];
    final hasAdventure = ref.watch(currentAdventureProvider).value != null;

    return Scaffold(
      backgroundColor: DS.bgHomeGround,
      body: Stack(
        children: [
          // Everything scrolls, the forest included (one screen tall, behind the content); under it only the plain
          // ground colour remains. The bottom tabs belong to the shell and stay.
          SingleChildScrollView(
            controller: _scroll,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.sizeOf(context).height,
                  child: Image.asset('assets/art/background/home_forest.webp', fit: BoxFit.cover, alignment: Alignment.topCenter),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SceneHeader(
                      time: SceneHeader.timeFor(now.hour),
                      height: MediaQuery.sizeOf(context).height * 0.45,
                      paintScene: false,
                      child: const SizedBox(height: 170, child: FittedBox(child: CatView())),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (paused) _PausedCard(),
                          const TrialEndingBanner(),
                          const _SeasonBanner(),
                          if (cardVisible) _SafetyCard(),
                          // The top card: the adventure while one is running or finished, else today's energy toward it.
                          if (hasAdventure) const AdventureCard() else const _EnergyCard(),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const SizedBox(width: 8),
                              const GlyphArt('calendar', color: DS.onDark, size: 26),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  left > 0 ? copy.t('home.goals_left', {'n': left}) : copy.t(shown.isEmpty ? 'home.habits.title' : 'home.goals_done'),
                                  style: const TextStyle(color: DS.onDark, fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton(
                                tooltip: copy.t('home.filter'),
                                icon: Opacity(
                                  opacity: filter == null ? 1 : 0.55,
                                  child: const GlyphArt('tune', color: DS.onDark, size: 26),
                                ),
                                onPressed: () => _pickFilter(context),
                              ),
                              IconButton(
                                tooltip: copy.t('home.areas'),
                                icon: const GlyphArt('areas', color: DS.onDark, size: 26),
                                onPressed: () => context.push(Routes.areas),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (shown.isEmpty) _EmptyGoals(),
                          for (final h in sorted)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _GoalCard(key: ValueKey(h.habit.id), item: h, def: library[h.habit.goalKey ?? h.habit.templateKey]),
                            ),
                          _GlassAction(glyph: 'plus', label: copy.t('home.add_goal'), onTap: () => context.push(Routes.goalNew)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // The menu and the wallet stay on top; once the page is scrolled their bar gets a solid background.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 180),
              color: _scrolled ? DS.bgHomeBar : DS.bgHomeBar.withValues(alpha: 0),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: copy.t('nav.menu'),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const EmojiArt('ui/menu', size: 30),
                        onPressed: () => context.push(Routes.menu),
                      ),
                      const Spacer(),
                      _WalletChips(streak: streak?.current ?? 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFilter(BuildContext context) async {
    final copy = ref.read(copyProvider);
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(copy.t('home.filter.all')), onTap: () => Navigator.pop(ctx, '')),
            for (final a in goalAreas)
              ListTile(
                leading: AreaIcon(icon: null, area: a, size: 32),
                title: Text(copy.t('area.$a.name')),
                onTap: () => Navigator.pop(ctx, a),
              ),
          ],
        ),
      ),
    );
    if (v != null) ref.read(homeAreaFilterProvider.notifier).set(v.isEmpty ? null : v);
  }
}

/// Home area filter (null = all). Not persisted: it is a view helper.
class HomeAreaFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final homeAreaFilterProvider = NotifierProvider<HomeAreaFilter, String?>(HomeAreaFilter.new);

/// Coins, energy and (when there is one) the streak, as small dark pills over the scene.
class _WalletChips extends ConsumerWidget {
  const _WalletChips({required this.streak});
  final int streak;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(walletProvider).value;
    final copy = ref.watch(copyProvider);
    Widget chip(String emoji, String label, String value) => Semantics(
      label: '$label $value',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsetsDirectional.only(start: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: DS.scrim, borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmojiArt(emoji, size: 18),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        if (streak > 0) chip('ui/flame', copy.t('streak.title'), toPersianDigits(streak)),
        chip('ui/coin', copy.t('wallet.coins'), toPersianDigits(w?.coins ?? 0)),
        chip('ui/bolt', copy.t('wallet.energy'), toPersianDigits(w?.energy ?? 0)),
      ],
    );
  }
}

/// Dark translucent card over the scene (the top card and the two actions under the goals).
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.onTap, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: semanticLabel,
    child: Material(
      color: DS.glassDark,
      borderRadius: BorderRadius.circular(DS.radiusHomeCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: child),
      ),
    ),
  );
}

/// A sticker (or a plain glyph) on a rounded tile, used at the start of the glass cards.
class _Tile extends StatelessWidget {
  const _Tile({this.emoji, this.glyph, this.color = DS.glassDark});
  final String? emoji;
  final String? glyph;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(17)),
    child: emoji != null ? EmojiArt(emoji!, size: 30) : GlyphArt(glyph ?? 'plus', color: DS.onDark, size: 22),
  );
}

class _GlassAction extends StatelessWidget {
  const _GlassAction({required this.glyph, required this.label, required this.onTap});
  final String glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Glass(
    onTap: onTap,
    semanticLabel: label,
    child: Row(
      children: [
        _Tile(glyph: glyph),
        const SizedBox(width: 16),
        Expanded(
          child: ExcludeSemantics(
            child: Text(
              label,
              style: const TextStyle(color: DS.onDark, fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Today's energy toward `adventure.daily_energy_target` (docs/22 §9): just the bolt and the bar, shown until the
/// adventure starts.
class _EnergyCard extends ConsumerWidget {
  const _EnergyCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final target = ref.watch(appConfigProvider).dailyEnergyTarget;
    final energy = ref.watch(walletProvider).value?.energy ?? 0;
    final startedToday = ref.watch(adventureStartedTodayProvider).value ?? false;
    return _Glass(
      semanticLabel: copy.t('home.energy.label'),
      child: Row(
        children: [
          const _Tile(emoji: 'ui/bolt', color: DS.progressYellow),
          const SizedBox(width: 16),
          Expanded(
            child: ProgressPill(value: startedToday ? target : energy, max: target),
          ),
        ],
      ),
    );
  }
}

/// True once today's adventure has started (the bar then shows "done" and the rest as reserve).
final adventureStartedTodayProvider = FutureProvider<bool>((ref) {
  ref.watch(dbTickProvider);
  ref.watch(todayProvider);
  return ref.watch(adventureServiceProvider).startedToday();
});

class _PausedCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RoundCard(
        color: DS.doneBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.t('home.paused.title'),
              style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(copy.t('home.paused.body'), style: const TextStyle(color: DS.textPrimary)),
            const SizedBox(height: 8),
            ChunkyButton(label: copy.t('home.paused.resume'), onPressed: () => ref.read(pauseServiceProvider).set(false)),
          ],
        ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(copy.t('checkin.low_mood_card')),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.safetyScreenViewed, {'source': 'auto_card'}));
                    context.push(Routes.safety);
                  },
                  child: Text(copy.t('checkin.low_mood_card.action')),
                ),
                const Spacer(),
                TextButton(onPressed: () => ref.read(safetyServiceProvider).dismissCard(), child: Text(copy.t('common.close'))),
              ],
            ),
          ],
        ),
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
      child: Column(
        children: [
          Text(
            copy.t('home.empty_habits.title'),
            style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700),
          ),
          Text(
            copy.t('home.empty_habits.body'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: DS.onDark),
          ),
        ],
      ),
    );
  }
}

/// Completes [item] (or undoes it). A goal linked to an exercise starts that exercise instead; finishing the exercise
/// ticks the goal (HabitService.completeLinked).
Future<void> _toggleGoal(BuildContext context, WidgetRef ref, TodayHabit item, String? linked) async {
  final copy = ref.read(copyProvider);
  final service = ref.read(habitServiceProvider);
  final h = item.habit;
  if (item.done) {
    await service.undo(h.id);
    return;
  }
  if (linked != null) {
    if (ref.read(exerciseServiceProvider).isLocked(linked, isPremium: ref.read(premiumProvider))) {
      await passGate(context, ref, 'premium_exercise');
    } else {
      await context.push(Routes.exerciseRun(linked));
    }
    return;
  }
  final r = await service.complete(h.id);
  if (r.status == CompleteStatus.completed && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copy.t('goal.completed')),
        action: SnackBarAction(label: copy.t('goal.undo'), onPressed: () => service.undo(h.id)),
      ),
    );
  }
}

String _repeatLabel(CopyResolver copy, Habit h, LocalDay today) {
  final day = h.dueDay == null ? today : LocalDay.parse(h.dueDay!);
  final mode = h.repeatType == 'once' || h.repeatType == 'monthly' ? h.repeatType : (h.scheduleType == 'weekly' ? (h.weekdaysMask == weekdaysMask ? 'weekdays' : 'custom') : 'daily');
  return goalRepeatLabel(copy, mode, h.weekdaysMask, day);
}

/// The sticker of a goal on a soft rounded tile.
class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.item, required this.def});
  final TodayHabit item;
  final GoalDef? def;
  static const size = 48.0;

  @override
  Widget build(BuildContext context) {
    final h = item.habit;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: DS.chipBg, borderRadius: BorderRadius.circular(size * 0.36)),
      child: EmojiArt(
        goalEmoji(goalKey: h.goalKey ?? h.templateKey, icon: h.icon.contains('/') ? h.icon : (def?.icon ?? h.icon), area: h.areaKey ?? def?.areaKey),
        size: size * 0.7,
      ),
    );
  }
}

/// Energy of a goal with its little treat.
class _Reward extends ConsumerWidget {
  const _Reward({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        toPersianDigits(ref.watch(appConfigProvider).energyPerGoal),
        style: const TextStyle(color: DS.textSecondary, fontWeight: FontWeight.w700, fontSize: 14),
      ),
      const SizedBox(width: 2),
      EmojiArt(exerciseTreat(habit.id), size: 18),
    ],
  );
}

/// One goal: sticker tile, title, reward and the 3D tick. Tapping opens the focused view; dragging it sideways
/// reveals "more" and "edit". Done goals turn into a calm, struck-through card.
class _GoalCard extends ConsumerStatefulWidget {
  const _GoalCard({super.key, required this.item, required this.def});
  final TodayHabit item;
  final GoalDef? def;

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard> {
  static const _reveal = 168.0;
  double _dx = 0; // how far the card is pulled toward the start edge

  void _openFocus(String? linked) {
    setState(() => _dx = 0);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: ref.read(copyProvider).t('common.close'),
      barrierColor: DS.scrimDeep,
      pageBuilder: (_, _, _) => _GoalFocus(habitId: widget.item.habit.id, def: widget.def, linked: linked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final item = widget.item;
    final h = item.habit;
    final title = goalTitle(copy, h.goalKey ?? h.templateKey, h.title);
    final done = item.done;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Only when the exercise still exists in the pack; otherwise the goal is ticked by hand.
    final linked = exerciseByKey(ref.watch(contentRepositoryProvider), h.exerciseKey)?['key'] as String?;

    Widget action(Widget icon, String label, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: _reveal / 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: DS.onDark, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );

    final card = Material(
      color: done ? DS.doneBg : DS.card,
      borderRadius: BorderRadius.circular(DS.radiusHomeCard),
      elevation: 2,
      shadowColor: DS.shadow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _dx > 0 ? setState(() => _dx = 0) : _openFocus(linked),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _GoalTile(item: item, def: widget.def),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: done ? DS.doneText : DS.textPrimary, fontWeight: FontWeight.w800, fontSize: 16, decoration: done ? TextDecoration.lineThrough : null),
                    ),
                    if (h.isLocked)
                      Text(copy.t('goal.locked.hint'), style: const TextStyle(color: DS.textSecondary, fontSize: 13))
                    else if (h.targetPerDay > 1)
                      Text(
                        '${toPersianDigits(item.count)}/${toPersianDigits(h.targetPerDay)}',
                        style: const TextStyle(color: DS.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
              if (item.goalOfDay) const Padding(padding: EdgeInsetsDirectional.only(start: 6), child: EmojiArt('misc/star_badge', size: 22)),
              const SizedBox(width: 8),
              if (!h.isLocked) _Reward(habit: h),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                child: h.isLocked
                    ? const Center(child: EmojiArt('ui/lock', size: 24))
                    : ChunkyButton(
                        label: '',
                        glyph: !done && linked != null ? 'play' : 'check',
                        height: 34,
                        color: done ? DS.primaryGreen : DS.neutralButton,
                        edgeColor: done ? DS.primaryGreenEdge : DS.neutralButtonEdge,
                        textColor: done ? DS.onDark : DS.primaryGreenEdge,
                        onPressed: () => _toggleGoal(context, ref, item, linked),
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: title,
      checked: done,
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => setState(() => _dx = (_dx + (rtl ? d.delta.dx : -d.delta.dx)).clamp(0.0, _reveal)),
        onHorizontalDragEnd: (_) => setState(() => _dx = _dx > _reveal / 2 ? _reveal : 0),
        child: Stack(
          children: [
            if (_dx > 0)
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      action(const GlyphArt('dots', color: DS.onDark, size: 34), copy.t('goal.focus.more'), () => _openFocus(linked)),
                      action(const EmojiArt('ui/pencil', size: 34), copy.t('goal.editor.edit'), () {
                        setState(() => _dx = 0);
                        context.push(Routes.goalEdit(h.id));
                      }),
                    ],
                  ),
                ),
              ),
            AnimatedContainer(
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 120),
              transform: Matrix4.translationValues(rtl ? _dx : -_dx, 0, 0),
              child: card,
            ),
          ],
        ),
      ),
    );
  }
}

/// The goal alone on a dark backdrop: "goal of the day", edit and archive on top, the card, then skip / done / snooze.
class _GoalFocus extends ConsumerWidget {
  const _GoalFocus({required this.habitId, required this.def, required this.linked});
  final String habitId;
  final GoalDef? def;
  final String? linked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final today = ref.watch(todayProvider);
    final service = ref.read(habitServiceProvider);
    TodayHabit? item;
    for (final t in ref.watch(todayHabitsProvider).value ?? const <TodayHabit>[]) {
      if (t.habit.id == habitId) item = t;
    }
    if (item == null) return const SizedBox.shrink();
    final current = item;
    final h = current.habit;
    final done = current.done;
    const label = TextStyle(color: DS.onDark, fontSize: 15, fontWeight: FontWeight.w800);

    Widget round(Widget icon, String text, VoidCallback onTap) => Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: Semantics(
            button: true,
            label: text,
            child: Material(
              color: DS.glass,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: SizedBox(width: 36, height: 36, child: Center(child: icon))),
            ),
          ),
        );

    // Skip and snooze sit beside the big button; both close the view.
    Widget side(String emoji, String text, Future<void> Function() run) => Expanded(
          child: Semantics(
            button: true,
            label: text,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await run();
                if (context.mounted) Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  EmojiArt(emoji, size: 42),
                  const SizedBox(height: 8),
                  ExcludeSemantics(child: Text(text, style: label)),
                ]),
              ),
            ),
          ),
        );

    final act = !h.isLocked;
    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Semantics(
                    button: true,
                    selected: current.goalOfDay,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => service.toggleGoalOfDay(h.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Opacity(opacity: current.goalOfDay ? 1 : 0.55, child: const EmojiArt('misc/star_badge', size: 28)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(copy.t(current.goalOfDay ? 'goal.focus.star.on' : 'goal.focus.star'), style: label)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              round(const EmojiArt('ui/pencil', size: 18), copy.t('goal.editor.edit'), () {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.push(Routes.goalEdit(h.id));
              }),
              round(const GlyphArt('trash', color: DS.onDark, size: 18), copy.t('goal.editor.archive'), () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    content: Text(copy.t('goal.archive.confirm')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(copy.t('common.cancel'))),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: Text(copy.t('goal.editor.archive'))),
                    ],
                  ),
                );
                if (ok != true) return;
                await service.archive(h.id);
                if (context.mounted) Navigator.pop(context);
              }),
            ]),
            const SizedBox(height: 10),
            Material(
              color: DS.card,
              borderRadius: BorderRadius.circular(DS.radiusCard),
              child: Stack(children: [
                if (act) PositionedDirectional(top: 12, end: 16, child: _Reward(habit: h)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _GoalTile(item: current, def: def),
                      const SizedBox(height: 12),
                      Text(
                        goalTitle(copy, h.goalKey ?? h.templateKey, h.title),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: DS.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        EmojiArt(h.repeatType == 'once' ? 'ui/repeat_off' : 'ui/repeat', size: 16),
                        const SizedBox(width: 6),
                        Flexible(child: Text(_repeatLabel(copy, h, today), style: const TextStyle(color: DS.textSecondary, fontSize: 15, fontWeight: FontWeight.w600))),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            if (act)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (done) const Spacer() else side('misc/kite', copy.t('goal.focus.skip'), () => service.skipToday(h.id)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 78,
                    child: ChunkyButton(
                      label: '',
                      glyph: done ? 'undo' : (linked != null ? 'play' : 'check'),
                      height: 62,
                      color: DS.card,
                      edgeColor: DS.neutralButtonEdge,
                      textColor: DS.primaryGreen,
                      onPressed: () async {
                        await _toggleGoal(context, ref, current, linked);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(copy.t(done ? 'goal.undo' : (linked != null ? 'goal.linked.start' : 'goal.focus.complete')), style: label),
                ]),
                if (done) const Spacer() else side('misc/desk_calendar', copy.t('goal.focus.snooze'), () => service.snooze(h.id)),
              ]),
            const SizedBox(height: 22),
            Semantics(
              button: true,
              label: copy.t('common.close'),
              child: Material(
                color: DS.glass,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: () => Navigator.pop(context), child: const SizedBox(width: 32, height: 32, child: Center(child: GlyphArt('close', color: DS.onDark, size: 14)))),
              ),
            ),
          ]),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: Color(p.accent ?? 0xFF3FA796), width: 2),
      ),
      child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(copy.t('seasonal.${p.key}.home_banner'))),
    );
  }
}
