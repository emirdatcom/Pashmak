import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../../shop/domain/shop_service.dart';
import '../../shop/presentation/shop_screens.dart' show ItemArt, shopItemsOf;

/// Bag tab: owned outfits and furniture (wear / place them), and locked cards for the phase-2 sections.
class BagScreen extends ConsumerWidget {
  const BagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final svc = ref.watch(shopServiceProvider);
    final owned = ref.watch(ownedItemsProvider).value ?? const [];
    final items = {for (final i in shopItemsOf(ref)) i.itemKey: i};
    final outfits = [for (final o in owned) if (items[o.itemKey]?.shop == 'outfit') o];
    final furniture = [for (final o in owned) if (items[o.itemKey]?.shop == 'furniture') o];
    final bg = owned.where((o) => o.slot == 'background' && o.equipped).firstOrNull;
    final place = bg == null ? copy.t('adventure.location.courtyard.name') : copy.t(items[bg.itemKey]?.nameKey ?? 'shop.title');

    Widget section(String titleKey, List<dynamic> list, {required bool outfit}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RoundCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(copy.t(titleKey), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
              if (list.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(copy.t('bag.empty'), style: const TextStyle(color: DS.textSecondary))),
              for (final o in list)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    ItemArt(item: items[o.itemKey]!, size: 44),
                    const SizedBox(width: 10),
                    Expanded(child: Text(copy.t(items[o.itemKey]!.nameKey), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w600))),
                    SizedBox(
                      width: 104,
                      child: ChunkyButton(
                        height: 40,
                        label: copy.t(o.equipped as bool ? (outfit ? 'bag.take_off' : 'bag.remove') : (outfit ? 'bag.wear' : 'bag.place')),
                        color: (o.equipped as bool) ? DS.neutralButton : DS.primaryGreen,
                        edgeColor: (o.equipped as bool) ? DS.neutralButtonEdge : DS.primaryGreenEdge,
                        textColor: (o.equipped as bool) ? DS.textPrimary : DS.onDark,
                        onPressed: () async {
                          final r = await svc.toggleEquip(o.itemKey as String, isPremium: ref.read(premiumProvider));
                          if (r == EquipStatus.premiumLocked && context.mounted) await passGate(context, ref, 'premium_item');
                        },
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        );

    Widget locked(String titleKey) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RoundCard(
            color: DS.neutralButton,
            semanticLabel: '${copy.t(titleKey)} ${copy.t('bag.locked')}',
            child: Row(children: [
              const Icon(Icons.help_outline, color: DS.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(copy.t(titleKey), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700))),
              Text(copy.t('bag.locked'), style: const TextStyle(color: DS.textSecondary)),
              const SizedBox(width: 6),
              const Icon(Icons.lock, size: 18, color: DS.textSecondary),
            ]),
          ),
        );

    return Scaffold(
      backgroundColor: DS.bgBag,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Text(copy.t('bag.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Center(child: SizedBox(height: 200, child: CatView())),
          const SizedBox(height: 8),
          locked('bag.letters'),
          section('bag.outfits', outfits, outfit: true),
          section('bag.furniture', furniture, outfit: false),
          locked('bag.colors'),
          locked('bag.companions'),
          Center(child: Text(copy.t('bag.location', {'place': place}), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}
