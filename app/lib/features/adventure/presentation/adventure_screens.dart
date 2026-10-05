import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../domain/adventure_service.dart';

/// The automatic adventure: waiting for the energy bar, away (countdown) or back (claim). There is no place picker.
class AdventureScreen extends ConsumerWidget {
  const AdventureScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    ref.watch(tickProvider);
    final adv = ref.watch(currentAdventureProvider).value;
    final now = ref.watch(clockProvider).now();
    final target = ref.watch(appConfigProvider).dailyEnergyTarget;
    final energy = ref.watch(walletProvider).value?.energy ?? 0;
    final Widget body;
    if (adv == null) {
      body = Column(children: [
        Text(copy.t('adventure.screen.idle_title'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(copy.t('adventure.screen.idle_body'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary)),
        const SizedBox(height: 16),
        ProgressPill(value: energy, max: target),
      ]);
    } else if (adv.status == 'returned' || now.millisecondsSinceEpoch >= adv.endsAt) {
      body = Column(children: [
        Text(copy.t('adventure.returned'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ChunkyButton(
          label: copy.t('adventure.claim'),
          onPressed: () async {
            await ref.read(adventureServiceProvider).claim(adv.id);
            if (context.mounted) context.pushReplacement(Routes.adventureResult(adv.id));
          },
        ),
      ]);
    } else {
      final mins = DateTime.fromMillisecondsSinceEpoch(adv.endsAt).difference(now).inMinutes + 1;
      body = Column(children: [
        Text(copy.t('adventure.away', {'place': copy.t('adventure.location.${adv.locationKey}.name')}), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(copy.t('adventure.eta', {'n': mins}), style: const TextStyle(color: DS.textPrimary)),
      ]);
    }
    return Scaffold(
      backgroundColor: DS.cardCat,
      appBar: AppBar(title: Text(copy.t('adventure.title')), backgroundColor: DS.cardCat),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Center(child: CatView()),
        const SizedBox(height: 16),
        RoundCard(child: body),
      ]),
    );
  }
}

/// Story, coins, item, the new discovery and growth of a claimed adventure.
class AdventureResultScreen extends ConsumerWidget {
  const AdventureResultScreen({super.key, required this.adventureId});
  final String adventureId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final db = ref.watch(databaseProvider);
    return FutureBuilder(
      future: Future.wait([(db.select(db.adventures)..where((a) => a.id.equals(adventureId))).getSingleOrNull(), adventureExtras(db, adventureId)]),
      builder: (context, snap) {
        final a = snap.data?[0] as dynamic;
        final extras = snap.data?[1] as ({String? discovery, String? stageUp})?;
        return Scaffold(
          backgroundColor: DS.cardCat,
          appBar: AppBar(title: Text(copy.t('adventure.result.title')), backgroundColor: DS.cardCat),
          body: a == null
              ? const SizedBox.shrink()
              : ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
                  RoundCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (a.storyKey != null) Text(copy.t('adventure.story.${a.locationKey}.${(a.storyKey as String).split('_').last}'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
                      const SizedBox(height: AppSpacing.md),
                      Text(copy.t('adventure.result.coins', {'n': a.rewardCoins}), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary)),
                      if (a.rewardItemKey != null) Text(copy.t('adventure.result.item', {'item': copy.t('shop.item.${a.rewardItemKey}.name')}), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary)),
                      if (extras?.discovery != null) ...[
                        const SizedBox(height: 8),
                        Text(copy.t('adventure.result.discovery', {'item': copy.t('discovery.${extras!.discovery}.name')}), textAlign: TextAlign.center, style: const TextStyle(color: DS.doneText, fontWeight: FontWeight.w700)),
                        TextButton(onPressed: () => context.push(Routes.discoveries), child: Text(copy.t('adventure.result.collection'))),
                      ],
                      if (extras?.stageUp != null) ...[
                        const SizedBox(height: 8),
                        Text(copy.t('adventure.result.stage_up'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                        Text(copy.t('adventure.result.stage.${extras!.stageUp}'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textSecondary)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ChunkyButton(onPressed: () => context.go(Routes.home), label: copy.t('common.done')),
                ]),
        );
      },
    );
  }
}
