import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/outbox/outbox_worker.dart';
import '../../core/providers.dart';
import '../core_loop_providers.dart';
import 'domain/monetization_service.dart';

/// Trial, purchase and restore flows plus their durable outbox. Needs the bootstrapped entitlement repository.
final monetizationServiceProvider = Provider<MonetizationService>((ref) {
  final repo = ref.watch(entitlementRepositoryProvider);
  if (repo == null) throw StateError('entitlement repository not bootstrapped');
  return MonetizationService(
    repo: repo,
    api: ref.watch(apiClientProvider),
    gateway: ref.watch(paymentGatewayProvider),
    db: ref.watch(databaseProvider),
    wallet: ref.watch(walletServiceProvider),
    analytics: ref.watch(analyticsProvider),
    clock: ref.watch(clockProvider),
    config: () => ref.read(appConfigProvider),
  );
});

final outboxWorkerProvider = Provider<OutboxWorker>((ref) => ref.watch(monetizationServiceProvider).outbox);
