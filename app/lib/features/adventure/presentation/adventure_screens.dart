import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../../wallet/presentation/wallet_bar.dart';
import '../domain/adventure_service.dart';

/// One screen, three states: pick a place, in progress (countdown), returned (claim).
class AdventureScreen extends ConsumerWidget {
  const AdventureScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    ref.watch(tickProvider);
    final adv = ref.watch(currentAdventureProvider).value;
    final now = ref.watch(clockProvider).now();
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('adventure.title'))),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        const Center(child: CatView()),
        const SizedBox(height: AppSpacing.md),
        const WalletBar(),
        const SizedBox(height: AppSpacing.md),
        if (adv == null) ..._picker(context, ref) else if (adv.status == 'returned' || now.millisecondsSinceEpoch >= adv.endsAt) ..._returned(context, ref, adv.id) else ..._active(context, ref, adv.locationKey, adv.endsAt, now),
      ]),
    );
  }

  List<Widget> _picker(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final svc = ref.watch(adventureServiceProvider);
    return [
      Text(copy.t('adventure.pick'), style: Theme.of(context).textTheme.titleMedium),
      for (final o in svc.options())
        Card(
          child: ListTile(
            title: Text(copy.t(o.nameKey)),
            subtitle: Text('${copy.t('adventure.cost', {'n': o.config.energyCost})} · ${copy.t('adventure.duration', {'n': o.config.durationMinutes})}'),
            trailing: o.premium && !ref.watch(premiumProvider) ? Chip(label: Text(copy.t('shop.premium_only'))) : const Icon(Icons.chevron_left),
            onTap: () async {
              if (o.premium && !ref.read(premiumProvider)) {
                await passGate(context, ref, 'premium_location');
                return;
              }
              final r = await svc.start(o.locationKey, isPremium: ref.read(premiumProvider));
              if (!context.mounted) return;
              if (r.status == StartStatus.notEnoughEnergy) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('adventure.not_enough_energy'))));
              }
            },
          ),
        ),
    ];
  }

  List<Widget> _active(BuildContext context, WidgetRef ref, String location, int endsAt, DateTime now) {
    final copy = ref.watch(copyProvider);
    final mins = DateTime.fromMillisecondsSinceEpoch(endsAt).difference(now).inMinutes + 1;
    return [
      Text(copy.t('adventure.away', {'place': copy.t('adventure.location.$location.name')}), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      Text(copy.t('adventure.eta', {'n': mins}), textAlign: TextAlign.center),
    ];
  }

  List<Widget> _returned(BuildContext context, WidgetRef ref, String id) {
    final copy = ref.watch(copyProvider);
    return [
      Text(copy.t('adventure.returned'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        onPressed: () async {
          await ref.read(adventureServiceProvider).claim(id);
          if (context.mounted) context.pushReplacement(Routes.adventureResult(id));
        },
        child: Text(copy.t('adventure.claim')),
      ),
    ];
  }
}

/// Story, coins and item of a claimed adventure.
class AdventureResultScreen extends ConsumerWidget {
  const AdventureResultScreen({super.key, required this.adventureId});
  final String adventureId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final db = ref.watch(databaseProvider);
    return FutureBuilder(
      future: (db.select(db.adventures)..where((a) => a.id.equals(adventureId))).getSingleOrNull(),
      builder: (context, snap) {
        final a = snap.data;
        return Scaffold(
          appBar: AppBar(title: Text(copy.t('adventure.result.title'))),
          body: a == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (a.storyKey != null) Text(copy.t('adventure.story.${a.locationKey}.${a.storyKey!.split('_').last}'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    Text(copy.t('adventure.result.coins', {'n': a.rewardCoins}), textAlign: TextAlign.center),
                    if (a.rewardItemKey != null) Text(copy.t('adventure.result.item', {'item': copy.t('shop.item.${a.rewardItemKey}.name')}), textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(onPressed: () => context.go(Routes.home), child: Text(copy.t('common.done'))),
                  ]),
                ),
        );
      },
    );
  }
}

