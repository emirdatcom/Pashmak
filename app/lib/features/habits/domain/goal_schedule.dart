import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/time/local_day.dart';

/// Whether a goal is scheduled on [day].
///
/// - `once`: only on [dueDay].
/// - `monthly`: on the Persian day-of-month of [dueDay] (clamped to the last day of shorter months).
/// - `daily` / `weekly`: every day, or the days of the Saturday-first [weekdaysMask].
/// For repeating goals a [dueDay] is the first day; earlier days are not scheduled.
bool goalScheduledOn({
  required String repeatType,
  required String? dueDay,
  required String scheduleType,
  required int weekdaysMask,
  required LocalDay day,
}) {
  if (repeatType == 'once') return dueDay == day.value;
  if (dueDay != null && day.value.compareTo(dueDay) < 0) return false;
  if (repeatType == 'monthly') {
    if (dueDay == null) return false;
    final anchor = Jalali.fromDateTime(LocalDay.parse(dueDay).date).day;
    final j = Jalali.fromDateTime(day.date);
    return j.day == (anchor > j.monthLength ? j.monthLength : anchor);
  }
  return scheduleType == 'daily' || (weekdaysMask >> day.weekdayIndex) & 1 == 1;
}
