import '../../core/util/version.dart';
import 'routes.dart';

/// Pure redirect rules (docs/20 §4). Returns null to stay on [location].
///
/// * `/safety` is reachable from anywhere (no gate, ever).
/// * app older than `update.min_supported_version` → `/update` (hard update).
/// * onboarding not completed → `/onboarding/1`.
String? appRedirect({
  required String location,
  required bool onboardingCompleted,
  required String appVersion,
  required String minSupportedVersion,
}) {
  if (location.startsWith(Routes.safety)) return null;
  // A new phone restores its account before onboarding (phone link → backup restore).
  final restoring = location == '${Routes.settings}/phone' || location == '${Routes.settings}/restore';
  final needsUpdate = compareVersions(appVersion, minSupportedVersion) < 0;
  if (needsUpdate) return location == Routes.update ? null : Routes.update;
  if (location == Routes.update) return Routes.home;
  if (!onboardingCompleted && restoring) return null;
  if (!onboardingCompleted) {
    return location.startsWith(Routes.onboarding) ? null : Routes.onboardingStep(1);
  }
  if (location == Routes.splash || location == Routes.onboarding || location.startsWith('${Routes.onboarding}/')) {
    return Routes.home;
  }
  return null;
}
