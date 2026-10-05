import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import '../../bootstrap.dart' show openBackgroundContainer;
import '../../features/backup/backup_providers.dart';
import '../../features/core_loop_providers.dart';
import '../../features/monetization/monetization_providers.dart';
import '../../features/support/support_providers.dart';
import 'support_poll_task.dart';
import '../providers.dart';
import '../logger.dart';

const notifReplanTask = 'notif_replan';
const outboxFlushTask = 'outbox_flush';
const backupDailyTask = 'backup_daily';

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

/// WorkManager entry point: `notif_replan` (daily) refills the 7-day window; `outbox_flush` delivers queued trial/purchase/delete calls and analytics; `backup_daily` is the automatic backup.
@pragma('vm:entry-point')
void workManagerDispatcher() {
  Workmanager().executeTask((task, input) async {
    final container = await openBackgroundContainer();
    if (container == null) return true;
    try {
      if (task == notifReplanTask) {
        await container.read(notificationSchedulerProvider).replan();
        await container.read(homeWidgetPublisherProvider).refresh(); // new day: drop yesterday's ticks
      }
      if (task == outboxFlushTask) {
        if (container.read(entitlementRepositoryProvider) != null) {
          await container.read(monetizationServiceProvider).outbox.runDue();
          await container.read(entitlementRepositoryProvider)!.refresh();
        }
        await container.read(analyticsFlusherProvider).flush();
      }
      if (task == supportPollTask) {
        final repo = container.read(supportRepositoryProvider);
        if (container.read(appConfigProvider).supportEnabled) {
          final fresh = await repo.pollForReplies();
          if (fresh) {
            // generic local notification (no message text); the planner applies quiet hours and the daily cap
            await container.read(databaseProvider).setMeta('support_reply_at', '${container.read(clockProvider).now().add(const Duration(seconds: 5)).millisecondsSinceEpoch}');
            await container.read(notificationSchedulerProvider).replan();
          }
          final last = await repo.lastUserMessageAt();
          if (last != null) {
            final next = container.read(supportPollScheduleProvider).nextDelay(lastUserMessageAt: last, now: container.read(clockProvider).now());
            if (next != null) await scheduleSupportPoll(next);
          }
        }
      }
      if (task == backupDailyTask) {
        // unmetered (Wi-Fi/ethernet) → always; metered → only a small snapshot (docs/30 §10).
        final net = await Connectivity().checkConnectivity();
        final unmetered = net.contains(ConnectivityResult.wifi) || net.contains(ConnectivityResult.ethernet);
        await container.read(backupServiceProvider).backupNow(auto: true, unmetered: unmetered);
      }
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
  await Workmanager().registerPeriodicTask(backupDailyTask, backupDailyTask,
      frequency: const Duration(hours: 24), constraints: Constraints(networkType: NetworkType.connected));
  await Workmanager().registerPeriodicTask(outboxFlushTask, outboxFlushTask, frequency: const Duration(hours: 12));
}
