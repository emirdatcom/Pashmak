import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../../shop/presentation/shop_screens.dart' show shopItemsOf;

/// Bag tab: owned outfits and furniture (open the closet to wear / place them), and locked cards for the phase-2 sections.
class BagScreen extends ConsumerWidget {
  const BagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final owned = ref.watch(ownedItemsProvider).value ?? const [];
    final items = {for (final i in shopItemsOf(ref)) i.itemKey: i};
    final outfits = [for (final o in owned) if (items[o.itemKey]?.shop == 'outfit') o];
    final furniture = [for (final o in owned) if (items[o.itemKey]?.shop == 'furniture') o];
    final bg = owned.where((o) => o.slot == 'background' && o.equipped).firstOrNull;
    final place = bg == null ? copy.t('adventure.location.courtyard.name') : copy.t(items[bg.itemKey]?.nameKey ?? 'shop.title');

    Widget tile(String titleKey, IconData icon, {String? subtitle, VoidCallback? onTap, bool lockedTile = false, bool wide = false}) => RoundCard(
          color: lockedTile ? DS.bgBagLocked : DS.card,
          onTap: lockedTile ? null : onTap,
          semanticLabel: lockedTile ? '${copy.t(titleKey)} ${copy.t('bag.locked')}' : copy.t(titleKey),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: wide ? 72 : 96),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(lockedTile ? Icons.help_outline_rounded : icon, size: 36, color: lockedTile ? DS.textDeep : DS.areaMovement),
              const SizedBox(height: 4),
              Text(copy.t(titleKey), style: TextStyle(color: lockedTile ? DS.textDeep : DS.textPrimary, fontWeight: FontWeight.w800)),
              if (subtitle != null) Text(subtitle, style: const TextStyle(color: DS.textSecondary, fontSize: 12)),
            ]),
          ),
        );

    return Scaffold(
      backgroundColor: DS.bgBagScene,
      body: Column(children: [
        // dark scene with the cat, like the reference's bag header
        Expanded(
          flex: 38,
          child: SafeArea(
            bottom: false,
            child: Align(alignment: const Alignment(0, 0.4), child: SizedBox(height: 160, child: FittedBox(child: Semantics(header: true, label: copy.t('bag.title'), child: const CatView())))),
          ),
        ),
        Expanded(
          flex: 62,
          child: Container(
            decoration: const BoxDecoration(color: DS.bgBag, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 24), children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: DS.progressYellow, borderRadius: BorderRadius.circular(6)),
                  child: Text(copy.t('bag.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback)),
                ),
              ),
              const SizedBox(height: 16),
              tile('bag.letters', Icons.mail_rounded, lockedTile: true, wide: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: tile('bag.outfits', Icons.checkroom_rounded, subtitle: outfits.isEmpty ? copy.t('bag.empty') : null, onTap: () => context.push(Routes.closetOf('outfit')))),
                const SizedBox(width: 10),
                Expanded(child: tile('bag.furniture', Icons.chair_rounded, subtitle: furniture.isEmpty ? copy.t('bag.empty') : null, onTap: () => context.push(Routes.closetOf('furniture')))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: tile('bag.colors', Icons.palette_rounded, lockedTile: true)),
                const SizedBox(width: 10),
                Expanded(child: tile('bag.companions', Icons.pets_rounded, lockedTile: true)),
              ]),
              const SizedBox(height: 16),
              Center(child: Text(copy.t('bag.location', {'place': place}), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ]),
    );
  }
}
