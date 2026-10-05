import 'package:home_widget/home_widget.dart';

import '../../bootstrap.dart' show openBackgroundContainer;
import '../../features/checkin/domain/checkin_service.dart';
import '../../features/core_loop_providers.dart';
import '../../features/habits/domain/habit_service.dart';
import '../logger.dart';

/// A tap on a widget, as delivered by `HomeWidgetBackgroundIntent` (uri `scheme://habit/<id>` or
/// `scheme://checkin?mood=<1..5>`). Anything else is ignored.
sealed class WidgetAction {
  const WidgetAction();

  static WidgetAction? parse(Uri? uri) {
    if (uri == null) return null;
    if (uri.host == 'habit' && uri.pathSegments.isNotEmpty && uri.pathSegments.first.isNotEmpty) {
      return CompleteHabitAction(uri.pathSegments.first);
    }
    if (uri.host == 'checkin') {
      final mood = int.tryParse(uri.queryParameters['mood'] ?? '');
      if (mood != null && mood >= 1 && mood <= 5) return QuickCheckinAction(mood);
    }
    return null;
  }
}

class CompleteHabitAction extends WidgetAction {
  const CompleteHabitAction(this.habitId);
  final String habitId;
}

class QuickCheckinAction extends WidgetAction {
  const QuickCheckinAction(this.mood);
  final int mood;
}

/// Runs the same use cases as the app, with `source = widget`, then republishes the snapshot.
class WidgetActionHandler {
  WidgetActionHandler(this._habits, this._checkins, this._republish);
  final HabitService _habits;
  final CheckinService _checkins;
  final Future<void> Function() _republish;

  /// Returns false when nothing was done (unknown action, locked/unknown habit).
  Future<bool> handle(WidgetAction action) async {
    var done = false;
    switch (action) {
      case CompleteHabitAction(:final habitId):
        final r = await _habits.complete(habitId, source: 'widget');
        done = r.status == CompleteStatus.completed || r.status == CompleteStatus.alreadyDone;
      case QuickCheckinAction(:final mood):
        await _checkins.submit(mood, source: 'widget');
        done = true;
    }
    await _republish();
    return done;
  }
}

/// Registered with `HomeWidget.registerInteractivityCallback`. Runs in a background isolate (no UI).
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  final action = WidgetAction.parse(uri);
  if (action == null) return;
  final container = await openBackgroundContainer();
  if (container == null) return;
  try {
    await WidgetActionHandler(
      container.read(habitServiceProvider),
      container.read(checkinServiceProvider),
      () => container.read(widgetSnapshotPublisherProvider).refresh(),
    ).handle(action);
  } catch (e, s) {
    AppLogger.error(e, s, 'widget callback');
  } finally {
    container.dispose();
  }
}

Future<void> registerWidgetCallback() => HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
