import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';

/// Kind help page. Always reachable, never gated, no paywall, no reason tracking (docs/80 §5).
/// Hotline numbers are shown only when the pack marks them `verified_at` (open question V9).
class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});
  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  @override
  void initState() {
    super.initState();
    // Only the screen view with its entry point is counted; nothing about why it was shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(analyticsProvider).track(AnalyticsEvent.safetyScreenViewed, {'source': 'settings'}));
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final pack = ref.watch(contentRepositoryProvider).entries('safety');
    final hotlines = pack is Map ? (pack['hotlines'] as List?)?.cast<Map<String, dynamic>>().where((h) => h['verified_at'] != null).toList() ?? const [] : const <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('safety.title'))),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text(copy.t('safety.body'), style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.md),
        Text(copy.t('safety.talk_hint')),
        const SizedBox(height: AppSpacing.lg),
        if (hotlines.isEmpty)
          Text(copy.t('safety.no_hotlines'))
        else
          for (final h in hotlines)
            Card(
              child: ListTile(
                title: Text(copy.t(h['label_key'] as String)),
                subtitle: Text('${toPersianDigits(h['number'])} · ${copy.t(h['hours_key'] as String)}'),
                trailing: const Icon(Icons.call),
                onTap: () => launchUrl(Uri(scheme: 'tel', path: h['number'] as String)),
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        Text(copy.t('disclaimer.not_medical'), style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }
}
