import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pashmak_app/core/auth/device_identity.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/config/asset_source.dart';
import 'package:pashmak_app/core/db/app_database.dart';
import 'package:pashmak_app/core/network/api_client.dart';
import 'package:pashmak_app/core/time/clock.dart';

AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Real bundled assets (assets/config + assets/content) read from disk.
MapAssetSource realAssets() {
  final files = <String, String>{};
  for (final dir in ['assets/config', 'assets/content']) {
    for (final f in Directory(dir).listSync().whereType<File>()) {
      files['$dir/${f.uri.pathSegments.last}'] = f.readAsStringSync();
    }
  }
  return MapAssetSource(files);
}

class ApiHarness {
  ApiHarness(DateTime now)
      : clock = FakeClock(now),
        db = memoryDb(),
        tokens = TokenStore(MemorySecretStore()) {
    api = ApiClient(
      baseUrl: 'https://api.test',
      info: const ClientInfo(appVersion: '1.0.0', market: 'bazaar'),
      identity: DeviceIdentity(db, const FixedDeviceIdSource('android-id')),
      tokens: tokens,
      clock: clock,
    );
    mock = DioAdapter(dio: api.dio);
  }
  final FakeClock clock;
  final AppDatabase db;
  final TokenStore tokens;
  late final ApiClient api;
  late final DioAdapter mock;
}
