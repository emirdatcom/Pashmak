/// One timed phase of a `timer_steps` exercise (repeat already expanded).
class ExercisePhase {
  const ExercisePhase({required this.textKey, required this.seconds, required this.animation});
  final String textKey;
  final int seconds;
  final String animation; // inhale | hold | exhale | none
}

/// Expands `steps` (with optional `repeat`) from the exercises pack. A repeated step group
/// (consecutive entries that share `repeat`) cycles together, e.g. inhale/hold/exhale × 6.
List<ExercisePhase> expandSteps(List<Map<String, dynamic>> steps) {
  final out = <ExercisePhase>[];
  var i = 0;
  while (i < steps.length) {
    final repeat = (steps[i]['repeat'] as int?) ?? 1;
    if (repeat > 1) {
      final group = <Map<String, dynamic>>[];
      while (i < steps.length && ((steps[i]['repeat'] as int?) ?? 1) == repeat) {
        group.add(steps[i]);
        i++;
      }
      for (var r = 0; r < repeat; r++) {
        for (final s in group) {
          out.add(ExercisePhase(textKey: s['text_key'] as String, seconds: s['seconds'] as int, animation: s['animation'] as String));
        }
      }
    } else {
      final s = steps[i++];
      out.add(ExercisePhase(textKey: s['text_key'] as String, seconds: s['seconds'] as int, animation: s['animation'] as String));
    }
  }
  return out;
}

/// Rescales the repeat counts of the (single) repeated group so the whole exercise lasts about [targetSeconds].
/// Exercises without a repeated group are returned unchanged. At least one cycle is kept.
List<Map<String, dynamic>> scaleRepeats(List<Map<String, dynamic>> steps, int targetSeconds) {
  final cycle = steps.where((s) => ((s['repeat'] as int?) ?? 1) > 1).fold<int>(0, (a, s) => a + (s['seconds'] as int));
  if (cycle == 0) return steps;
  final fixed = steps.where((s) => ((s['repeat'] as int?) ?? 1) <= 1).fold<int>(0, (a, s) => a + (s['seconds'] as int));
  final repeats = ((targetSeconds - fixed) / cycle).round().clamp(1, 1000);
  return [for (final s in steps) ((s['repeat'] as int?) ?? 1) > 1 ? {...s, 'repeat': repeats} : s];
}

class RunnerSnapshot {
  const RunnerSnapshot({required this.phaseIndex, required this.remainingInPhase, required this.elapsedSeconds, required this.finished});
  final int phaseIndex;
  final double remainingInPhase;
  final double elapsedSeconds;
  final bool finished;
}

/// Deterministic exercise timeline driven by explicit timestamps (no Timer), so tests can step it
/// with a FakeClock. Supports pause/resume.
class ExerciseRunner {
  ExerciseRunner(this.phases) : total = phases.fold<int>(0, (a, p) => a + p.seconds);

  final List<ExercisePhase> phases;
  final int total;
  DateTime? _startedAt;
  DateTime? _pausedAt;
  Duration _pausedTotal = Duration.zero;

  bool get started => _startedAt != null;
  bool get paused => _pausedAt != null;

  void start(DateTime now) => _startedAt ??= now;

  void pause(DateTime now) => _pausedAt ??= now;

  void resume(DateTime now) {
    final p = _pausedAt;
    if (p != null) {
      _pausedTotal += now.difference(p);
      _pausedAt = null;
    }
  }

  RunnerSnapshot snapshot(DateTime now) {
    final s = _startedAt;
    if (s == null) return RunnerSnapshot(phaseIndex: 0, remainingInPhase: phases.isEmpty ? 0 : phases.first.seconds.toDouble(), elapsedSeconds: 0, finished: false);
    final ref = _pausedAt ?? now;
    final elapsed = (ref.difference(s) - _pausedTotal).inMilliseconds / 1000.0;
    var acc = 0.0;
    for (var i = 0; i < phases.length; i++) {
      final end = acc + phases[i].seconds;
      if (elapsed < end) return RunnerSnapshot(phaseIndex: i, remainingInPhase: end - elapsed, elapsedSeconds: elapsed, finished: false);
      acc = end;
    }
    return RunnerSnapshot(phaseIndex: phases.length - 1, remainingInPhase: 0, elapsedSeconds: total.toDouble(), finished: true);
  }
}
