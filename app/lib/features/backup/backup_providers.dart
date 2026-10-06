import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../account/phone_link_service.dart';
import 'data/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) => BackupService(
      db: ref.watch(databaseProvider),
      api: ref.watch(apiClientProvider),
      clock: ref.watch(clockProvider),
      secrets: ref.watch(secretStoreProvider),
      analytics: ref.watch(analyticsProvider),
    ));

final phoneLinkServiceProvider = Provider<PhoneLinkService>(
    (ref) => PhoneLinkService(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider), ref.watch(analyticsProvider),
        // After a merge this device belongs to the other account: an automatic backup now would overwrite that
        // account's backup with this device's data before the user had a chance to restore it.
        onMerged: () => ref.read(backupServiceProvider).disable()));
