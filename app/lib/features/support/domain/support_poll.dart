/// Background polling schedule for support replies without a push service (decision D-9).
/// After the user's last message: every [firstInterval] for [firstWindow], then every [secondInterval] until
/// [stopAfter] has passed, then never again (the next user message restarts the schedule).
class SupportPollSchedule {
  const SupportPollSchedule({
    this.firstInterval = const Duration(minutes: 30),
    this.firstWindow = const Duration(hours: 24),
    this.secondInterval = const Duration(hours: 6),
    this.stopAfter = const Duration(days: 7),
  });

  final Duration firstInterval;
  final Duration firstWindow;
  final Duration secondInterval;
  final Duration stopAfter;

  /// Delay before the next poll, or null when polling should stop.
  Duration? nextDelay({required DateTime lastUserMessageAt, required DateTime now}) {
    final age = now.difference(lastUserMessageAt);
    if (age >= stopAfter) return null;
    return age < firstWindow ? firstInterval : secondInterval;
  }
}
