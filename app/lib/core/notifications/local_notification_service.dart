import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../logger.dart';
import 'notification_service.dart';

/// Channel names/descriptions come from copy (docs/50 §4); this holds the ids.
class NotificationChannels {
  const NotificationChannels({required this.names, required this.descriptions});
  final Map<String, String> names;
  final Map<String, String> descriptions;
  static const ids = ['daily', 'reminders', 'cat', 'account', 'support'];

  /// Which Android channel a notification type uses.
  static String forType(String type) => switch (type) {
        'habit_reminder' => 'reminders',
        'cat_returned' => 'cat',
        'trial' => 'account',
        'support_reply' => 'support',
        _ => 'daily',
      };
}

/// Called from the OS when the user taps the "done" action while the app is closed. Must be a
/// top-level function (see background_context.dart for the isolate wiring).
typedef BackgroundActionHandler = void Function(NotificationResponse response);

/// Local notifications through flutter_local_notifications. Inexact (Doze-friendly) scheduling by
/// default; exact alarms only for habit reminders when the user opted in. No FCM, no
/// USE_EXACT_ALARM, no battery-optimization exemption request (docs/50 §4).
///
/// Not verifiable without an Android device: see app/README.md.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({required this.channels, this.onBackgroundAction});

  final NotificationChannels channels;
  final BackgroundActionHandler? onBackgroundAction;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<NotificationTap> _taps = StreamController<NotificationTap>.broadcast();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );
    _ready = true;
  }

  void _onResponse(NotificationResponse r) {
    final payload = r.payload;
    if (payload == null) return;
    try {
      final m = jsonDecode(payload) as Map<String, dynamic>;
      _taps.add(NotificationTap(route: m['route'] as String, type: m['type'] as String, ref: (m['ref'] as String?) ?? '', planId: m['plan'] as String));
    } catch (e) {
      AppLogger.warn('bad notification payload: $e');
    }
  }

  /// If the app was launched by tapping a notification, returns that tap.
  Future<NotificationTap?> launchTap() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    final r = d?.notificationResponse;
    if (d == null || !d.didNotificationLaunchApp || r?.payload == null) return null;
    try {
      final m = jsonDecode(r!.payload!) as Map<String, dynamic>;
      return NotificationTap(route: m['route'] as String, type: m['type'] as String, ref: (m['ref'] as String?) ?? '', planId: m['plan'] as String);
    } catch (_) {
      return null;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    await init();
    return (await _android?.requestNotificationsPermission()) ?? false;
  }

  @override
  Future<bool> hasPermission() async {
    await init();
    return (await _android?.areNotificationsEnabled()) ?? false;
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  @override
  Future<void> replaceAll(List<ResolvedNotification> items) async {
    await init();
    await _plugin.cancelAll();
    final canExact = (await _android?.canScheduleExactNotifications()) ?? false;
    for (final n in items) {
      final channel = NotificationChannels.forType(n.type);
      final details = AndroidNotificationDetails(
        channel,
        channels.names[channel] ?? channel,
        channelDescription: channels.descriptions[channel],
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        actions: n.actionLabel == null ? null : [AndroidNotificationAction('done', n.actionLabel!)],
      );
      try {
        await _plugin.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          scheduledDate: tz.TZDateTime.from(n.fireAt, tz.local),
          notificationDetails: NotificationDetails(android: details),
          androidScheduleMode: (n.exact && canExact) ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({'route': n.route, 'type': n.type, 'ref': n.ref, 'plan': n.planId}),
        );
      } catch (e, s) {
        AppLogger.error(e, s, 'schedule ${n.planId}');
      }
    }
  }

  @override
  Stream<NotificationTap> get onTap => _taps.stream;
}
