import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/screen_awake.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/cat_renderer.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../habits/domain/habit_service.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../domain/exercise_runner.dart';
import 'exercise_picker.dart';

List<Map<String, dynamic>> _exercises(WidgetRef ref) =>
    ((ref.watch(contentRepositoryProvider).entries('exercises') as List?) ?? const []).cast<Map<String, dynamic>>();

/// Exercise list (docs/22 §13): purple page, leaf title, tabs, cards with reward and a "…" menu. Locks come from
/// `limits.free_exercises`; locked ones lead to the paywall (never mid-exercise).
class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key, this.initialTab});
  final String? initialTab;
  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesState();
}

class _ExercisesState extends ConsumerState<ExercisesScreen> {
  late String _tab = widget.initialTab ?? 'calm';

  Future<void> _addGoal(Map<String, dynamic> e) async {
    final copy = ref.read(copyProvider);
    final svc = ref.read(habitServiceProvider);
    final draft = HabitDraft(title: copy.t('exercise.${e['key']}.name'), areaKey: 'calm', source: 'custom');
    final gate = await svc.gateFor(draft, isPremium: ref.read(premiumProvider));
    if (gate != null) {
      if (!mounted) return;
      if (!await passGate(context, ref, gate.trigger)) return;
    }
    await svc.create(draft);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('exercise.added_goal'))));
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final premium = ref.watch(premiumProvider);
    final svc = ref.watch(exerciseServiceProvider);
    ref.watch(appConfigProvider);
    final energy = ref.watch(appConfigProvider).energyPerExercise;
    final list = [for (final e in _exercises(ref)) if ((e['tab'] ?? 'calm') == _tab) e];
    return Scaffold(
      backgroundColor: DS.bgExercises,
      appBar: AppBar(
        backgroundColor: DS.bgExercises,
        foregroundColor: DS.onDark,
        title: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.eco, color: DS.onDark), const SizedBox(width: 8), Text(copy.t('exercise.screen.title'))]),
      ),
      body: Column(children: [
        TabPills(
          onDark: true,
          tabs: [for (final t in const ['focus', 'calm', 'morning', 'night', 'energize']) PillTab(t, copy.t('exercise.tab.$t'))],
          selected: _tab,
          onSelected: (t) => setState(() => _tab = t),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            for (final e in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RoundCard(
                  semanticLabel: copy.t('exercise.${e['key']}.name'),
                  onTap: () async {
                    if (svc.isLocked(e['key'] as String, isPremium: premium)) {
                      await passGate(context, ref, 'premium_exercise');
                      return;
                    }
                    if (context.mounted) await context.push(Routes.exerciseRun(e['key'] as String));
                  },
                  child: Row(children: [
                    ExerciseBlob(e, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(copy.t('exercise.${e['key']}.name'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(copy.t('exercise.${e['key']}.desc'), style: const TextStyle(color: DS.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(copy.t('exercise.reward', {'n': (e['reward_energy'] as int?) ?? energy}), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                          const Icon(Icons.bolt, size: 16, color: DS.energy),
                        ]),
                      ]),
                    ),
                    if (svc.isLocked(e['key'] as String, isPremium: premium)) const Icon(Icons.lock_outline, color: DS.textSecondary),
                    PopupMenuButton<String>(
                      tooltip: copy.t('exercise.menu.about'),
                      icon: const Icon(Icons.more_vert, color: DS.textSecondary),
                      onSelected: (v) async {
                        if (v == 'about') {
                          await showDialog<void>(
                            context: context,
                            builder: (c) => AlertDialog(content: Text('${copy.t('exercise.${e['key']}.desc')}\n\n${copy.t(e['disclaimer_key'] as String)}'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(copy.t('common.close')))]),
                          );
                        } else {
                          await _addGoal(e);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'about', child: Text(copy.t('exercise.menu.about'))),
                        PopupMenuItem(value: 'goal', child: Text(copy.t('exercise.menu.add_goal'))),
                      ],
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Intro (disclaimer) → run (timer or journal prompts) → finish. Leaving early records nothing.
class ExerciseRunScreen extends ConsumerStatefulWidget {
  const ExerciseRunScreen({super.key, required this.exerciseKey});
  final String exerciseKey;
  @override
  ConsumerState<ExerciseRunScreen> createState() => _ExerciseRunState();
}

enum _Stage { intro, running, finished }

class _ExerciseRunState extends ConsumerState<ExerciseRunScreen> with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.intro;
  String? _sessionId;
  ExerciseRunner? _runner;
  late final Ticker _ticker;
  late final ScreenAwake _awake;
  int _energy = 0;
  int _prompt = 0;
  int _minutes = 0; // 0 = the exercise's own length; else 1 | 3 | 5
  final List<TextEditingController> _answers = [];
  RunnerSnapshot? _snap;

  Map<String, dynamic> get _ex => _exercises(ref).firstWhere((e) => e['key'] == widget.exerciseKey);
  bool get _isJournal => _ex['type'] == 'journal_prompt';

  @override
  void initState() {
    super.initState();
    _awake = ref.read(screenAwakeProvider);
    _ticker = createTicker((_) {
      final r = _runner;
      if (r == null || !mounted) return;
      final s = r.snapshot(ref.read(clockProvider).now());
      setState(() => _snap = s);
      if (s.finished) {
        _ticker.stop();
        _finish();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final c in _answers) {
      c.dispose();
    }
    _awake.set(false);
    super.dispose();
  }

  Future<void> _begin() async {
    final svc = ref.read(exerciseServiceProvider);
    _sessionId = await svc.start(widget.exerciseKey);
    await ref.read(screenAwakeProvider).set(true);
    if (_isJournal) {
      final prompts = (_ex['prompts'] as List).cast<String>();
      _answers.addAll(List.generate(prompts.length, (_) => TextEditingController()));
    } else {
      final raw = (_ex['steps'] as List).cast<Map<String, dynamic>>();
      _runner = ExerciseRunner(expandSteps(_minutes == 0 ? raw : scaleRepeats(raw, _minutes * 60)))..start(ref.read(clockProvider).now());
      _ticker.start();
    }
    if (mounted) setState(() => _stage = _Stage.running);
  }


  Future<void> _finish() async {
    if (_stage == _Stage.finished || _sessionId == null) return;
    final text = _isJournal
        ? [for (var i = 0; i < _answers.length; i++) if (_answers[i].text.trim().isNotEmpty) _answers[i].text.trim()].join('\n')
        : null;
    final duration = _isJournal ? (_ex['duration_s'] as int) : (_runner?.total ?? 0);
    final r = await ref.read(exerciseServiceProvider).complete(_sessionId!, durationS: duration, journalText: text);
    await ref.read(screenAwakeProvider).set(false);
    if (mounted) {
      setState(() {
        _energy = r.energyGranted;
        _stage = _Stage.finished;
      });
    }
  }

  Future<bool> _confirmQuit() async {
    if (_stage != _Stage.running) return true;
    final copy = ref.read(copyProvider);
    final quit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(copy.t('exercise.quit.confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(copy.t('exercise.continue'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(copy.t('exercise.quit'))),
        ],
      ),
    );
    return quit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    return PopScope(
      canPop: _stage != _Stage.running,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmQuit() && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: _isJournal ? DS.cardCat : DS.bgBreathing,
        appBar: AppBar(title: Text(copy.t('exercise.${widget.exerciseKey}.name')), backgroundColor: _isJournal ? DS.cardCat : DS.bgBreathing),
        body: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: switch (_stage) { _Stage.intro => _intro(copy), _Stage.running => _isJournal ? _journal(copy) : _timer(copy), _Stage.finished => _done(copy) }),
      ),
    );
  }

  Widget _intro(dynamic copy) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(copy.t('exercise.duration', {'n': (((_minutes == 0 ? _ex['duration_s'] as int : _minutes * 60)) / 60).ceil()}), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        if (!_isJournal) ...[
          const SizedBox(height: AppSpacing.md),
          Text(copy.t('exercise.length'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary)),
          Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
            for (final m in const [1, 3, 5]) ChoiceChip(label: Text(copy.t('exercise.length.min', {'n': m})), selected: _minutes == m, onSelected: (_) => setState(() => _minutes = _minutes == m ? 0 : m)),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(copy.t('exercise.voice')), subtitle: Text(copy.t('exercise.voice.off')), value: false, onChanged: null),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(copy.t(_ex['disclaimer_key'] as String), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary)),
        const SizedBox(height: AppSpacing.lg),
        ChunkyButton(onPressed: _begin, label: copy.t('exercise.start')),
      ]);

  Widget _timer(dynamic copy) {
    final r = _runner!;
    final s = _snap ?? r.snapshot(ref.read(clockProvider).now());
    final phase = r.phases[s.phaseIndex];
    final seconds = phase.seconds.toDouble();
    final progress = seconds == 0 ? 1.0 : (1 - s.remainingInPhase / seconds).clamp(0.0, 1.0);
    final scale = switch (phase.animation) { 'inhale' => 0.5 + 0.5 * progress, 'hold' => 1.0, 'exhale' => 1.0 - 0.5 * progress, _ => 0.75 };
    final sub = switch (phase.animation) { 'inhale' => copy.t('exercise.breath.nose'), 'exhale' => copy.t('exercise.breath.mouth'), _ => '' };
    final overall = r.total == 0 ? 0 : (s.elapsedSeconds / r.total * r.total).round();
    return Column(children: [
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          // Concentric circles like the reference: a fixed outer ring and an inner disc that breathes.
          final outer = math.min(box.maxWidth, box.maxHeight) * 0.96;
          return Center(
            child: SizedBox(
              width: outer,
              height: outer,
              child: Stack(alignment: Alignment.center, children: [
                Container(width: outer, height: outer, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: DS.card.withValues(alpha: 0.6), width: 4))),
                Container(width: outer * 0.62 * scale, height: outer * 0.62 * scale, decoration: BoxDecoration(shape: BoxShape.circle, color: DS.card.withValues(alpha: 0.35))),
                Container(width: outer * 0.5 * scale, height: outer * 0.5 * scale, decoration: BoxDecoration(shape: BoxShape.circle, color: DS.card.withValues(alpha: 0.6))),
                SizedBox(width: outer * 0.6, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Semantics(liveRegion: true, child: Text(copy.t(phase.textKey), textAlign: TextAlign.center, style: TextStyle(color: DS.textPrimary, fontSize: copy.t(phase.textKey).length > 12 ? 18 : 28, fontWeight: FontWeight.w800))),
                  if (sub.isNotEmpty) Text(sub, style: const TextStyle(color: DS.textPrimary, fontSize: 18)),
                  Text(toPersianDigits(math.max(0, s.remainingInPhase.ceil())), style: const TextStyle(color: DS.textPrimary)),
                ])),
              ]),
            ),
          );
        }),
      ),
      Transform.translate(
        offset: Offset(0, switch (phase.animation) { 'inhale' => -14 * progress, 'exhale' => -14 * (1 - progress), 'hold' => -14.0, _ => 0.0 }),
        child: SizedBox(height: 220, child: ClipRect(child: Transform.scale(scale: 1.7, alignment: Alignment.bottomCenter, child: const ExcludeSemantics(child: _BreathingFace())))),
      ),
      const SizedBox(height: AppSpacing.sm),
      ProgressPill(value: overall, max: r.total, height: 12, showText: false, label: copy.t('exercise.duration', {'n': (r.total / 60).ceil()})),
      IconButton(
        iconSize: 40,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        tooltip: copy.t(r.paused ? 'exercise.resume' : 'exercise.pause'),
        icon: Icon(r.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: DS.textPrimary),
        onPressed: () => setState(() => r.paused ? r.resume(ref.read(clockProvider).now()) : r.pause(ref.read(clockProvider).now())),
      ),
    ]);
  }

  Widget _journal(dynamic copy) {
    final prompts = (_ex['prompts'] as List).cast<String>();
    final last = _prompt == prompts.length - 1;
    return ListView(children: [
      Text(copy.t(prompts[_prompt]), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      TextField(controller: _answers[_prompt], maxLines: 6, maxLength: 1000, decoration: const InputDecoration(border: OutlineInputBorder())),
      const SizedBox(height: AppSpacing.md),
      FilledButton(onPressed: () => last ? _finish() : setState(() => _prompt++), child: Text(copy.t(last ? 'common.done' : 'common.next'))),
    ]);
  }

  Widget _done(dynamic copy) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(copy.t('exercise.finish'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (_energy > 0) Text(copy.t('exercise.energy', {'n': _energy}), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        // No paywall or upsell here, by design (docs/60 §5).
        ChunkyButton(onPressed: () => context.pop(), label: copy.t('common.done')),
      ]);
}

/// Just the calm face (eyes closed) of the cat, shown at the bottom of the breathing screen.
class _BreathingFace extends ConsumerWidget {
  const _BreathingFace();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(catProfileProvider).value;
    return ref.watch(catRendererProvider).build(context, CatVisualState(mood: CatMood.breathing, faceOnly: true, stage: ref.watch(catStageProvider), fur: profile?.fur ?? CatFur.orangeCream));
  }
}
