import 'package:home_widget/home_widget.dart';

import '../logger.dart';
import 'widget_snapshot.dart';

/// Native widget class names (android/.../widget/*.kt).
const widgetProviders = ['CatSmallWidget', 'HabitsMediumWidget', 'QuickCheckInWidget'];
const widgetPrefsKey = 'snapshot';

/// Thin seam over the `home_widget` plugin so the publisher is testable.
abstract class WidgetBridge {
  Future<void> save(String key, String value);
  Future<void> updateAll();
}

class HomeWidgetBridge implements WidgetBridge {
  const HomeWidgetBridge(this.androidPackage);

  /// Kotlin package of the widget providers, e.g. `ir.example.pashmak_app.widget`.
  final String androidPackage;

  @override
  Future<void> save(String key, String value) async {
    await HomeWidget.saveWidgetData<String>(key, value);
  }

  @override
  Future<void> updateAll() async {
    for (final p in widgetProviders) {
      await HomeWidget.updateWidget(qualifiedAndroidName: '$androidPackage.$p');
    }
  }
}

/// Writes the snapshot and asks the widgets to redraw. Failures never reach the caller (a widget is optional).
class HomeWidgetPublisher {
  HomeWidgetPublisher(this._builder, this._bridge, {required this.enabled});
  final WidgetSnapshotBuilder _builder;
  final WidgetBridge _bridge;
  final bool Function() enabled;

  Future<void> refresh() async {
    if (!enabled()) return;
    try {
      final snap = await _builder.build();
      await _bridge.save(widgetPrefsKey, snap.encode());
      await _bridge.updateAll();
    } catch (e, s) {
      AppLogger.error(e, s, 'widget publish');
    }
  }
}
