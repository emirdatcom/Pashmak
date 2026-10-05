import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flavor.dart';
import '../../core/network/api_error.dart';
import '../../core/providers.dart';
import '../monetization/monetization_providers.dart';
import 'data/support_api.dart';
import 'data/support_repository.dart';
import 'data/support_socket.dart';
import 'domain/support_models.dart';
import 'domain/support_poll.dart';

final supportApiProvider = Provider<SupportApi>((ref) => SupportApi(ref.watch(apiClientProvider)));

/// os/model info for the optional "send technical info" consent (read only when ticked).
Future<Map<String, String>> readDeviceHeaders({required String market, required String appVersion, required bool premium}) async {
  String os = '', model = '';
  try {
    final m = await const MethodChannel('app/device').invokeMapMethod<String, String>('deviceInfo');
    os = m?['os_version'] ?? '';
    model = m?['model'] ?? '';
  } on MissingPluginException {
    // not Android (tests)
  }
  return {'X-OS-Version': os, 'X-Device-Model': model, 'X-Is-Premium': '$premium'};
}

final Provider<SupportRepository> supportRepositoryProvider = Provider<SupportRepository>((ref) => SupportRepository(
      ref.watch(databaseProvider),
      ref.watch(supportApiProvider),
      ref.watch(clockProvider),
      ref.watch(analyticsProvider),
      // lazily: the outbox worker belongs to the monetization service, which in turn runs our handlers
      enqueue: (kind, payload) async {
        await ref.read(monetizationServiceProvider).outbox.enqueue(kind, payload);
      },
      deviceHeaders: () => readDeviceHeaders(market: ref.read(flavorProvider).wireName, appVersion: ref.read(appVersionProvider), premium: ref.read(premiumProvider)),
    ));

final supportMessagesProvider = StreamProvider.autoDispose((ref) => ref.watch(supportRepositoryProvider).watchMessages());

/// Operator replies the user has not seen yet (badge on the settings entry).
final supportUnreadCountProvider = StreamProvider<int>((ref) => ref
    .watch(supportRepositoryProvider)
    .watchMessages()
    .map((rows) => rows.where((m) => m.sender != 'user' && m.status == 'sent').length));

/// Conversation summary (hours banner, operator name). Fails softly (offline → null).
final supportInfoProvider = FutureProvider.autoDispose<SupportInfo?>((ref) async {
  try {
    return await ref.watch(supportApiProvider).conversation();
  } on ApiError {
    return null;
  }
});

/// Whether chat entries are shown at all (remote kill switch `support.enabled`).
final supportEnabledProvider = Provider<bool>((ref) => ref.watch(appConfigProvider).supportEnabled);

final supportPollScheduleProvider = Provider<SupportPollSchedule>((ref) {
  final c = ref.watch(appConfigProvider);
  return SupportPollSchedule(
    firstInterval: Duration(minutes: c.supportPollFirstMinutes),
    firstWindow: Duration(hours: c.supportPollFirstWindowHours),
    secondInterval: Duration(hours: c.supportPollSecondHours),
    stopAfter: Duration(days: c.supportPollStopDays),
  );
});

/// WebSocket URL derived from the API base (`https://…` → `wss://…`).
Uri supportSocketUri() {
  final base = Uri.parse(apiBaseUrl);
  return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '/v1/support/ws', query: '');
}

typedef SupportSocketFactory = SupportSocket Function(Future<void> Function() onPoll);

/// Builds the chat's WebSocket (tests replace it with a socket that never connects).
final Provider<SupportSocketFactory> supportSocketFactoryProvider = Provider<SupportSocketFactory>((ref) => (onPoll) => SupportSocket(
      baseUri: supportSocketUri(),
      tokenProvider: () => ref.read(apiClientProvider).accessToken(),
      onPoll: onPoll,
    ));
