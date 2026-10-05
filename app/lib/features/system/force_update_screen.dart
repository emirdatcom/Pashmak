import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics/analytics_event.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';

/// Hard update (`/update`, not dismissible) and soft update banner (dismissible once per session).
class ForceUpdateScreen extends ConsumerStatefulWidget {
  const ForceUpdateScreen({super.key});
  @override
  ConsumerState<ForceUpdateScreen> createState() => _ForceUpdateState();
}

class _ForceUpdateState extends ConsumerState<ForceUpdateScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.forceUpdateShown, {'kind': 'hard'}));
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(copy.t('update.hard'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: () => openStore(ref), child: Text(copy.t('update.action'))),
          ]),
        ),
      ),
    );
  }
}

Future<void> openStore(WidgetRef ref) async {
  final flavor = ref.read(flavorProvider);
  final id = ref.read(applicationIdProvider);
  if (!await launchUrl(flavor.storeUri(id))) {
    await launchUrl(flavor.storeWebUri(id), mode: LaunchMode.externalApplication);
  }
}

/// Dismissible bar shown when `update.recommended_version` is newer than the app.
class SoftUpdateBanner extends ConsumerStatefulWidget {
  const SoftUpdateBanner({super.key});
  @override
  ConsumerState<SoftUpdateBanner> createState() => _SoftUpdateState();
}

class _SoftUpdateState extends ConsumerState<SoftUpdateBanner> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.forceUpdateShown, {'kind': 'soft'}));
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    return MaterialBanner(
      content: Text(copy.t('update.soft')),
      actions: [
        TextButton(onPressed: () => openStore(ref), child: Text(copy.t('update.action'))),
        IconButton(
          tooltip: copy.t('common.close'),
          icon: const Icon(Icons.close),
          onPressed: () => ref.read(softUpdateDismissedProvider.notifier).dismiss(),
        ),
      ],
    );
  }
}
