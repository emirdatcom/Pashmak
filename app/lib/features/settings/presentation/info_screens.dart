import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';

/// `/settings/terms`: the plain-language terms of use (linked from the paywall).
class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Scaffold(
      backgroundColor: DS.bgSettings,
      appBar: AppBar(title: Text(copy.t('terms.title')), backgroundColor: DS.bgSettings),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        RoundCard(child: Text(copy.t('terms.body'), style: const TextStyle(color: DS.textPrimary, height: 1.8, fontSize: 15))),
      ]),
    );
  }
}

final _pausedSinceProvider = FutureProvider.autoDispose<int?>((ref) async {
  ref.watch(pausedProvider);
  return int.tryParse(await ref.watch(databaseProvider).setting('paused_since') ?? '');
});

/// `/settings/rest`: what rest mode does, with its switch.
class RestModeScreen extends ConsumerWidget {
  const RestModeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final paused = ref.watch(pausedProvider).value ?? false;
    final since = ref.watch(_pausedSinceProvider).value;
    Widget point(String emoji, String key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            EmojiArt(emoji, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Text(copy.t(key), style: const TextStyle(color: DS.textPrimary, fontSize: 15, height: 1.6))),
          ]),
        );
    return Scaffold(
      backgroundColor: DS.bgSettings,
      appBar: AppBar(title: Text(copy.t('rest.title')), backgroundColor: DS.bgSettings),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Center(child: EmojiArt('calm/zzz', size: 96)),
        const SizedBox(height: 12),
        RoundCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(copy.t('rest.body'), style: const TextStyle(color: DS.textDeep, fontSize: 16, fontWeight: FontWeight.w700, height: 1.6)),
            const SizedBox(height: 8),
            point('ui/flame', 'rest.point.streak'),
            point('tech/bell_off', 'rest.point.notif'),
            point('nav/quests', 'rest.point.quests'),
            point('animals/cat', 'rest.point.cat'),
          ]),
        ),
        const SizedBox(height: 12),
        RoundCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            title: Text(copy.t('rest.toggle'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700)),
            subtitle: paused && since != null
                ? Text(copy.t('rest.since', {'date': JalaliFormatter.date(LocalDay.fromDate(DateTime.fromMillisecondsSinceEpoch(since)))}),
                    style: const TextStyle(color: DS.textSecondary))
                : null,
            value: paused,
            onChanged: (v) => ref.read(pauseServiceProvider).set(v),
          ),
        ),
      ]),
    );
  }
}
