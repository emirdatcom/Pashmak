/// Route paths (docs/20 §4).
class Routes {
  const Routes._();
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static String onboardingStep(int n) => '/onboarding/$n';
  static const home = '/home';
  static const checkin = '/checkin';
  // Goals (formerly habits). `/habits/*` still works through a redirect (old notification/widget links).
  static const goals = '/goals';
  static const goalNew = '/goals/new';
  static String goal(String id) => '/goals/$id';
  static String goalEdit(String id) => '/goals/$id/edit';
  static const legacyHabits = '/habits';
  // Compatibility aliases for older call sites.
  static const habits = goals;
  static const habitNew = goalNew;
  static String habit(String id) => goal(id);
  static String habitEdit(String id) => goalEdit(id);
  static const quests = '/quests';
  static const questReflect = '/quests/reflect';
  static const bag = '/bag';
  static const cat = '/cat';
  static const discoveries = '/cat/discoveries';
  static const catEdit = '/cat/edit';
  static const menu = '/menu';
  static const areas = '/menu/areas';
  static const retake = '/menu/areas/retake';
  static const history = '/menu/history';
  static const shopOutfit = '/shop/outfit';
  static const shopFurniture = '/shop/furniture';
  static const restMode = '/settings/rest';
  static String exercisesTab(String tab) => '/exercises?tab=$tab';
  static const exercises = '/exercises';
  static String exerciseRun(String id) => '/exercises/$id/run';
  static const adventure = '/adventure';
  static String adventureResult(String id) => '/adventure/result/$id';
  static const shop = '/shop';
  static const closet = '/shop/closet';
  static String closetOf(String shop) => '/shop/closet?shop=$shop';
  static String shopItem(String shop, String key) => '/shop/$shop/item/$key';
  static String shopCatalog(String shop) => '/shop/$shop/catalog';
  static String shopSell(String shop) => '/shop/$shop/sell';
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
