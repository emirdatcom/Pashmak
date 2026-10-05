import '../content/copy_resolver.dart';
import 'digits.dart';

/// "۱۲ ساعت ۲۷ دقیقه" / "۲۷ دقیقه" for countdowns (the unit words come from copy).
String formatRemaining(CopyResolver copy, Duration d) {
  final total = d.isNegative ? 0 : d.inMinutes;
  final h = total ~/ 60, m = total % 60;
  if (h == 0) return copy.t('quest.countdown.minutes', {'n': m});
  return copy.t('quest.countdown', {'n': h, 'time': toPersianDigits(m)});
}
