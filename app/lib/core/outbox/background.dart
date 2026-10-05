import 'package:workmanager/workmanager.dart';

const outboxTaskName = 'outbox_flush';

/// WorkManager entry point (runs in a background isolate). The real flush wiring (open the DB,
/// build the ApiClient, run OutboxWorker) is added together with the first handlers in prompts
/// 12–14; this step registers the periodic task and the dispatcher.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    return true;
  });
}

Future<void> scheduleOutboxFlush() async {
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerPeriodicTask(outboxTaskName, outboxTaskName, frequency: const Duration(hours: 12));
}
