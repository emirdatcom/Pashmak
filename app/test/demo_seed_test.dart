import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/config/config_repository.dart';
import 'package:pashmak_app/core/content/content_repository.dart';
import 'package:pashmak_app/core/demo/demo_seed.dart';
import 'package:pashmak_app/core/providers.dart';
import 'package:pashmak_app/features/core_loop_providers.dart';

import 'helpers.dart';

void main() {
  test('the demo seed never runs in a release build', () {
    expect(demoSeedActive(flag: true, release: true), isFalse);
    expect(demoSeedActive(flag: true, release: false), isTrue);
    expect(demoSeedActive(flag: false, release: false), isFalse);
    expect(kDemoSeedFlag, isFalse, reason: 'default builds and tests are not seeded');
  });

  test('applyDemoSeed fills the reference state once (302 coins, 3 of 4 goals done, quests, adventure, discoveries)', () async {
    final h = ApiHarness(DateTime(2026, 10, 5, 9));
    final content = ContentRepository(h.db, realAssets(), h.api, appVersion: '1.0.0');
    final config = ConfigRepository(h.db, realAssets(), h.api, h.clock);
    await content.load();
    await config.load();
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(h.db),
      apiClientProvider.overrideWithValue(h.api),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      contentRepositoryProvider.overrideWithValue(content),
      configRepositoryProvider.overrideWithValue(config),
      clockProvider.overrideWithValue(h.clock),
      appVersionProvider.overrideWithValue('1.0.0'),
      analyticsProvider.overrideWithValue(const NoopAnalytics()),
    ]);
    addTearDown(c.dispose);
    await applyDemoSeed(c);
    await applyDemoSeed(c);
    expect((await c.read(walletServiceProvider).balance()).coins, 302);
    expect((await c.read(habitServiceProvider).activeHabits()).length, 4);
    expect((await c.read(adventureServiceProvider).current())?.status, 'returned');
    final q = await c.read(questServiceProvider).daily();
    expect(q.where((x) => x.state.name == 'claimed').length, q.length - 1);
    expect((await h.db.select(h.db.discoveriesFound).get()).length, 6);
  });
}
