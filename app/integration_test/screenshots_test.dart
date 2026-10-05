// Device screenshots of the main screens for the owner's review (prompt 23 §7). NOT run in the authoring
// environment (no emulator); `docs/device-review-checklist.md` explains how to run it.
//
//   flutter test integration_test/screenshots_test.dart --flavor bazaar -d <device> --dart-define=DEMO_SEED=true
//
// The shots are written by the integration_test driver (`takeScreenshot`); the host-side driver saves them to
// docs/visual-diff/device/.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pashmak_app/bootstrap.dart';
import 'package:pashmak_app/core/demo/demo_seed.dart';
import 'package:pashmak_app/core/flavor.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo-seeded app: tab screens', (t) async {
    expect(demoSeedActive(), isTrue, reason: 'run with --dart-define=DEMO_SEED=true in a debug/profile build');
    unawaited(bootstrap(Flavor.bazaar));
    await t.pumpAndSettle(const Duration(seconds: 3));
    await binding.convertFlutterSurfaceToImage();
    await t.pumpAndSettle();
    await binding.takeScreenshot('02-home');
    // Tab labels come from copy_fa (nav.*); tap by position of the bottom bar entries (RTL: home is rightmost).
    final labels = ['مأموریت‌ها', 'فروشگاه', 'کیف', 'ملوس'];
    final names = ['01-quests', '05-shop', '06-bag', '10-cat'];
    for (var i = 0; i < labels.length; i++) {
      await t.tap(find.text(labels[i]).last);
      await t.pumpAndSettle(const Duration(seconds: 1));
      await binding.takeScreenshot(names[i]);
    }
  });
}
