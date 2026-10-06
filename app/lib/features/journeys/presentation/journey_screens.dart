import 'dart:async';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../../journal/domain/journal.dart';
import '../../sounds/domain/sound_mixer.dart';
import '../../sounds/presentation/sounds_screen.dart';
import '../domain/journey.dart';

final journeyServiceProvider = Provider<JourneyService>((ref) => JourneyService(ref.watch(databaseProvider), ref.watch(walletServiceProvider), today: () => ref.read(todayProvider)));

final journeyProgressProvider = FutureProvider.family<JourneyProgress, String>((ref, key) {
  ref.watch(dbTickProvider);
  return ref.watch(journeyServiceProvider).progress(Journey.byKey(key));
});

/// `/journeys`: the programs with their progress.
class JourneysScreen extends ConsumerWidget {
  const JourneysScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final premium = ref.watch(premiumProvider);
    return Scaffold(
      backgroundColor: DS.bgExercises,
      appBar: AppBar(title: Text(copy.t('journey.title')), backgroundColor: DS.bgExercises, foregroundColor: DS.onDark),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(copy.t('journey.intro'), style: const TextStyle(color: DS.onDark, height: 1.6)),
        const SizedBox(height: 14),
        for (final j in Journey.all) ...[
          RoundCard(
            semanticLabel: copy.t('journey.${j.key}.name'),
            onTap: () async {
              if (j.premium && !premium && !await passGate(context, ref, 'premium_exercise')) return;
              if (context.mounted) unawaited(context.push(Routes.journey(j.key)));
            },
            child: Row(children: [
              EmojiArt(j.icon, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(copy.t('journey.${j.key}.name'), style: const TextStyle(color: DS.textDeep, fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(copy.t('journey.${j.key}.desc'), style: const TextStyle(color: DS.textSecondary)),
                  const SizedBox(height: 8),
                  ProgressPill(
                    value: ref.watch(journeyProgressProvider(j.key)).value?.daysDone ?? 0,
                    max: j.days.length,
                    height: 20,
                    knob: true,
                  ),
                ]),
              ),
              if (j.premium && !premium) ...[const SizedBox(width: 8), const EmojiArt('misc/padlock', size: 24, fallback: 'ui/lock')],
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

/// `/journeys/:key`: the days as a timeline; the open day shows its tip and steps.
class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key, required this.journeyKey});
  final String journeyKey;

  Future<bool> _doneToday(WidgetRef ref, String exerciseKey) async {
    final db = ref.read(databaseProvider);
    final today = ref.read(todayProvider).value;
    final rows = await (db.select(db.exerciseSessions)..where((s) => s.exerciseKey.equals(exerciseKey) & s.localDay.equals(today) & s.completedAt.isNotNull())).get();
    return rows.isNotEmpty;
  }

  Future<void> _runStep(BuildContext context, WidgetRef ref, Journey j, int day, int i) async {
    final svc = ref.read(journeyServiceProvider);
    final (kind, value) = switch (j.days[day][i].split(':')) { [final k, final v] => (k, v), _ => ('', '') };
    switch (kind) {
      case 'ex':
        await context.push(Routes.exerciseRun(value));
        if (await _doneToday(ref, value)) await svc.completeStep(j, day, i);
      case 'journal':
        await context.push(Routes.journalWrite(value));
        if (await _doneToday(ref, JournalTemplate.all.firstWhere((t) => t.key == value).exerciseKey)) await svc.completeStep(j, day, i);
      case 'sound':
        final preset = SoundPreset.all.firstWhere((p) => p.key == value);
        unawaited(ref.read(soundMixerProvider).applyPreset(preset));
        await svc.completeStep(j, day, i);
        if (context.mounted) await context.push(Routes.sounds);
    }
    ref.invalidate(journeyProgressProvider(j.key));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final j = Journey.byKey(journeyKey);
    final p = ref.watch(journeyProgressProvider(journeyKey)).value;
    final today = ref.watch(todayProvider);
    String stepLabel(String s) => switch (s.split(':')) {
          ['ex', final k] => copy.t('exercise.$k.name'),
          ['journal', final k] => copy.t('journal.$k.name'),
          ['sound', final k] => copy.t('sounds.preset.$k'),
          _ => s,
        };
    String stepIcon(String s) => switch (s.split(':')) {
          ['journal', final k] => JournalTemplate.all.firstWhere((t) => t.key == k).icon,
          ['sound', final k] => SoundPreset.all.firstWhere((x) => x.key == k).icon,
          _ => 'calm/meditation',
        };

    return Scaffold(
      backgroundColor: DS.bgExercises,
      appBar: AppBar(title: Text(copy.t('journey.${j.key}.name')), backgroundColor: DS.bgExercises, foregroundColor: DS.onDark),
      body: p == null
          ? const SizedBox.shrink()
          : ListView(padding: const EdgeInsets.all(16), children: [
              Center(child: EmojiArt(j.icon, size: 84)),
              const SizedBox(height: 8),
              Text(copy.t('journey.${j.key}.desc'), textAlign: TextAlign.center, style: const TextStyle(color: DS.onDark, fontSize: 16)),
              const SizedBox(height: 16),
              if (!p.isStarted)
                ChunkyButton(label: copy.t('journey.start'), onPressed: () async {
                  await ref.read(journeyServiceProvider).start(j);
                  ref.invalidate(journeyProgressProvider(j.key));
                })
              else if (p.finished) ...[
                RoundCard(
                  child: Column(children: [
                    const EmojiArt('misc/medal_first', size: 64),
                    const SizedBox(height: 8),
                    Text(copy.t('journey.done'), style: const TextStyle(color: DS.textDeep, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(copy.t('journey.done.body'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textSecondary)),
                  ]),
                ),
                const SizedBox(height: 10),
                ChunkyButton.neutral(label: copy.t('journey.restart'), onPressed: () async {
                  await ref.read(journeyServiceProvider).start(j);
                  ref.invalidate(journeyProgressProvider(j.key));
                }),
              ],
              const SizedBox(height: 12),
              QuestTimeline(rows: [
                for (var d = 0; d < j.days.length; d++)
                  (
                    p.completedOn.containsKey(d),
                    _DayCard(
                      title: '${copy.t('journey.day', {'n': d + 1})} · ${copy.t('journey.${j.key}.day.${d + 1}.title')}',
                      done: p.completedOn.containsKey(d),
                      open: p.isOpen(d, today),
                      lockedNote: p.isStarted && d == p.currentDay && !p.isOpen(d, today) ? copy.t('journey.locked_tomorrow') : null,
                      tip: copy.t('journey.${j.key}.day.${d + 1}.tip'),
                      tipLabel: copy.t('journey.tip'),
                      steps: [
                        for (var i = 0; i < j.days[d].length; i++)
                          (
                            stepIcon(j.days[d][i]),
                            stepLabel(j.days[d][i]),
                            p.stepDone(d, i),
                            j.days[d][i].startsWith('sound') ? copy.t('journey.step.sound') : copy.t('journey.step.go'),
                            () => _runStep(context, ref, j, d, i),
                          ),
                      ],
                    ),
                  ),
              ]),
            ]),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.title, required this.done, required this.open, required this.tip, required this.tipLabel, required this.steps, this.lockedNote});
  final String title, tip, tipLabel;
  final bool done, open;
  final String? lockedNote;
  final List<(String, String, bool, String, VoidCallback)> steps; // icon, label, done, action, onTap

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: done ? DS.doneBg : (open ? DS.card : DS.glass), borderRadius: BorderRadius.circular(DS.radiusCard)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: TextStyle(color: done ? DS.doneText : (open ? DS.textDeep : DS.onDark), fontSize: 16, fontWeight: FontWeight.w800)),
          if (lockedNote != null) Text(lockedNote!, style: const TextStyle(color: DS.onDark, fontSize: 13)),
          if (open) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: DS.cardCat, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tipLabel, style: const TextStyle(color: DS.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(tip, style: const TextStyle(color: DS.textPrimary, height: 1.6)),
              ]),
            ),
            const SizedBox(height: 8),
            for (final s in steps)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  EmojiArt(s.$1, size: 32),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.$2, style: TextStyle(color: DS.textDeep, fontWeight: FontWeight.w700, decoration: s.$3 ? TextDecoration.lineThrough : null))),
                  if (s.$3)
                    const Icon(Icons.check_circle_rounded, color: DS.questDone)
                  else
                    SizedBox(width: 88, child: ChunkyButton(label: s.$4, height: 40, onPressed: s.$5)),
                ]),
              ),
          ],
        ]),
      );
}
