import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'analytics/analytics_service.dart';
import 'auth/device_identity.dart';
import 'auth/token_store.dart';
import 'config/app_config.dart';
import 'config/config_repository.dart';
import 'content/content_repository.dart';
import 'content/copy_resolver.dart';
import 'db/app_database.dart';
import 'flavor.dart';
import 'network/api_client.dart';
import 'notifications/notification_service.dart';
import 'payments/payment_gateway.dart';
import 'time/clock.dart';
import 'time/local_day.dart';
import '../features/cat/presentation/static_cat_renderer.dart';
import 'widgets/cat_renderer.dart';

// Providers that bootstrap (or tests) must override with real instances.
final flavorProvider = Provider<Flavor>((ref) => throw UnimplementedError('flavorProvider'));
final appVersionProvider = Provider<String>((ref) => throw UnimplementedError('appVersionProvider'));
final applicationIdProvider = Provider<String>((ref) => throw UnimplementedError('applicationIdProvider'));
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('databaseProvider'));
final apiClientProvider = Provider<ApiClient>((ref) => throw UnimplementedError('apiClientProvider'));
final configRepositoryProvider = Provider<ConfigRepository>((ref) => throw UnimplementedError('configRepositoryProvider'));
final contentRepositoryProvider = Provider<ContentRepository>((ref) => throw UnimplementedError('contentRepositoryProvider'));

final clockProvider = Provider<Clock>((ref) => const SystemClock());
final secretStoreProvider = Provider<SecretStore>((ref) => const SecureSecretStore());
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore(ref.watch(secretStoreProvider)));
final deviceIdentityProvider = Provider<DeviceIdentity>((ref) => DeviceIdentity(ref.watch(databaseProvider), AndroidDeviceIdSource()));

final paymentGatewayProvider = Provider<PaymentGateway>((ref) => FakeGateway(market: ref.watch(flavorProvider).market));
final notificationServiceProvider = Provider<NotificationService>((ref) => const NoopNotificationService());
final catRendererProvider = Provider<CatRenderer>((ref) => const StaticCatRenderer());

/// Random id of the current app session (new per process).
final sessionIdProvider = Provider<String>((ref) => const Uuid().v4());

final analyticsProvider = Provider<AnalyticsService>((ref) => QueueAnalytics(
      ref.watch(databaseProvider),
      ref.watch(clockProvider),
      sessionId: () => ref.read(sessionIdProvider),
    ));

/// Current effective config; replaced when a refresh brings new values.
class AppConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() => ref.watch(configRepositoryProvider).current;
  void reload() => state = ref.read(configRepositoryProvider).current;
}

final appConfigProvider = NotifierProvider<AppConfigNotifier, AppConfig>(AppConfigNotifier.new);

/// The user's cat name (empty = default from the brand pack).
class CatNameNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String name) => state = name;
}

final catNameProvider = NotifierProvider<CatNameNotifier, String>(CatNameNotifier.new);

/// Persian-display `day_start_hour` (0..6).
class DayStartHourNotifier extends Notifier<int> {
  @override
  int build() => 4;
  void set(int h) => state = h;
}

final dayStartHourProvider = NotifierProvider<DayStartHourNotifier, int>(DayStartHourNotifier.new);

final todayProvider = Provider<LocalDay>((ref) => LocalDay.today(ref.watch(clockProvider), dayStartHour: ref.watch(dayStartHourProvider)));

/// `copy.t(key, vars)` — all user-facing text goes through this (docs/40).
final copyProvider = Provider<CopyResolver>((ref) {
  final content = ref.watch(contentRepositoryProvider);
  final brand = content.bundledEntries('brand');
  final dl = content.downloadedEntries('brand');
  return CopyResolver(
    bundled: {...content.bundledEntries('copy_fa')},
    downloaded: {...content.downloadedEntries('copy_fa')},
    appName: (dl['app_name'] ?? brand['app_name'] ?? 'App') as String,
    defaultCatName: (dl['cat_default_name'] ?? brand['cat_default_name'] ?? '') as String,
    catName: ref.watch(catNameProvider),
    today: () => ref.read(todayProvider).value,
  );
});

/// `app_meta.onboarding_completed`; drives the router redirect.
class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final onboardingCompletedProvider = NotifierProvider<OnboardingCompletedNotifier, bool>(OnboardingCompletedNotifier.new);

/// Soft-update banner dismissed today (kept per session in this step).
class SoftUpdateDismissedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void dismiss() => state = true;
}

final softUpdateDismissedProvider = NotifierProvider<SoftUpdateDismissedNotifier, bool>(SoftUpdateDismissedNotifier.new);

/// Premium state. Stub until prompt 14 (signed entitlement); tests and dev can override it.
class PremiumNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final premiumProvider = NotifierProvider<PremiumNotifier, bool>(PremiumNotifier.new);

/// True after a check-in with mood_level <= 2 in this session (paywall suppression, docs/60 §5).
class LowMoodSessionNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void mark() => state = true;
}

final lowMoodSessionProvider = NotifierProvider<LowMoodSessionNotifier, bool>(LowMoodSessionNotifier.new);
