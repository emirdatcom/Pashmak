import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/duration_format.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../domain/quest_engine.dart';
import '../domain/quest_service.dart';

/// Quests tab: season banner, daily quests on a timeline with a countdown to the next day, and special quests with hints.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    ref.watch(tickProvider);
    final daily = ref.watch(dailyQuestsProvider).value ?? const <QuestView>[];
    final special = ref.watch(specialQuestsProvider).value ?? const <QuestView>[];
    final paused = ref.watch(pausedProvider).value ?? false;
    final now = ref.watch(clockProvider).now();
    final today = ref.watch(todayProvider);
    final startHour = ref.watch(dayStartHourProvider);
    final next = today.addDays(1);
    final untilNext = DateTime(next.year, next.month, next.day, startHour).difference(now);

    return Scaffold(
      backgroundColor: DS.bgQuests,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Text(copy.t('quest.screen.title'), style: const TextStyle(color: DS.textDeep, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback)),
          const SizedBox(height: 12),
          _SeasonBanner(today: today),
          Row(children: [
            Expanded(child: Text(copy.t('quest.daily.title'), style: const TextStyle(color: DS.textDeep, fontWeight: FontWeight.w700, fontSize: 16))),
            if (!paused) CountdownChip(label: formatRemaining(copy, untilNext), onDark: false),
          ]),
          const SizedBox(height: 4),
          if (paused)
            Padding(padding: const EdgeInsets.all(12), child: Text(copy.t('quest.paused'), style: const TextStyle(color: DS.textDeep)))
          else
            QuestTimeline(rows: [for (final q in daily) (q.state == QuestState.claimed, _QuestCard(view: q, special: false))]),
          const SizedBox(height: 16),
          Text(copy.t('quest.special.title'), style: const TextStyle(color: DS.textDeep, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          for (final q in special) Padding(padding: const EdgeInsets.only(bottom: 10), child: _QuestCard(view: q, special: true)),
        ]),
      ),
    );
  }
}

class _SeasonBanner extends ConsumerWidget {
  const _SeasonBanner({required this.today});
  final LocalDay today;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).feature('seasonal_packs')) return const SizedBox.shrink();
    final copy = ref.watch(copyProvider);
    final catalog = ref.watch(seasonalCatalogProvider);
    final active = catalog.active(today);
    if (active.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: RoundCard(child: Row(children: [
          const Icon(Icons.celebration, color: DS.energy),
          const SizedBox(width: 10),
          Expanded(child: Text('${copy.t('quest.season.active')}: ${active.first.name}', style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700))),
        ])),
      );
    }
    final upcoming = [for (final p in catalog.packs) if (p.startDate.isAfter(today.date)) p]..sort((a, b) => a.startDate.compareTo(b.startDate));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final days = upcoming.first.startDate.difference(today.date).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 190),
        decoration: BoxDecoration(color: DS.bgShopPanel, borderRadius: BorderRadius.circular(DS.radiusCard)),
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(upcoming.first.name, style: const TextStyle(color: DS.onDark, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Icon(Icons.lock, color: DS.lockYellow, size: 64)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: DS.primaryGreen, borderRadius: BorderRadius.circular(10)),
            child: Text(copy.t('quest.season.locked', {'n': days}), textAlign: TextAlign.center, style: const TextStyle(color: DS.onPrimary, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

class _QuestCard extends ConsumerWidget {
  const _QuestCard({required this.view, required this.special});
  final QuestView view;
  final bool special;

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final copy = ref.read(copyProvider);
    final r = await ref.read(questServiceProvider).claim(view.def.key, special: special);
    if (r.status == ClaimStatus.claimed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('quest.claimed_toast', {'n': r.coins}))));
    }
  }

  void _go(BuildContext context) => context.push(view.def.route);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final q = view.def;
    final done = view.state == QuestState.claimed;
    final ready = view.state == QuestState.ready;
    final title = copy.t(q.titleKey);
    final Widget trailing;
    if (done) {
      trailing = const Icon(Icons.verified, color: DS.doneText);
    } else if (ready) {
      trailing = SizedBox(width: 96, child: ChunkyButton(label: copy.t('quest.claim'), height: 44, onPressed: () => _claim(context, ref)));
    } else if (special && q.hintKey != null) {
      trailing = HintButton(label: copy.t('quest.hint'), onPressed: () => _showHint(context, ref));
    } else {
      trailing = SizedBox(width: 64, child: ChunkyButton.neutral(label: '', icon: Icons.arrow_back, height: 44, onPressed: () => _go(context)));
    }
    return Semantics(
      label: title,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: done ? DS.doneBg : DS.card, borderRadius: BorderRadius.circular(DS.radiusCard)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: done ? DS.doneText : DS.textPrimary, fontWeight: FontWeight.w700, decoration: done ? TextDecoration.lineThrough : null)),
              if (!done) ...[
                const SizedBox(height: 8),
                ProgressPill(value: view.shown, max: q.target, height: 22),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          trailing,
        ]),
      ),
    );
  }

  Future<void> _showHint(BuildContext context, WidgetRef ref) {
    final copy = ref.read(copyProvider);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(copy.t(view.def.titleKey), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            Text(copy.t(view.def.hintKey!), style: const TextStyle(color: DS.textPrimary, height: 1.6)),
            const SizedBox(height: 16),
            ChunkyButton(
              label: copy.t('quest.go'),
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(context.push(view.def.route));
              },
            ),
          ]),
        ),
      ),
    );
  }
}

/// The two-option reflective question of the daily quest. The answer stays on the device.
class ReflectScreen extends ConsumerWidget {
  const ReflectScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final prompts = ((ref.watch(contentRepositoryProvider).entries('reflection_prompts') as List?) ?? const []).cast<Map<String, dynamic>>();
    final today = ref.watch(todayProvider);
    final p = prompts.isEmpty ? null : prompts[(today.year * 400 + today.month * 31 + today.day) % prompts.length];
    return Scaffold(
      backgroundColor: DS.bgQuests,
      appBar: AppBar(title: Text(copy.t('quest.reflect.title')), backgroundColor: DS.bgQuests, foregroundColor: DS.textDeep),
      body: p == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                RoundCard(child: Text(copy.t(p['prompt_key'] as String), style: const TextStyle(color: DS.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
                const SizedBox(height: 16),
                for (final o in const ['a', 'b']) ...[
                  ChunkyButton.neutral(
                    label: copy.t(p['${o}_key'] as String),
                    onPressed: () async {
                      await ref.read(questServiceProvider).answerReflection(o);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('quest.reflect.saved'))));
                        context.pop();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                Text(copy.t('quest.reflect.private'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textDeep)),
              ]),
            ),
    );
  }
}
