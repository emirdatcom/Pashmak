import 'package:workmanager/workmanager.dart';

import '../logger.dart';

const supportPollTask = 'support_poll';

/// Schedules (replaces) the next background poll for support replies (decision D-9: no push service).
Future<void> scheduleSupportPoll(Duration delay) async {
  try {
    await Workmanager().registerOneOffTask(
      supportPollTask,
      supportPollTask,
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (e) {
    AppLogger.warn('could not schedule support poll: ${e.runtimeType}'); // not on Android (tests)
  }
}
