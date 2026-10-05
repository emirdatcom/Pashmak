/// Called after data changes so the Android widget can refresh (real implementation in prompt 13B).
abstract class WidgetSnapshotPublisher {
  Future<void> refresh();
}

class NoopWidgetSnapshotPublisher implements WidgetSnapshotPublisher {
  const NoopWidgetSnapshotPublisher();
  @override
  Future<void> refresh() async {}
}
