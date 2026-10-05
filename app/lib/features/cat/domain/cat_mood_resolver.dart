import '../../../core/widgets/cat_renderer.dart';

/// Pure rule from docs/30 §6 (first matching rule wins).
class CatMoodResolver {
  const CatMoodResolver._();

  static CatVisualState resolve({
    required bool adventureActive,
    required int localHour,
    int? lastCheckinMoodToday,
    required bool allHabitsDoneToday,
    required bool adventureJustClaimed,
    List<String> accessories = const [],
    String? background,
  }) {
    CatVisualState s(CatMood m, [CatActivity a = CatActivity.idle]) =>
        CatVisualState(mood: m, activity: a, accessories: accessories, background: background);
    if (adventureActive) return s(CatMood.happy, CatActivity.away); // 1: the cat is out
    if (localHour >= 23 || localHour < 6) return s(CatMood.sleepy); // 2
    if (lastCheckinMoodToday != null && lastCheckinMoodToday <= 2) return s(CatMood.sad); // 3: empathy, not absence
    if (allHabitsDoneToday || adventureJustClaimed) return s(CatMood.proud); // 4
    return s(CatMood.happy); // 5
  }
}
