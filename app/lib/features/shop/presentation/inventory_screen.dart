import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../core_loop_providers.dart';
import '../domain/shop_service.dart';
import 'shop_screens.dart' show shopItemsOf;
import 'shop_widgets.dart';

/// Blue list page of a shop with a category row (inventory screenshot). [sell]: what you own and can sell (worn
/// items are left out); otherwise the catalog: everything the shop ever sells, owned ones ticked.
class ShopInventoryScreen extends ConsumerStatefulWidget {
  const ShopInventoryScreen({super.key, required this.shop, required this.sell});
  final String shop;
  final bool sell;
  @override
  ConsumerState<ShopInventoryScreen> createState() => _ShopInventoryState();
}

class _ShopInventoryState extends ConsumerState<ShopInventoryScreen> {
  String _cat = 'all';

  Future<void> _sell(ShopItem it) async {
    final copy = ref.read(copyProvider);
    final svc = ref.read(shopServiceProvider);
    final hue = ref.read(itemHuesProvider).value?[it.itemKey] ?? 0;
    final ok = await shopDialog(context,
        title: copy.t('shop.sell.confirm', {'item': copy.t(it.nameKey), 'n': svc.sellValue(it.itemKey)}),
        art: ItemArt(item: it, size: 110, hue: hue),
        yes: copy.t('shop.sell.yes'),
        no: copy.t('shop.confirm.cancel'));
    if (ok != true) return;
    final r = await svc.sell(it.itemKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r == SellStatus.sold ? copy.t('shop.sold', {'n': svc.sellValue(it.itemKey)}) : copy.t('shop.sell_equipped'))));
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final cats = ShopCategory.forShop(widget.shop);
    final cat = cats.firstWhere((c) => c.key == _cat);
    final rows = ref.watch(ownedItemsProvider).value ?? const [];
    final owned = {for (final r in rows) r.itemKey: r};
    final hues = ref.watch(itemHuesProvider).value ?? const {};
    final svc = ref.watch(shopServiceProvider);
    final all = [for (final i in shopItemsOf(ref)) if (i.shop == widget.shop && cat.matches(i)) i];
    final list = widget.sell ? [for (final i in all) if (owned[i.itemKey] case final r? when !r.equipped) i] : [for (final i in all) if (i.seasonalKey == null || owned.containsKey(i.itemKey)) i];

    return Scaffold(
      backgroundColor: DS.inventoryBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              IconButton(
                tooltip: copy.t('common.back'),
                onPressed: () => context.canPop() ? context.pop() : context.go(widget.shop == 'furniture' ? Routes.shopFurniture : Routes.shopOutfit),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DS.onDark, size: 32),
              ),
              const Spacer(),
              const CoinPill(),
            ]),
          ),
          Semantics(
            header: true,
            child: Text(copy.t(widget.sell ? 'shop.inventory.title' : 'shop.catalog.title'),
                style: const TextStyle(color: DS.onDark, fontSize: 28, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback)),
          ),
          const SizedBox(height: 12),
          CategoryRow(categories: cats, selected: _cat, onSelect: (k) => setState(() => _cat = k)),
          const SizedBox(height: 12),
          Expanded(
            child: list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(copy.t(widget.sell ? 'shop.inventory.empty' : 'shop.catalog.empty'), textAlign: TextAlign.center, style: const TextStyle(color: DS.onDark, fontSize: 18, fontWeight: FontWeight.w800)),
                  )
                : GridView.count(
                    crossAxisCount: 3,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.84,
                    children: [
                      for (final it in list)
                        widget.sell
                            ? _SellTile(item: it, hue: hues[it.itemKey] ?? 0, value: svc.sellValue(it.itemKey), label: copy.t(it.nameKey), onTap: () => _sell(it))
                            : ShopItemTile(
                                item: it,
                                color: DS.inventoryChip,
                                label: copy.t(it.nameKey),
                                owned: owned.containsKey(it.itemKey),
                                ownedLabel: copy.t('shop.owned'),
                                hue: hues[it.itemKey] ?? 0,
                                onTap: () => context.push(Routes.shopItem(widget.shop, it.itemKey), extra: [for (final i in list) i.itemKey]),
                              ),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}

class _SellTile extends StatelessWidget {
  const _SellTile({required this.item, required this.hue, required this.value, required this.label, required this.onTap});
  final ShopItem item;
  final int hue, value;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(color: DS.inventoryChip, borderRadius: BorderRadius.circular(28)),
              child: LayoutBuilder(
                builder: (context, c) => Column(children: [
                  const Spacer(flex: 2),
                  ItemArt(item: item, size: c.maxWidth * 0.6, hue: hue),
                  const Spacer(flex: 3),
                  FittedBox(child: PriceTag(coins: value)),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
          ),
        ),
      );
}
