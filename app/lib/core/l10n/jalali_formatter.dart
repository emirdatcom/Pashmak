import 'package:shamsi_date/shamsi_date.dart';

import '../time/local_day.dart';
import 'digits.dart';

/// Persian calendar display helpers. Internal storage stays Gregorian [LocalDay].
class JalaliFormatter {
  const JalaliFormatter._();

  static const monthNames = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند', //
  ];

  /// Saturday-first (index 0 = شنبه).
  static const weekdayNames = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];

  static Jalali toJalali(LocalDay d) => Jalali.fromDateTime(d.date);

  /// `۱۳ مهر ۱۴۰۵`
  static String date(LocalDay d) {
    final j = toJalali(d);
    return '${toPersianDigits(j.day)} ${monthNames[j.month - 1]} ${toPersianDigits(j.year)}';
  }

  /// `۱۳ مهر`
  static String dayMonth(LocalDay d) {
    final j = toJalali(d);
    return '${toPersianDigits(j.day)} ${monthNames[j.month - 1]}';
  }

  static String weekday(LocalDay d) => weekdayNames[d.weekdayIndex];

  /// `دوشنبه، ۱۳ مهر ۱۴۰۵`
  static String weekdayDate(LocalDay d) => '${weekday(d)}، ${date(d)}';

  static String monthName(LocalDay d) => monthNames[toJalali(d).month - 1];

  /// `YYYY-MM` of the Persian month (used for monthly streak-freeze reset).
  static String monthKey(LocalDay d) {
    final j = toJalali(d);
    return '${j.year.toString().padLeft(4, '0')}-${j.month.toString().padLeft(2, '0')}';
  }

  /// `۸:۳۰`
  static String time(int minutesFromMidnight) {
    final h = minutesFromMidnight ~/ 60, m = minutesFromMidnight % 60;
    return toPersianDigits('$h:${m.toString().padLeft(2, '0')}');
  }
}
