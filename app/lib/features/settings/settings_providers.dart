import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../core_loop_providers.dart';
import '../onboarding/domain/onboarding_service.dart';
import '../stats/domain/stats_service.dart';
import 'domain/data_service.dart';

final dataServiceProvider = Provider<DataService>((ref) =>
    DataService(ref.watch(databaseProvider), ref.watch(apiClientProvider), ref.watch(tokenStoreProvider), ref.watch(clockProvider)));

final statsServiceProvider = Provider<StatsService>((ref) => StatsService(ref.watch(databaseProvider), ref.watch(streakServiceProvider)));

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  final brand = ref.watch(contentRepositoryProvider).bundledEntries('brand');
  return OnboardingService(ref.watch(databaseProvider), ref.watch(habitServiceProvider), ref.watch(analyticsProvider), ref.watch(clockProvider),
      defaultCatName: (brand['cat_default_name'] as String?) ?? '');
});

/// Words refused as a cat name (`brand.name_blocklist`, downloaded pack wins).
final nameBlocklistProvider = Provider<List<String>>((ref) {
  final content = ref.watch(contentRepositoryProvider);
  final list = (content.downloadedEntries('brand')['name_blocklist'] ?? content.bundledEntries('brand')['name_blocklist']) as List?;
  return list?.cast<String>() ?? const [];
});

final weekStatsProvider = FutureProvider.autoDispose<WeekStats>((ref) {
  ref.watch(todayHabitsProvider); // re-read when habit logs change
  ref.watch(streakProvider);
  return ref.watch(statsServiceProvider).week(ref.watch(todayProvider));
});
