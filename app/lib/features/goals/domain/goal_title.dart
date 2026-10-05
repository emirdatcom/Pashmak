import '../../../core/content/copy_resolver.dart';

/// Display title of a goal: its own `title` (custom goals), else the goal-library copy, else the legacy
/// `habit.template.*` copy (rows created before prompt 22).
String goalTitle(CopyResolver copy, String? goalKey, String? title) {
  if (goalKey == null) return title ?? '';
  if (copy.has('goal.$goalKey.title')) return copy.t('goal.$goalKey.title');
  return copy.t('habit.template.$goalKey.title');
}
