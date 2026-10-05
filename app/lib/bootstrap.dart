import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/auth/device_identity.dart';
import 'core/auth/token_store.dart';
import 'core/config/asset_source.dart';
import 'core/config/config_repository.dart';
import 'core/content/content_repository.dart';
import 'core/db/app_database.dart';
import 'core/db/connection.dart';
import 'core/entitlement/entitlement_repository.dart';
import 'core/entitlement/signature_verifier.dart';
import 'core/flavor.dart';
import 'core/logger.dart';
import 'core/network/api_client.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/background/background_handlers.dart';
import 'core/providers.dart';
import 'core/widgets_home/widget_callbacks.dart';
import 'core/time/clock.dart';
import 'core/time/local_day.dart';
import 'features/system/db_error_screen.dart';

/// App entry shared by both flavors (see main_bazaar.dart / main_myket.dart).
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) => AppLogger.error(d.exception, d.stack, 'flutter');
  PlatformDispatcher.instance.onError = (e, s) {
    AppLogger.error(e, s, 'platform');
    return true;
  };
  await runZonedGuarded(() async {
    await _initTimezone();
    await _start(flavor);
  }, (e, s) => AppLogger.error(e, s, 'zone'));
}

Future<void> _initTimezone() async {
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
  } catch (e) {
    AppLogger.warn('timezone fallback to UTC: $e');
  }
}

Future<void> _start(Flavor flavor) async {
  final overrides = await buildOverrides(flavor);
  if (overrides is _DbFailure) {
    runApp(_DbErrorApp(failure: overrides, retry: () => unawaited(_start(flavor))));
    return;
  }
  unawaited(registerWidgetCallback().catchError((Object e, StackTrace s) => AppLogger.error(e, s, 'widget callback')));
  unawaited(registerBackgroundTasks().catchError((Object e, StackTrace s) => AppLogger.error(e, s, 'register tasks')));
  runApp(ProviderScope(overrides: (overrides as _Ok).overrides, child: const App()));
}

class _Ok {
  _Ok(this.overrides);
  final List<Override> overrides;
}

class _DbFailure {
  _DbFailure(this.error);
  final Object error;
}

/// Opens the encrypted DB and loads config + content. Returns [_DbFailure] if the DB cannot be opened.
Future<Object> buildOverrides(Flavor? flavorOrNull) async {
  final info = await PackageInfo.fromPlatform();
  final AppDatabase db;
  try {
    final dir = await getApplicationSupportDirectory();
    final key = await DbKeyStore().getOrCreate();
    db = AppDatabase(openEncrypted(File(p.join(dir.path, 'app.db')), key));
    await db.meta('install_id'); // forces open: wrong key / corrupt file surface here
  } catch (e, s) {
    AppLogger.error(e, s, 'db open');
    return _DbFailure(e);
  }
  AppLogger.attach(db);
  // The flavor is remembered so background tasks (WorkManager) talk to the server as the right market.
  final storedFlavor = await db.meta('flavor');
  final flavor = flavorOrNull ?? Flavor.values.firstWhere((f) => f.wireName == storedFlavor, orElse: () => Flavor.bazaar);
  await db.setMeta('flavor', flavor.wireName);

  const clock = SystemClock();
  const assets = BundleAssetSource();
  final identity = DeviceIdentity(db, AndroidDeviceIdSource());
  final api = ApiClient(
    baseUrl: apiBaseUrl,
    info: ClientInfo(appVersion: info.version, market: flavor.wireName),
    identity: identity,
    tokens: TokenStore(const SecureSecretStore()),
    clock: clock,
  );
  final config = ConfigRepository(db, assets, api, clock);
  await config.load();
  final content = ContentRepository(db, assets, api, appVersion: info.version);
  await content.load();

  final copyEntries = content.bundledEntries('copy_fa');
  final catDefault = (content.bundledEntries('brand')['cat_default_name'] as String?) ?? '';
  String chan(String suffix, String id) => ((copyEntries['notif.channel.$id.$suffix'] as String?) ?? id).replaceAll('{CAT_NAME}', catDefault);
  final notifications = LocalNotificationService(
    channels: NotificationChannels(
      names: {for (final id in NotificationChannels.ids) id: chan('name', id)},
      descriptions: {for (final id in NotificationChannels.ids) id: chan('desc', id)},
    ),
    onBackgroundAction: notificationBackgroundHandler,
  );
  final entitlements = EntitlementRepository(db, api, SignatureVerifier(await _loadEntitlementKeys()), clock, trialDays: () => config.current.trialDays);
  await entitlements.load();
  final onboarded = await db.meta('onboarding_completed') == 'true';
  final catName = await db.meta('cat_name') ?? '';
  final dayStart = (int.tryParse(await db.setting('day_start_hour') ?? '') ?? 4).clamp(0, 6);
  final installAt = int.tryParse(await db.meta('install_at') ?? '') ?? clock.now().millisecondsSinceEpoch;
  if (await db.meta('install_at') == null) await db.setMeta('install_at', '$installAt');
  final installAge = clock.now().difference(DateTime.fromMillisecondsSinceEpoch(installAt)).inDays;
  final themeMode = ThemeModeNotifier.parse(await db.setting('theme_mode'));
  final softDismissed = await db.meta('soft_update_dismissed_day') == LocalDay.today(clock, dayStartHour: dayStart).value;

  return _Ok([
    flavorProvider.overrideWithValue(flavor),
    appVersionProvider.overrideWithValue(info.version),
    applicationIdProvider.overrideWithValue(info.packageName),
    databaseProvider.overrideWithValue(db),
    apiClientProvider.overrideWithValue(api),
    configRepositoryProvider.overrideWithValue(config),
    contentRepositoryProvider.overrideWithValue(content),
    deviceIdentityProvider.overrideWithValue(identity),
    entitlementRepositoryProvider.overrideWithValue(entitlements),
    notificationServiceProvider.overrideWithValue(notifications),
    onboardingCompletedProvider.overrideWith(() => _PresetOnboarding(onboarded)),
    catNameProvider.overrideWith(() => _PresetCatName(catName)),
    dayStartHourProvider.overrideWith(() => _PresetDayStart(dayStart)),
    themeModeProvider.overrideWith(() => _PresetTheme(themeMode)),
    installAgeDaysProvider.overrideWith(() => _PresetAge(installAge)),
    softUpdateDismissedProvider.overrideWith(() => _PresetSoftUpdate(softDismissed)),
  ]);
}

/// Production keys ship in assets/keys/entitlement_pub.json. With no key the app can never trust a
/// state and stays on the free tier (fail-safe). Staging/dev may add one with
/// `--dart-define=ENT_PUBKEY=<kid>:<base64url public key>` without committing it.
const _extraKey = String.fromEnvironment('ENT_PUBKEY');

Future<EntitlementKeys> _loadEntitlementKeys() async {
  final keys = EntitlementKeys.fromJson(await rootBundle.loadString('assets/keys/entitlement_pub.json'));
  if (_extraKey.contains(':')) {
    final i = _extraKey.indexOf(':');
    return keys.withKey(_extraKey.substring(0, i), _extraKey.substring(i + 1));
  }
  return keys;
}

class _PresetOnboarding extends OnboardingCompletedNotifier {
  _PresetOnboarding(this._v);
  final bool _v;
  @override
  bool build() => _v;
}

class _PresetDayStart extends DayStartHourNotifier {
  _PresetDayStart(this._v);
  final int _v;
  @override
  int build() => _v;
}

class _PresetSoftUpdate extends SoftUpdateDismissedNotifier {
  _PresetSoftUpdate(this._v);
  final bool _v;
  @override
  bool build() => _v;
}

class _PresetAge extends InstallAgeNotifier {
  _PresetAge(this._v);
  final int _v;
  @override
  int build() => _v;
}

class _PresetTheme extends ThemeModeNotifier {
  _PresetTheme(this._v);
  final ThemeMode _v;
  @override
  ThemeMode build() => _v;
}

class _PresetCatName extends CatNameNotifier {
  _PresetCatName(this._v);
  final String _v;
  @override
  String build() => _v;
}

class _DbErrorApp extends StatelessWidget {
  const _DbErrorApp({required this.failure, required this.retry});
  final _DbFailure failure;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    // Content packs are not loaded here; the strings come from the bundled copy_fa pack.
    return FutureBuilder<Map<String, dynamic>>(
      future: const BundleAssetSource().load('assets/content/copy_fa.json').then((s) => _entries(s)),
      builder: (context, snap) {
        final c = snap.data ?? const {};
        String t(String k) => (c[k] as String?) ?? '';
        return MaterialApp(
          locale: const Locale('fa', 'IR'),
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: DbErrorScreen(title: t('system.db_error.title'), body: t('system.db_error.body'), retryLabel: t('system.db_error.retry'), onRetry: retry),
        );
      },
    );
  }
}

Map<String, dynamic> _entries(String json) =>
    ((jsonDecode(json) as Map<String, dynamic>)['entries'] as Map<String, dynamic>);

/// Opens the same dependency graph in a background isolate (WorkManager task, notification action).
/// Returns null if the database cannot be opened.
Future<ProviderContainer?> openBackgroundContainer() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initTimezone();
  // Background work only needs local data; the flavor only matters for network headers.
  final r = await buildOverrides(null);
  if (r is! _Ok) return null;
  return ProviderContainer(overrides: r.overrides);
}
