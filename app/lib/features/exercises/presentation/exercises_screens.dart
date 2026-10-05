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
import '../../core_loop_providers.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../domain/exercise_runner.dart';

List<Map<String, dynamic>> _exercises(WidgetRef ref) =>
    ((ref.watch(contentRepositoryProvider).entries('exercises') as List?) ?? const []).cast<Map<String, dynamic>>();

/// Exercise list. Locks come from `limits.free_exercises`; locked ones lead to the paywall (never mid-exercise).
class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final premium = ref.watch(premiumProvider);
    final svc = ref.watch(exerciseServiceProvider);
    ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('exercise.list.title'))),
      body: ListView(children: [
        for (final e in _exercises(ref))
          ListTile(
            title: Text(copy.t('exercise.${e['key']}.name')),
            subtitle: Text(copy.t('exercise.duration', {'n': ((e['duration_s'] as int) / 60).ceil()})),
            trailing: svc.isLocked(e['key'] as String, isPremium: premium) ? const Icon(Icons.lock_outline) : const Icon(Icons.chevron_left),
            onTap: () async {
              if (svc.isLocked(e['key'] as String, isPremium: premium)) {
                await passGate(context, ref, 'premium_exercise');
                return;
              }
              if (context.mounted) await context.push(Routes.exerciseRun(e['key'] as String));
            },
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
      _runner = ExerciseRunner(expandSteps((_ex['steps'] as List).cast<Map<String, dynamic>>()))..start(ref.read(clockProvider).now());
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
        appBar: AppBar(title: Text(copy.t('exercise.${widget.exerciseKey}.name'))),
        body: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: switch (_stage) { _Stage.intro => _intro(copy), _Stage.running => _isJournal ? _journal(copy) : _timer(copy), _Stage.finished => _done(copy) }),
      ),
    );
  }

  Widget _intro(dynamic copy) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(copy.t('exercise.duration', {'n': ((_ex['duration_s'] as int) / 60).ceil()}), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Text(copy.t(_ex['disclaimer_key'] as String), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: _begin, child: Text(copy.t('exercise.start'))),
      ]);

  Widget _timer(dynamic copy) {
    final r = _runner!;
    final s = _snap ?? r.snapshot(ref.read(clockProvider).now());
    final phase = r.phases[s.phaseIndex];
    final seconds = phase.seconds.toDouble();
    final progress = seconds == 0 ? 1.0 : (1 - s.remainingInPhase / seconds).clamp(0.0, 1.0);
    final scale = switch (phase.animation) { 'inhale' => 0.5 + 0.5 * progress, 'hold' => 1.0, 'exhale' => 1.0 - 0.5 * progress, _ => 0.75 };
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 220,
        height: 220,
        child: Center(
          child: Container(
            width: 220 * scale,
            height: 220 * scale,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.turquoise.withValues(alpha: 0.35), border: Border.all(color: AppColors.turquoiseDark, width: 3)),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Semantics(liveRegion: true, child: Text(copy.t(phase.textKey), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
      const SizedBox(height: AppSpacing.sm),
      Text(toPersianDigits(math.max(0, s.remainingInPhase.ceil()))),
      const SizedBox(height: AppSpacing.lg),
      OutlinedButton.icon(
        icon: Icon(r.paused ? Icons.play_arrow : Icons.pause),
        label: Text(copy.t(r.paused ? 'exercise.resume' : 'exercise.pause')),
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
        FilledButton(onPressed: () => context.pop(), child: Text(copy.t('common.done'))),
      ]);
}
