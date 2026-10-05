import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/l10n/digits.dart';
import 'package:pashmak_app/core/l10n/jalali_formatter.dart';
import 'package:pashmak_app/core/time/clock.dart';
import 'package:pashmak_app/core/time/local_day.dart';

void main() {
  group('digits', () {
    test('toPersianDigits / normalizeDigits round trip', () {
      expect(toPersianDigits('۱۲ ab 0123456789'), '۱۲ ab ۰۱۲۳۴۵۶۷۸۹');
      expect(toPersianDigits(42), '۴۲');
      expect(normalizeDigits('۰۹۱۲٣٤٥ x9'), '0912345 x9');
    });
    test('normalizePersianText', () {
      expect(normalizePersianText('عليك‌می'), 'علیک می');
    });
  });

  group('Jalali', () {
    test('2026-10-05 is 13 Mehr 1405', () {
      expect(JalaliFormatter.date(LocalDay.parse('2026-10-05')), '۱۳ مهر ۱۴۰۵');
    });
    test('year boundary: Nowruz 1405 is 2026-03-21', () {
      expect(JalaliFormatter.date(LocalDay.parse('2026-03-21')), '۱ فروردین ۱۴۰۵');
      expect(JalaliFormatter.date(LocalDay.parse('2026-03-20')), '۲۹ اسفند ۱۴۰۴');
    });
    test('leap Esfand has 30 days (1403: 2025-03-20)', () {
      expect(JalaliFormatter.date(LocalDay.parse('2025-03-20')), '۳۰ اسفند ۱۴۰۳');
      expect(JalaliFormatter.date(LocalDay.parse('2025-03-21')), '۱ فروردین ۱۴۰۴');
    });
    test('weekday and month key', () {
      expect(JalaliFormatter.weekday(LocalDay.parse('2026-10-05')), 'دوشنبه'); // Monday
      expect(JalaliFormatter.monthKey(LocalDay.parse('2026-10-05')), '1405-07');
      expect(JalaliFormatter.time(510), '۸:۳۰');
    });
  });

  group('LocalDay', () {
    test('day_start_hour=4: 03:30 belongs to yesterday', () {
      final c = FakeClock(DateTime(2026, 10, 5, 3, 30));
      expect(LocalDay.today(c, dayStartHour: 4).value, '2026-10-04');
      c.set(DateTime(2026, 10, 5, 4, 0));
      expect(LocalDay.today(c, dayStartHour: 4).value, '2026-10-05');
      expect(LocalDay.today(c).value, '2026-10-05');
    });
    test('addDays across month/year and weekStart on Saturday', () {
      expect(LocalDay.parse('2026-12-31').addDays(1).value, '2027-01-01');
      expect(LocalDay.parse('2026-03-01').addDays(-1).value, '2026-02-28');
      // 2026-10-05 is Monday -> week starts Saturday 2026-10-03
      expect(LocalDay.parse('2026-10-05').weekStart().value, '2026-10-03');
      expect(LocalDay.parse('2026-10-03').weekStart().value, '2026-10-03');
      expect(LocalDay.parse('2026-10-09').weekStart().value, '2026-10-03'); // Friday
      expect(LocalDay.parse('2026-10-03').weekdayIndex, 0);
      expect(LocalDay.parse('2026-10-02').daysUntil(LocalDay.parse('2026-10-05')), 3);
    });
    test('parse rejects garbage', () {
      expect(() => LocalDay.parse('2026-1-5'), throwsFormatException);
    });
  });
}
