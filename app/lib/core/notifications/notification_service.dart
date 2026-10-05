/// A notification to schedule (planner output, docs/50 §2).
class PlannedNotification {
  const PlannedNotification({required this.id, required this.type, required this.fireAt, required this.titleKey, required this.bodyKey, this.vars = const {}, this.payloadRoute});
  final String id;
  final String type;
  final DateTime fireAt;
  final String titleKey;
  final String bodyKey;
  final Map<String, Object?> vars;
  final String? payloadRoute;
}

abstract class NotificationService {
  Future<bool> requestPermission();
  Future<void> scheduleAll(List<PlannedNotification> plan);
  Future<void> cancelType(String type);

  /// Routes from tapped notifications (deep links).
  Stream<String> get onTap;
}

/// Placeholder until prompt 13.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> scheduleAll(List<PlannedNotification> plan) async {}
  @override
  Future<void> cancelType(String type) async {}
  @override
  Stream<String> get onTap => const Stream.empty();
}
