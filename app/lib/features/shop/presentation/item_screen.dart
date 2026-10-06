import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/cat_renderer.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../domain/shop_service.dart';
import 'shop_screens.dart' show shopItemsOf;
import 'shop_widgets.dart';

/// One item up close (item preview screenshot): the cat wearing it (or the furniture piece large), its name and
/// collection, colour dots, the price button, and a strip of the neighbouring items to flip through.
class ShopItemScreen extends ConsumerStatefulWidget {
  const ShopItemScreen({super.key, required this.shop, required this.itemKey, this.keys});
  final String shop;
  final String itemKey;

  /// The list the item was opened from (the strip at the bottom). Defaults to everything in the shop.
  final List<String>? keys;

  @override
  ConsumerState<ShopItemScreen> createState() => _ShopItemScreenState();
}

class _ShopItemScreenState extends ConsumerState<ShopItemScreen> {
  late String _key = widget.itemKey;
  int _hue = 0;
  bool _busy = false;

  ShopItem? _item(List<ShopItem> all) => all.where((i) => i.itemKey == _key).firstOrNull;

  Future<void> _buy(ShopItem it) async {
    if (_busy) return;
    final copy = ref.read(copyProvider);
    final premium = ref.read(premiumProvider);
    if (it.premiumOnly && !premium) {
      await passGate(context, ref, 'premium_item');
      return;
    }
    final coins = (await ref.read(walletServiceProvider).balance()).coins;
    if (!mounted) return;
    if (coins < it.priceCoins) {
      final go = await shopDialog(context,
          title: copy.t('shop.poor.title'), body: copy.t('shop.poor.body'), art: const EmojiArt('ui/coin', size: 72), yes: copy.t('shop.poor.go'), no: copy.t('shop.bought.later'));
      if (go == true && mounted) context.go(Routes.quests);
      return;
    }
    final sure = await shopDialog(context,
        title: copy.t('shop.confirm.title', {'item': copy.t(it.nameKey)}),
        art: ItemArt(item: it, size: 110, hue: _hue),
        extra: PriceTag(coins: it.priceCoins, color: DS.textDeep, size: 22),
        yes: copy.t('shop.confirm.buy'),
        no: copy.t('shop.confirm.cancel'));
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    final svc = ref.read(shopServiceProvider);
    final r = await svc.buy(it.itemKey, isPremium: premium);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == BuyStatus.outOfSeason || r == BuyStatus.notEnoughCoins) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t(r == BuyStatus.outOfSeason ? 'shop.out_of_season' : 'shop.not_enough_coins'))));
      return;
    }
    if (r != BuyStatus.bought) return;
    // The colour previewed is the colour bought.
    if (_hue != 0) await ref.read(databaseProvider).setMeta('item_hue:${it.itemKey}', '$_hue');
    if (!mounted) return;
    final outfit = it.shop == 'outfit';
    final wear = await shopDialog(context,
        title: copy.t('shop.bought.title'),
        art: ItemArt(item: it, size: 120, hue: _hue),
        yes: copy.t(outfit ? 'shop.bought.wear' : 'shop.bought.place'),
        no: copy.t('shop.bought.later'));
    if (wear == true) await svc.toggleEquip(it.itemKey, isPremium: premium);
  }

  Future<void> _toggle(ShopItem it) async {
    if (_hue != (ref.read(itemHuesProvider).value?[it.itemKey] ?? 0)) await ref.read(databaseProvider).setMeta('item_hue:${it.itemKey}', '$_hue');
    await ref.read(shopServiceProvider).toggleEquip(it.itemKey, isPremium: ref.read(premiumProvider));
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final all = shopItemsOf(ref);
    final it = _item(all);
    final ownedRows = ref.watch(ownedItemsProvider).value ?? const [];
    final owned = {for (final i in ownedRows) i.itemKey: i};
    final keys = widget.keys ?? [for (final i in all) if (i.shop == widget.shop && i.seasonalKey == null) i.itemKey];
    final strip = [for (final k in keys) ?all.where((i) => i.itemKey == k).firstOrNull];
    if (it == null) return const Scaffold(backgroundColor: DS.shopPreviewBg);
    final mine = owned[it.itemKey];
    final outfit = it.shop == 'outfit';
    final collection = it.seasonalKey != null ? copy.t('seasonal.${it.seasonalKey}.name') : (it.collection == null ? null : copy.t('shop.collection.${it.collection}'));

    // Preview: the cat as it is now, with this item put on (replacing whatever sits in the same slot).
    final cat = ref.watch(catStateProvider);
    final clash = switch (it.slot) { 'onesie' => const ['onesie', 'top', 'bottom'], 'top' || 'bottom' => [it.slot, 'onesie'], _ => [it.slot] };
    final preview = cat.copyWith(worn: [
      for (final w in cat.worn) if (!clash.contains(w.slot)) w,
      WornItem(asset: it.asset, slot: it.slot, hue: _hue),
    ]);

    return Scaffold(
      backgroundColor: DS.shopPreviewBg,
      body: Column(children: [
        SafeArea(
          bottom: false,
          child: Padding(
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
        ),
        Expanded(
          child: Center(
            child: outfit
                ? SizedBox(height: 260, child: FittedBox(child: ExcludeSemantics(child: ref.watch(catRendererProvider).build(context, preview))))
                : ItemArt(item: it, size: 220, hue: _hue),
          ),
        ),
        Semantics(header: true, child: Text(copy.t(it.nameKey), textAlign: TextAlign.center, style: const TextStyle(color: DS.onDark, fontSize: 24, fontWeight: FontWeight.w800))),
        if (collection != null) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            EmojiArt(it.seasonalKey != null ? 'nature/pomegranate' : 'misc/map', size: 40),
            const SizedBox(width: 10),
            Text(collection, style: const TextStyle(color: DS.onDark, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ]),
        ],
        if (it.hues.length > 1) ...[
          const SizedBox(height: 12),
          _HueDots(hues: it.hues, selected: _hue, onPick: (h) => setState(() => _hue = h), label: copy.t('shop.colors', {'n': it.hues.length})),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: 240,
          child: mine == null
              ? _PriceButton(key: const ValueKey('buy'), item: it, busy: _busy, onTap: () => _buy(it))
              : ChunkyButton(
                  label: mine.equipped ? copy.t(outfit ? 'shop.wearing' : 'shop.placed') : copy.t(outfit ? 'shop.wear' : 'shop.place'),
                  color: mine.equipped ? DS.primaryGreen : DS.card,
                  edgeColor: mine.equipped ? DS.primaryGreenEdge : DS.neutralButtonEdge,
                  textColor: DS.textDeep,
                  onPressed: () => _toggle(it),
                ),
        ),
        const SizedBox(height: 20),
        Container(
          color: DS.shopPreviewStrip,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(14),
                itemCount: strip.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(
                  width: 112,
                  child: ShopItemTile(
                    item: strip[i],
                    color: ShopTheme.of(widget.shop).tile,
                    label: copy.t(strip[i].nameKey),
                    owned: owned.containsKey(strip[i].itemKey),
                    ownedLabel: copy.t('shop.owned'),
                    selected: strip[i].itemKey == _key,
                    onTap: () => setState(() {
                      _key = strip[i].itemKey;
                      _hue = 0;
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// White 3D button with the coin and the price.
class _PriceButton extends StatelessWidget {
  const _PriceButton({super.key, required this.item, required this.busy, required this.onTap});
  final ShopItem item;
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: GestureDetector(
          onTap: busy ? null : onTap,
          child: Container(
            height: 64,
            decoration: BoxDecoration(color: DS.card, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: DS.neutralButtonEdge, offset: Offset(0, 5))]),
            alignment: Alignment.center,
            child: PriceTag(coins: item.priceCoins, color: DS.textDeep, size: 24),
          ),
        ),
      );
}

/// Colour variants as dots; the base colour first.
class _HueDots extends StatelessWidget {
  const _HueDots({required this.hues, required this.selected, required this.onPick, required this.label});
  final List<int> hues;
  final int selected;
  final ValueChanged<int> onPick;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final h in hues)
            GestureDetector(
              onTap: () => onPick(h),
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: DS.onDark, width: h == selected ? 4 : 2),
                ),
                child: HueShift(degrees: h, child: const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: DS.areaMovement))),
              ),
            ),
        ]),
      );
}
