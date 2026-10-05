import '../l10n/digits.dart';

enum DistressKind { lowMoodStreak, keyword }

class CheckinPoint {
  const CheckinPoint(this.day, this.moodLevel);
  final String day; // LocalDay.value
  final int moodLevel;
}

/// Local-only detection of strong distress signals (docs/30 §7). Pure and side-effect free. The
/// outcome is never sent anywhere; the result is a kind gentle card, never a diagnosis.
class DistressDetector {
  DistressDetector({required this.keywords, required this.lowMoodLevel, required this.lowMoodCount, required this.windowDays})
      : _normalizedKeywords = [for (final k in keywords) _norm(k)].where((k) => k.isNotEmpty).toList();

  final List<String> keywords;
  final int lowMoodLevel; // safety.low_mood_level: levels <= this count as low
  final int lowMoodCount; // safety.low_mood_count
  final int windowDays; // safety.low_mood_window_days (today + previous days)
  final List<String> _normalizedKeywords;

  /// Lower-cases, unifies Arabic/Persian letters, ZWNJ → space, collapses spaces, drops digits' variants.
  static String _norm(String s) => normalizePersianText(normalizeDigits(s)).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// [recent] holds check-ins of the window (any order); [today] is today's LocalDay.value.
  DistressKind? evaluate({required List<CheckinPoint> recent, required String today, String? note}) {
    if (note != null && note.isNotEmpty && _normalizedKeywords.isNotEmpty) {
      final n = _norm(note);
      if (_normalizedKeywords.any(n.contains)) return DistressKind.keyword;
    }
    final t = DateTime.parse(today);
    final low = recent.where((c) {
      final days = t.difference(DateTime.parse(c.day)).inDays;
      return days >= 0 && days < windowDays && c.moodLevel <= lowMoodLevel;
    }).length;
    return low >= lowMoodCount ? DistressKind.lowMoodStreak : null;
  }
}
