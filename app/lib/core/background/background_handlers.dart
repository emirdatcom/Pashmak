import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import '../../bootstrap.dart' show openBackgroundContainer;
import '../../features/core_loop_providers.dart';
import '../logger.dart';

const notifReplanTask = 'notif_replan';
const outboxFlushTask = 'outbox_flush';

/// Runs when the user taps the "done" action of a habit reminder while the app is closed
/// (docs/50 §4). Completes the habit with `source=notification` and replans.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  if (response.actionId != 'done' || response.payload == null) return;
  final container = await openBackgroundContainer();
  if (container == null) return;
  try {
    final habitId = RegExp(r'"ref":"([^"]+)"').firstMatch(response.payload!)?[1];
    if (habitId != null) {
      await container.read(habitServiceProvider).complete(habitId, source: 'notification');
      await container.read(notificationSchedulerProvider).replan();
    }
  } catch (e, s) {
    AppLogger.error(e, s, 'notification action');
  } finally {
    container.dispose();
  }
}

/// WorkManager entry point: `notif_replan` (daily) refills the 7-day window; `outbox_flush` is wired in prompt 14.
@pragma('vm:entry-point')
void workManagerDispatcher() {
  Workmanager().executeTask((task, input) async {
    final container = await openBackgroundContainer();
    if (container == null) return true;
    try {
      if (task == notifReplanTask) await container.read(notificationSchedulerProvider).replan();
      return true;
    } catch (e, s) {
      AppLogger.error(e, s, 'workmanager $task');
      return false;
    } finally {
      container.dispose();
    }
  });
}

/// Registers the periodic tasks. Call once at startup.
Future<void> registerBackgroundTasks() async {
  await Workmanager().initialize(workManagerDispatcher);
  await Workmanager().registerPeriodicTask(notifReplanTask, notifReplanTask, frequency: const Duration(hours: 24), flexInterval: const Duration(hours: 6));
  await Workmanager().registerPeriodicTask(outboxFlushTask, outboxFlushTask, frequency: const Duration(hours: 12));
}
