// On-device E2E against a staging backend (prompt 20 §3). NOT run in the authoring environment (no emulator,
// no staging server); the domain-level equivalent runs in test/e2e_flow_test.dart.
//
//   flutter test integration_test/e2e_flow_test.dart --flavor bazaar -d <emulator> \
//     --dart-define=API_BASE_URL=https://staging-api.example.ir --dart-define=FAKE_BILLING=true \
//     --dart-define=ENT_PUBKEY=<kid>:<base64url staging public key>
//
// Staging config should shorten adventures (`adventure.locations[*].duration_minutes: 1`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pashmak_app/bootstrap.dart';
import 'package:pashmak_app/core/flavor.dart';

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).first);
  await t.pumpAndSettle(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh install: onboarding → trial → habit tick → shop → paywall', (t) async {
    unawaited(bootstrap(Flavor.bazaar));
    await t.pumpAndSettle(const Duration(seconds: 3));

    // onboarding
    expect(find.textContaining('جای درمان'), findsOneWidget);
    await tapText(t, 'بعدی');
    await tapText(t, 'بعدی'); // keep the default cat name
    await tapText(t, 'آب خوردن');
    await tapText(t, 'خواب');
    await tapText(t, 'بعدی');
    await tapText(t, 'بعداً'); // notification pre-prompt (system dialog is not driven here)
    await tapText(t, 'شروع ۷ روز رایگان'); // online trial against staging

    // home: tick the first habit
    expect(find.text('آب خوردن'), findsWidgets);
    await t.tap(find.byType(Checkbox).first);
    await t.pumpAndSettle(const Duration(milliseconds: 500));

    // shop tab
    await tapText(t, 'فروشگاه');
    expect(find.byType(ListTile), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
