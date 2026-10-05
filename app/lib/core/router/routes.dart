/// Route paths (docs/20 §4).
class Routes {
  const Routes._();
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static String onboardingStep(int n) => '/onboarding/$n';
  static const home = '/home';
  static const checkin = '/checkin';
  static const habits = '/habits';
  static const habitNew = '/habits/new';
  static String habit(String id) => '/habits/$id';
  static String habitEdit(String id) => '/habits/$id/edit';
  static const exercises = '/exercises';
  static String exerciseRun(String id) => '/exercises/$id/run';
  static const adventure = '/adventure';
  static String adventureResult(String id) => '/adventure/result/$id';
  static const shop = '/shop';
  static const closet = '/shop/closet';
  static const stats = '/stats';
  static const statsDeep = '/stats/deep';
  static String paywall(String trigger) => '/paywall?trigger=$trigger';
  static const settings = '/settings';
  static const subscription = '/settings/subscription';
  static const trialEnded = '/trial-ended';
  static const lockSelect = '/lock-select';
  static const safety = '/safety';
  static String support({String source = 'settings'}) => '/support?source=$source';
  static const supportBase = '/support';
  static const update = '/update';
}
