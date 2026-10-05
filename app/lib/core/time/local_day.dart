import 'clock.dart';

/// A calendar day in the user's day-model: `YYYY-MM-DD` (Gregorian, internal). The day starts at
/// `day_start_hour` local time, so 03:30 with start hour 4 still belongs to yesterday.
class LocalDay implements Comparable<LocalDay> {
  const LocalDay._(this.year, this.month, this.day);

  factory LocalDay.fromDate(DateTime d) => LocalDay._(d.year, d.month, d.day);

  /// The day containing [local] (a device-local DateTime) for the given [dayStartHour].
  factory LocalDay.of(DateTime local, {int dayStartHour = 0}) =>
      LocalDay.fromDate(local.subtract(Duration(hours: dayStartHour)));

  factory LocalDay.today(Clock clock, {int dayStartHour = 0}) =>
      LocalDay.of(clock.now(), dayStartHour: dayStartHour);

  factory LocalDay.parse(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) throw FormatException('Not a LocalDay: $s');
    return LocalDay._(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  final int year;
  final int month;
  final int day;

  /// Noon avoids DST edge cases when doing day arithmetic.
  DateTime get _noon => DateTime(year, month, day, 12);

  LocalDay addDays(int n) => LocalDay.fromDate(_noon.add(Duration(days: n)));

  /// Start of the week: Saturday (docs/20 §6).
  LocalDay weekStart() => addDays(-((_noon.weekday - DateTime.saturday) % 7));

  /// 0 = Saturday … 6 = Friday.
  int get weekdayIndex => (_noon.weekday - DateTime.saturday) % 7;

  DateTime get date => DateTime(year, month, day);

  int daysUntil(LocalDay other) => other._noon.difference(_noon).inHours ~/ 24;

  String get value =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() => value;
  @override
  bool operator ==(Object other) =>
      other is LocalDay && other.year == year && other.month == month && other.day == day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  int compareTo(LocalDay other) => value.compareTo(other.value);
}
