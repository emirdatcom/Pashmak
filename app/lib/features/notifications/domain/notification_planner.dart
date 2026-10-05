import '../../../core/time/local_day.dart';

/// Priority order of docs/50 §3 rule 2 (first = highest).
const notificationPriority = ['trial', 'support_reply', 'habit_reminder', 'cat_returned', 'evening_checkin', 'morning', 'seasonal', 'comeback', 'streak_gentle'];

class PlanHabit {
  const PlanHabit({required this.id, this.templateKey, this.title, this.reminderMinutes, required this.scheduleType, required this.weekdaysMask, this.isLocked = false, this.doneToday = false});
  final String id;
  final String? templateKey;
  final String? title;
  final int? reminderMinutes;
  final String scheduleType;
  final int weekdaysMask; // bit0 = Saturday
  final bool isLocked;
  final bool doneToday;
}

class PlanAdventure {
  const PlanAdventure({required this.id, required this.endsAt});
  final String id;
  final DateTime endsAt;
}

class PlanTrial {
  const PlanTrial({required this.active, this.startedAt, this.purchased = false});
  final bool active;
  final DateTime? startedAt;
  final bool purchased;
}

class PlanLogEntry {
  const PlanLogEntry({required this.type, this.ref = '', required this.scheduledFor, this.openedAt});
  final String type;
  final String ref; // habit id for habit_reminder
  final DateTime scheduledFor;
  final DateTime? openedAt;
}

class SeasonalEvent {
  const SeasonalEvent({required this.id, required this.at, required this.copyKey});
  final String id;
  final DateTime at;
  final String copyKey;
}

class PlannerSettings {
  const PlannerSettings({
    required this.enabled,
    this.morningMinutes = 540,
    this.eveningMinutes = 1230,
    this.quietStartMinutes = 1350,
    this.quietEndMinutes = 480,
    this.maxPerDay = 3,
    this.comebackDays = const [3, 7, 14],
    this.ignoreThreshold = 3,
    this.trialReminderDay = 6,
    this.streakGentleMinutes = 1140,
    this.comebackMinutes = 1080,
    this.trialMinutes = 720,
  });

  /// type → on/off (user switches already merged with the remote kill switch).
  final Map<String, bool> enabled;
  final int morningMinutes;
  final int eveningMinutes;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final int maxPerDay;
  final List<int> comebackDays;
  final int ignoreThreshold;
  final int trialReminderDay;
  final int streakGentleMinutes;
  final int comebackMinutes;
  final int trialMinutes;

  bool on(String type) => enabled[type] ?? false;
}

class PlanInput {
  const PlanInput({
    required this.now,
    this.dayStartHour = 4,
    required this.settings,
    this.habits = const [],
    this.adventure,
    this.checkedInToday = false,
    this.streakCurrent = 0,
    this.activeToday = false,
    this.lastOpenedAt,
    this.trial = const PlanTrial(active: false),
    this.log = const [],
    this.seasonal = const [],
    this.supportReplyAt,
  });
  final DateTime now;
  final int dayStartHour;
  final PlannerSettings settings;
  final List<PlanHabit> habits;
  final PlanAdventure? adventure;
  final bool checkedInToday;
  final int streakCurrent;
  final bool activeToday;
  final DateTime? lastOpenedAt;
  final PlanTrial trial;
  final List<PlanLogEntry> log;
  final List<SeasonalEvent> seasonal;

  /// When a support reply notification should fire (set by the `support_poll` task when it found a new reply).
  final DateTime? supportReplyAt;
}

/// A notification the planner wants scheduled. Text is resolved later from the copy keys.
class PlanItem {
  const PlanItem({required this.type, required this.ref, required this.fireAt, required this.titleKey, required this.bodyKey, this.vars = const {}, required this.route});
  final String type;
  final String ref;
  final DateTime fireAt;
  final String titleKey;
  final String bodyKey;
  final Map<String, Object?> vars;
  final String route;

  String get day => LocalDay.fromDate(fireAt).value;

  /// Deterministic id = hash(type + ref + fire_day) (docs/50 §3 rule 6).
  String get id => '$type:$ref:$day';
  int get intId {
    var h = 0x811c9dc5;
    for (final b in id.codeUnits) {
      h ^= b;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }
}

/// Pure planner of docs/50 §3: produces up to 7 days of notifications.
List<PlanItem> planNotifications(PlanInput i) {
  final s = i.settings;
  final today = LocalDay.of(i.now, dayStartHour: i.dayStartHour);
  final cands = <PlanItem>[];

  DateTime at(LocalDay d, int minutes) => DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);

  for (var off = 0; off < 7; off++) {
    final d = today.addDays(off);
    final isToday = off == 0;
    if (s.on('morning')) {
      cands.add(PlanItem(type: 'morning', ref: '', fireAt: at(d, s.morningMinutes), titleKey: 'notif.morning.title', bodyKey: 'notif.morning', route: '/checkin'));
    }
    if (s.on('habit_reminder')) {
      for (final h in i.habits) {
        if (h.reminderMinutes == null || h.isLocked) continue;
        final scheduled = h.scheduleType == 'daily' || (h.weekdaysMask >> d.weekdayIndex) & 1 == 1;
        if (!scheduled || (isToday && h.doneToday)) continue;
        final tk = h.templateKey;
        cands.add(PlanItem(
          type: 'habit_reminder',
          ref: h.id,
          fireAt: at(d, h.reminderMinutes!),
          titleKey: 'notif.habit_reminder.title',
          bodyKey: tk != null ? 'notif.habit_reminder.$tk' : 'notif.habit_reminder.generic',
          vars: {'habit': h.title ?? tk ?? ''},
          route: '/habits/${h.id}',
        ));
      }
    }
    if (s.on('evening_checkin') && !(isToday && i.checkedInToday)) {
      cands.add(PlanItem(type: 'evening_checkin', ref: '', fireAt: at(d, s.eveningMinutes), titleKey: 'notif.evening_checkin.title', bodyKey: 'notif.evening_checkin', route: '/checkin'));
    }
  }

  final adv = i.adventure;
  if (adv != null && s.on('cat_returned')) {
    cands.add(PlanItem(type: 'cat_returned', ref: adv.id, fireAt: adv.endsAt, titleKey: 'notif.cat_returned.title', bodyKey: 'notif.cat_returned', route: '/adventure'));
  }

  if (s.on('streak_gentle') && i.streakCurrent >= 3 && !i.activeToday) {
    final recent = i.log.where((l) => l.type == 'streak_gentle' && i.now.difference(l.scheduledFor) < const Duration(days: 2));
    if (recent.isEmpty) {
      cands.add(PlanItem(type: 'streak_gentle', ref: '', fireAt: at(today, s.streakGentleMinutes), titleKey: 'notif.streak_gentle.title', bodyKey: 'notif.streak_gentle', route: '/home'));
    }
  }

  final opened = i.lastOpenedAt;
  if (opened != null && s.on('comeback')) {
    final base = LocalDay.fromDate(opened);
    for (final n in s.comebackDays) {
      final d = base.addDays(n);
      if (d.compareTo(today) >= 0 && d.compareTo(today.addDays(6)) <= 0) {
        cands.add(PlanItem(type: 'comeback', ref: '$n', fireAt: at(d, s.comebackMinutes), titleKey: 'notif.comeback.title', bodyKey: 'notif.comeback.$n', route: '/home'));
      }
    }
  }

  final trial = i.trial;
  if (s.on('trial') && trial.active && !trial.purchased && trial.startedAt != null) {
    final start = LocalDay.fromDate(trial.startedAt!);
    for (final n in [s.trialReminderDay, s.trialReminderDay + 1]) {
      final d = start.addDays(n - 1);
      cands.add(PlanItem(type: 'trial', ref: '$n', fireAt: at(d, s.trialMinutes), titleKey: 'notif.trial.title', bodyKey: 'notif.trial.$n', route: '/paywall?trigger=trial_end'));
    }
  }

  final reply = i.supportReplyAt;
  if (s.on('support_reply') && reply != null) {
    // Generic text only (no message content); follows quiet hours and the daily cap like everything else.
    cands.add(PlanItem(type: 'support_reply', ref: '', fireAt: reply, titleKey: 'notif.support_reply.title', bodyKey: 'notif.support_reply', route: '/support'));
  }

  if (s.on('seasonal')) {
    for (final e in i.seasonal) {
      cands.add(PlanItem(type: 'seasonal', ref: e.id, fireAt: e.at, titleKey: 'notif.seasonal.title', bodyKey: e.copyKey, route: '/home'));
    }
  }

  // 1. quiet hours: move to the end of the quiet window; the cat's return is dropped instead.
  final moved = <PlanItem>[];
  for (final c in cands) {
    final m = c.fireAt.hour * 60 + c.fireAt.minute;
    if (!_inQuiet(m, s.quietStartMinutes, s.quietEndMinutes)) {
      moved.add(c);
      continue;
    }
    if (c.type == 'cat_returned') continue;
    final wraps = s.quietStartMinutes > s.quietEndMinutes;
    final dayShift = (wraps && m >= s.quietStartMinutes) ? 1 : 0;
    final d = LocalDay.fromDate(c.fireAt).addDays(dayShift);
    moved.add(PlanItem(type: c.type, ref: c.ref, fireAt: DateTime(d.year, d.month, d.day, s.quietEndMinutes ~/ 60, s.quietEndMinutes % 60), titleKey: c.titleKey, bodyKey: c.bodyKey, vars: c.vars, route: c.route));
  }

  // past items are not scheduled
  var items = moved.where((c) => c.fireAt.isAfter(i.now)).toList()..sort((a, b) => a.fireAt.compareTo(b.fireAt));

  // 3. frequency reduction for ignored types (per habit for habit_reminder)
  items = _reduceIgnored(items, i);

  // 2. daily cap by priority
  final byDay = <String, List<PlanItem>>{};
  for (final it in items) {
    byDay.putIfAbsent(it.day, () => []).add(it);
  }
  final kept = <PlanItem>[];
  for (final list in byDay.values) {
    list.sort((a, b) {
      final p = notificationPriority.indexOf(a.type).compareTo(notificationPriority.indexOf(b.type));
      return p != 0 ? p : a.fireAt.compareTo(b.fireAt);
    });
    kept.addAll(list.take(s.maxPerDay));
  }
  kept.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return kept;
}

bool _inQuiet(int m, int start, int end) => start > end ? (m >= start || m < end) : (m >= start && m < end);

/// Rule 3 (A14): 3 ignored in a row → every other day; 6 → weekly; any opened notification resets it.
List<PlanItem> _reduceIgnored(List<PlanItem> items, PlanInput i) {
  final threshold = i.settings.ignoreThreshold;
  final out = <PlanItem>[];
  final lastAllowed = <String, LocalDay>{};
  for (final it in items) {
    if (it.type == 'support_reply') {
      out.add(it); // a reply from a person is never throttled as "ignored"
      continue;
    }
    final key = '${it.type}|${it.type == 'habit_reminder' ? it.ref : ''}';
    final history = i.log.where((l) => l.type == it.type && (it.type != 'habit_reminder' || l.ref == it.ref) && l.scheduledFor.isBefore(i.now.subtract(const Duration(hours: 2)))).toList()
      ..sort((a, b) => b.scheduledFor.compareTo(a.scheduledFor));
    var ignored = 0;
    for (final h in history) {
      if (h.openedAt != null) break;
      ignored++;
    }
    final gap = ignored >= threshold * 2 ? 7 : (ignored >= threshold ? 2 : 1);
    if (gap == 1) {
      out.add(it);
      continue;
    }
    final day = LocalDay.fromDate(it.fireAt);
    final last = lastAllowed[key] ?? (history.isEmpty ? null : LocalDay.fromDate(history.first.scheduledFor));
    if (last == null || last.daysUntil(day) >= gap) {
      out.add(it);
      lastAllowed[key] = day;
    }
  }
  return out;
}
