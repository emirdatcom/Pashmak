import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../goals/domain/goal_recommender.dart';
import '../../goals/presentation/goal_screens.dart' show AreaIcon, goalAreas;
import '../../onboarding/domain/onboarding_answers.dart';
import '../../onboarding/presentation/question_steps.dart';

/// Hamburger menu: cat + user card, six tiles, subscription banner.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final user = ref.watch(catProfileProvider).value?.userName ?? '';
    final premium = ref.watch(premiumProvider);
    final tiles = [
      ('menu.activities', Icons.self_improvement, Routes.exercises, false),
      ('menu.areas', Icons.category, Routes.areas, false),
      ('menu.goals', Icons.checklist, Routes.goals, false),
      ('menu.insights', Icons.insights, Routes.stats, false),
      ('menu.journal', Icons.newspaper, '', true),
      ('menu.history', Icons.history, Routes.history, false),
    ];
    return Scaffold(
      backgroundColor: DS.bgSettings,
      appBar: AppBar(
        title: Text(copy.t('menu.title')),
        backgroundColor: DS.bgSettings,
        actions: [IconButton(tooltip: copy.t('menu.settings'), icon: const Icon(Icons.settings), onPressed: () => context.push(Routes.settings))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        RoundCard(
          child: Row(children: [
            const Icon(Icons.pets, color: DS.areaMovement, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Text(user.isEmpty ? copy.t('menu.card.nouser') : copy.t('menu.card', {'item': user}), style: const TextStyle(color: DS.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
          ]),
        ),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 100 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0)),
          children: [
            for (final t in tiles)
              RoundCard(
                color: t.$4 ? DS.neutralButton : DS.card,
                onTap: t.$4 ? null : () => context.push(t.$3),
                semanticLabel: t.$4 ? '${copy.t(t.$1)} ${copy.t('menu.soon')}' : copy.t(t.$1),
                child: Row(children: [
                  Icon(t.$2, size: 32, color: t.$4 ? DS.textSecondary : DS.premiumBadge),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(copy.t(t.$1), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700)),
                      if (t.$4) Text(copy.t('menu.soon'), style: const TextStyle(color: DS.textSecondary, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
          ],
        ),
        if (!premium) ...[
          const SizedBox(height: 12),
          RoundCard(
            color: DS.premiumBadge,
            onTap: () => context.push(Routes.paywall('settings')),
            child: Row(children: [
              const Icon(Icons.workspace_premium, color: DS.lockYellow),
              const SizedBox(width: 10),
              Expanded(child: Text(copy.t('menu.subscription_banner'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700))),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// "My care areas": edit the chosen areas, or re-run the questionnaire.
class AreasScreen extends ConsumerStatefulWidget {
  const AreasScreen({super.key});
  @override
  ConsumerState<AreasScreen> createState() => _AreasState();
}

class _AreasState extends ConsumerState<AreasScreen> {
  Set<String>? _areas;
  OnboardingProfile? _profile;

  Future<void> _load() async {
    final p = await OnboardingAnswers(ref.read(databaseProvider)).load();
    if (mounted) {
      setState(() {
        _profile = p;
        _areas = p.areas.toSet();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final areas = _areas ?? const <String>{};
    return Scaffold(
      backgroundColor: DS.bgSettings,
      appBar: AppBar(title: Text(copy.t('areas.title')), backgroundColor: DS.bgSettings),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(copy.t('areas.body'), style: const TextStyle(color: DS.textPrimary)),
        const SizedBox(height: 12),
        for (final a in goalAreas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RoundCard(
              onTap: () => setState(() => areas.contains(a) ? _areas!.remove(a) : _areas!.add(a)),
              semanticLabel: copy.t('area.$a.name'),
              child: Row(children: [
                AreaIcon(icon: null, area: a, size: 40),
                const SizedBox(width: 12),
                Expanded(child: Text(copy.t('area.$a.name'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700))),
                Icon(areas.contains(a) ? Icons.check_circle : Icons.circle_outlined, color: areas.contains(a) ? DS.primaryGreen : DS.textSecondary),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        ChunkyButton(
          label: copy.t('areas.save'),
          onPressed: _profile == null
              ? null
              : () async {
                  final p = _profile!;
                  await OnboardingAnswers(ref.read(databaseProvider)).save(OnboardingProfile(
                      energyLevel: p.energyLevel, areas: [for (final a in goalAreas) if (areas.contains(a)) a], areaAnswers: p.areaAnswers, chronotype: p.chronotype, dailyTime: p.dailyTime));
                  if (context.mounted) context.pop();
                },
        ),
        const SizedBox(height: 8),
        ChunkyButton.neutral(label: copy.t('areas.retake'), onPressed: () => context.push(Routes.retake)),
      ]),
    );
  }
}

/// Completed-goal counts per day (last 30 days), Jalali dates.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final db = ref.watch(databaseProvider);
    final today = ref.watch(todayProvider);
    return Scaffold(
      backgroundColor: DS.bgSettings,
      appBar: AppBar(title: Text(copy.t('history.title')), backgroundColor: DS.bgSettings),
      body: FutureBuilder(
        future: (db.select(db.habitLogs)..where((l) => l.deletedAt.isNull() & l.localDay.isBetweenValues(today.addDays(-29).value, today.value))).get(),
        builder: (context, snap) {
          final counts = <String, int>{};
          for (final l in snap.data ?? const []) {
            counts[l.localDay] = (counts[l.localDay] ?? 0) + 1;
          }
          final days = counts.keys.toList()..sort((a, b) => b.compareTo(a));
          if (days.isEmpty) return Center(child: Text(copy.t('history.empty')));
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final d in days)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RoundCard(
                  child: Row(children: [
                    Expanded(child: Text(JalaliFormatter.weekdayDate(LocalDay.parse(d)), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700))),
                    Text(copy.t('history.goals_done', {'n': counts[d]!}), style: const TextStyle(color: DS.textSecondary)),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// Re-run the questionnaire (energy, areas, answers, chronotype, time) from "My care areas".
class RetakeScreen extends ConsumerStatefulWidget {
  const RetakeScreen({super.key});
  @override
  ConsumerState<RetakeScreen> createState() => _RetakeState();
}

class _RetakeState extends ConsumerState<RetakeScreen> {
  OnboardingProfile _profile = const OnboardingProfile();
  int _i = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    OnboardingAnswers(ref.read(databaseProvider)).load().then((p) {
      if (mounted) {
        setState(() {
          _profile = p;
          _ready = true;
        });
      }
    });
  }

  List<QuestionStep> get _steps => [for (final s in QuestionStep.values) if (s != QuestionStep.answers || _profile.areas.isNotEmpty) s];

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final steps = _steps;
    final last = _i >= steps.length - 1;
    return Scaffold(
      backgroundColor: DS.cardCat,
      appBar: AppBar(title: Text(copy.t('areas.retake.title')), backgroundColor: DS.cardCat),
      body: !_ready
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: ListView(children: [QuestionStepView(step: steps[_i.clamp(0, steps.length - 1)], profile: _profile, onChanged: (p) => setState(() => _profile = p))])),
                ChunkyButton(
                  label: copy.t(last ? 'areas.retake.finish' : 'common.next'),
                  onPressed: () async {
                    if (!last) {
                      setState(() => _i++);
                      return;
                    }
                    await OnboardingAnswers(ref.read(databaseProvider)).save(_profile);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('areas.retake.done'))));
                      context.pop();
                    }
                  },
                ),
              ]),
            ),
    );
  }
}
