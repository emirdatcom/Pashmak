import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/content/copy_resolver.dart';
import '../../../core/db/app_database.dart';
import '../../../core/logger.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/local_day.dart';
import '../domain/notification_planner.dart';

/// Keys in `user_settings` for the notification screen.
class NotifSettingKeys {
  const NotifSettingKeys._();
  static String enabled(String type) => 'notif_enabled_$type';
  static const morning = 'notif_morning_minutes';
  static const evening = 'notif_evening_minutes';
  static const quietStart = 'notif_quiet_start_minutes';
  static const quietEnd = 'notif_quiet_end_minutes';
  static const exactAlarms = 'notif_exact_alarms';
}

/// Defaults of docs/50 §2: everything on except `streak_gentle` (opt-in).
const defaultNotifTypes = {
  'morning': true,
  'habit_reminder': true,
  'evening_checkin': true,
  'cat_returned': true,
  'streak_gentle': false,
  'comeback': true,
  'trial': true,
  'seasonal': true,
};

int parseHHmm(String s) {
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Collects inputs → pure planner → resolves copy → hands the plan to the OS.
/// Triggers: app open, data changes (habit/check-in/exercise/adventure/settings/trial), WorkManager
/// `notif_replan`, timezone change. Replanning is cheap and idempotent (deterministic ids).
class NotificationScheduler {
  NotificationScheduler({
    required AppDatabase db,
    required Clock clock,
    required NotificationService service,
    required AppConfig Function() config,
    required CopyResolver Function() copy,
    AnalyticsService analytics = const NoopAnalytics(),
    this.dayStartHour = 4,
  })  : _db = db,
        _clock = clock,
        _service = service,
        _config = config,
        _copy = copy,
        _analytics = analytics;

  final AppDatabase _db;
  final Clock _clock;
  final NotificationService _service;
  final AppConfig Function() _config;
  final CopyResolver Function() _copy;
  final AnalyticsService _analytics;
  final int dayStartHour;

  static const _kOpens = 'recent_opens';
  static const _kLastOpened = 'last_opened_at';

  /// Records that the app was opened (for comeback timing and ignore detection).
  Future<void> recordOpen() async {
    final now = _clock.now().millisecondsSinceEpoch;
    await _db.setMeta(_kLastOpened, '$now');
    final opens = (jsonDecode(await _db.meta(_kOpens) ?? '[]') as List).cast<int>()..add(now);
    await _db.setMeta(_kOpens, jsonEncode(opens.length > 60 ? opens.sublist(opens.length - 60) : opens));
  }

  Future<PlannerSettings> _settings() async {
    final cfg = _config();
    Future<int> mins(String key, String def) async => int.tryParse(await _db.setting(key) ?? '') ?? parseHHmm(def);
    final enabled = <String, bool>{};
    for (final t in defaultNotifTypes.keys) {
      final user = await _db.setting(NotifSettingKeys.enabled(t));
      final on = user == null ? defaultNotifTypes[t]! : user == 'true';
      enabled[t] = on && cfg.notifTypeEnabled(t); // remote kill switch
    }
    return PlannerSettings(
      enabled: enabled,
      morningMinutes: await mins(NotifSettingKeys.morning, cfg.notifMorningTime),
      eveningMinutes: await mins(NotifSettingKeys.evening, cfg.notifEveningTime),
      quietStartMinutes: await mins(NotifSettingKeys.quietStart, cfg.notifQuietStart),
      quietEndMinutes: await mins(NotifSettingKeys.quietEnd, cfg.notifQuietEnd),
      maxPerDay: cfg.notifMaxPerDay,
      comebackDays: cfg.notifComebackDays,
      ignoreThreshold: cfg.notifIgnoreThreshold,
      trialReminderDay: cfg.trialReminderDay,
    );
  }

  Future<PlanInput> buildInput() async {
    final now = _clock.now();
    final today = LocalDay.of(now, dayStartHour: dayStartHour);
    final habitRows = await (_db.select(_db.habits)..where((h) => h.archivedAt.isNull() & h.deletedAt.isNull())).get();
    final doneRows = await (_db.select(_db.habitLogs)..where((l) => l.localDay.equals(today.value) & l.deletedAt.isNull())).get();
    final done = {for (final l in doneRows) if (l.count >= 1) l.habitId};
    final habits = [
      for (final h in habitRows)
        PlanHabit(id: h.id, templateKey: h.templateKey, title: h.title, reminderMinutes: h.reminderMinutes, scheduleType: h.scheduleType, weekdaysMask: h.weekdaysMask, isLocked: h.isLocked, doneToday: done.contains(h.id)),
    ];
    final adv = await (_db.select(_db.adventures)..where((a) => a.status.equals('active'))).getSingleOrNull();
    final checkedIn = (await (_db.select(_db.checkins)..where((c) => c.localDay.equals(today.value) & c.deletedAt.isNull())).get()).isNotEmpty;
    final streak = await _db.select(_db.streakState).getSingle();
    final opens = (jsonDecode(await _db.meta(_kOpens) ?? '[]') as List).cast<int>();
    final lastOpened = int.tryParse(await _db.meta(_kLastOpened) ?? '');

    // Ignored = past, not opened by tap, and the app was not opened within 2 hours (docs/50 §5).
    final logRows = await _db.select(_db.notificationLog).get();
    final log = <PlanLogEntry>[];
    for (final r in logRows) {
      final parts = r.id.split(':');
      final scheduled = DateTime.fromMillisecondsSinceEpoch(r.scheduledFor);
      DateTime? opened = r.openedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(r.openedAt!);
      if (opened == null && opens.any((o) => o >= r.scheduledFor && o <= r.scheduledFor + const Duration(hours: 2).inMilliseconds)) opened = scheduled;
      log.add(PlanLogEntry(type: r.type, ref: parts.length > 1 ? parts[1] : '', scheduledFor: scheduled, openedAt: opened));
    }

    final trialStart = int.tryParse(await _db.meta('trial_started_at') ?? '');
    final trialEnd = int.tryParse(await _db.meta('trial_ends_at') ?? '');
    final purchased = await _db.meta('premium_purchased') == 'true';
    final trialActive = trialStart != null && trialEnd != null && now.millisecondsSinceEpoch < trialEnd;

    return PlanInput(
      now: now,
      dayStartHour: dayStartHour,
      settings: await _settings(),
      habits: habits,
      adventure: adv == null ? null : PlanAdventure(id: adv.id, endsAt: DateTime.fromMillisecondsSinceEpoch(adv.endsAt)),
      checkedInToday: checkedIn,
      streakCurrent: streak.current,
      activeToday: streak.lastActiveDay == today.value,
      lastOpenedAt: lastOpened == null ? null : DateTime.fromMillisecondsSinceEpoch(lastOpened),
      trial: PlanTrial(active: trialActive, startedAt: trialStart == null ? null : DateTime.fromMillisecondsSinceEpoch(trialStart), purchased: purchased),
      log: log,
    );
  }

  /// Plans and (re)schedules. Returns what was scheduled.
  Future<List<ResolvedNotification>> replan() async {
    try {
      final input = await buildInput();
      final plan = planNotifications(input);
      final copy = _copy();
      final exact = await _db.setting(NotifSettingKeys.exactAlarms) == 'true';
      final resolved = <ResolvedNotification>[];
      for (final p in plan) {
        if (!copy.has(p.bodyKey)) {
          AppLogger.warn('notification copy missing: ${p.bodyKey}');
          continue;
        }
        resolved.add(ResolvedNotification(
          id: p.intId,
          planId: p.id,
          type: p.type,
          ref: p.ref,
          fireAt: p.fireAt,
          title: copy.has(p.titleKey) ? copy.t(p.titleKey) : '',
          body: copy.t(p.bodyKey, p.vars),
          route: p.route,
          exact: exact && p.type == 'habit_reminder',
          actionLabel: p.type == 'habit_reminder' && copy.has('notif.action.done') ? copy.t('notif.action.done') : null,
        ));
      }
      await _service.replaceAll(resolved);
      await _logScheduled(resolved);
      return resolved;
    } catch (e, s) {
      AppLogger.error(e, s, 'replan');
      return const [];
    }
  }

  Future<void> _logScheduled(List<ResolvedNotification> items) async {
    await _db.batch((b) => b.insertAll(
        _db.notificationLog,
        [for (final n in items) NotificationLogCompanion.insert(id: n.planId, type: n.type, scheduledFor: n.fireAt.millisecondsSinceEpoch)],
        mode: InsertMode.insertOrIgnore));
    // keep the log small: drop entries older than 60 days
    final cutoff = _clock.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch;
    await (_db.delete(_db.notificationLog)..where((l) => l.scheduledFor.isSmallerThanValue(cutoff))).go();
  }

  /// A notification was tapped: log it and count it (no personal data in the event).
  Future<void> onOpened(NotificationTap tap) async {
    await (_db.update(_db.notificationLog)..where((l) => l.id.equals(tap.planId))).write(NotificationLogCompanion(openedAt: Value(_clock.now().millisecondsSinceEpoch)));
    await _analytics.track(AnalyticsEvent.notificationOpened, {'type': tap.type});
  }
}
