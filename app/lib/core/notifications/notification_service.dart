/// A fully resolved notification (texts already looked up) ready for the OS scheduler.
class ResolvedNotification {
  const ResolvedNotification({
    required this.id,
    required this.planId,
    required this.type,
    required this.ref,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.route,
    this.exact = false,
    this.actionLabel,
  });

  final int id; // deterministic int id (hash of type+ref+day)
  final String planId; // `type:ref:day`
  final String type;
  final String ref;
  final DateTime fireAt;
  final String title;
  final String body;
  final String route;
  final bool exact;
  final String? actionLabel; // habit_reminder: the quick "done" action
}

/// What the user tapped.
class NotificationTap {
  const NotificationTap({required this.route, required this.type, required this.ref, required this.planId});
  final String route;
  final String type;
  final String ref;
  final String planId;
}

abstract class NotificationService {
  /// Asks for POST_NOTIFICATIONS (Android 13+). Returns whether it is granted.
  Future<bool> requestPermission();
  Future<bool> hasPermission();

  /// Replaces everything that is scheduled with [items].
  Future<void> replaceAll(List<ResolvedNotification> items);
  Future<void> cancelAll();

  /// Taps on notifications (deep links).
  Stream<NotificationTap> get onTap;
}

/// Used in tests and before the real service is wired.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<void> replaceAll(List<ResolvedNotification> items) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Stream<NotificationTap> get onTap => const Stream.empty();
}

/// Records calls; used by scheduler tests.
class FakeNotificationService implements NotificationService {
  final List<List<ResolvedNotification>> calls = [];
  bool permission = true;
  List<ResolvedNotification> get scheduled => calls.isEmpty ? const [] : calls.last;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> replaceAll(List<ResolvedNotification> items) async => calls.add(List.of(items));
  @override
  Future<void> cancelAll() async => calls.add(const []);
  @override
  Stream<NotificationTap> get onTap => const Stream.empty();
}
