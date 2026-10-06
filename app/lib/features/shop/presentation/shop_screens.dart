import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../domain/shop_service.dart';
import 'shop_widgets.dart';

export 'shop_widgets.dart' show ItemArt;

List<ShopItem> shopItemsOf(WidgetRef ref) => shopCatalog(ref.watch(contentRepositoryProvider), ref.watch(seasonalCatalogProvider));

const _headline = TextStyle(fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback);

/// "Shops" hub: a dusky scene with the cat, then a slate panel with the shop sign and the two shops as white cards.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    unawaited(ref.read(questServiceProvider).recordVisit('shop'));
    return Scaffold(
      backgroundColor: DS.shopHubPanel,
      body: Column(children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/art/background/shop_hub.webp',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => Image.asset('assets/art/background/home_forest.webp', fit: BoxFit.cover, excludeFromSemantics: true, errorBuilder: (_, _, _) => const SizedBox())),
            const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: DS.closetDim))),
            SafeArea(
              bottom: false,
              child: Stack(children: [
                const PositionedDirectional(top: 8, start: 12, child: CoinPill()),
                Align(
                  alignment: const Alignment(0, 0.35),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(height: 130, child: FittedBox(child: CatView())),
                    Text(ref.watch(catNameProvider), style: const TextStyle(color: DS.onDark, fontSize: 18, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        Container(
          decoration: const BoxDecoration(color: DS.shopHubPanel, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Transform.translate(offset: const Offset(0, -46), child: const EmojiArt('nav/shop', size: 110)),
            Transform.translate(offset: const Offset(0, -40), child: _Sign(copy.t('shop.shops.title'))),
            Row(children: [
              for (final (i, s) in const [('outfit', 'nav/outfit', 'clothing/tshirt', Routes.shopOutfit), ('furniture', 'nav/furniture', 'home/lamp', Routes.shopFurniture)].indexed) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: _ShopCard(label: copy.t('shop.shop.${s.$1}'), sticker: s.$2, fallback: s.$3, onTap: () => context.push(s.$4))),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Yellow wooden sign with four nails.
class _Sign extends StatelessWidget {
  const _Sign(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Container(
          width: 210,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: DS.shopSign, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: DS.shadow, offset: Offset(0, 3))]),
          child: Stack(alignment: Alignment.center, children: [
            Text(text, style: _headline.copyWith(color: DS.shopSignText, fontSize: 22, fontWeight: FontWeight.w800)),
            for (final a in const [Alignment(-0.92, -0.9), Alignment(0.92, -0.9), Alignment(-0.92, 0.9), Alignment(0.92, 0.9)])
              Align(alignment: a, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: DS.shopSignNail, shape: BoxShape.circle))),
          ]),
        ),
      );
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.label, required this.sticker, required this.fallback, required this.onTap});
  final String label, sticker, fallback;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: DS.card, borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: DS.shadow, offset: Offset(0, 4))]),
              child: Column(children: [
                EmojiArt(sticker, size: 64, fallback: fallback),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(color: DS.textDeep, fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      );
}

/// Black header of a shop: close, wallet, catalog and sell.
class _ShopTopBar extends ConsumerWidget {
  const _ShopTopBar({required this.shop});
  final String shop;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    Widget action(String sticker, String fallback, String label, String route) => Semantics(
          button: true,
          label: label,
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: () => context.push(route),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  EmojiArt(sticker, size: 42, fallback: fallback),
                  Text(label, style: const TextStyle(color: DS.onDark, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        );
    return ColoredBox(
      color: DS.shopTopBar,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            Semantics(
              button: true,
              label: copy.t('shop.close'),
              child: GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go(Routes.shop),
                child: Container(width: 48, height: 48, decoration: const BoxDecoration(color: DS.shopCloseButton, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: DS.onDark, size: 30)),
              ),
            ),
            const SizedBox(width: 10),
            const CoinPill(),
            const Spacer(),
            action('misc/catalog', 'misc/book', copy.t('shop.catalog'), Routes.shopCatalog(shop)),
            action('misc/sell_bag', 'misc/bag', copy.t('shop.sell'), Routes.shopSell(shop)),
          ]),
        ),
      ),
    );
  }
}

/// One shop (outfit | furniture): keeper scene with the premium card, today's rotating stock with a live countdown
/// and refresh, the seasonal items, then the everyday collection. Tabs at the bottom switch shops.
class ShopDetailScreen extends ConsumerStatefulWidget {
  const ShopDetailScreen({super.key, required this.shop});
  final String shop; // outfit | furniture
  @override
  ConsumerState<ShopDetailScreen> createState() => _ShopDetailState();
}

class _ShopDetailState extends ConsumerState<ShopDetailScreen> {
  List<ShopItem> _stock = const [];
  String? _stockDay;
  Timer? _second;

  @override
  void initState() {
    super.initState();
    // The refresh countdown shows seconds.
    _second = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _second?.cancel();
    super.dispose();
  }

  Future<void> _loadStock() async {
    final s = await ref.read(shopServiceProvider).stock(widget.shop);
    if (mounted) setState(() => _stock = s);
  }

  void _open(ShopItem it, List<ShopItem> list) => context.push(Routes.shopItem(widget.shop, it.itemKey), extra: [for (final i in list) i.itemKey]);

  Future<void> _refresh() async {
    final copy = ref.read(copyProvider);
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref.read(shopServiceProvider).refresh(widget.shop);
    if (!mounted) return;
    if (r == RefreshStatus.refreshed) {
      await _loadStock();
      messenger.showSnackBar(SnackBar(content: Text(copy.t('shop.refreshed'))));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(copy.t('shop.not_enough_coins'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final theme = ShopTheme.of(widget.shop);
    final today = ref.watch(todayProvider);
    if (_stockDay != today.value) {
      _stockDay = today.value;
      unawaited(_loadStock());
    }
    final items = shopItemsOf(ref);
    final owned = <String>{for (final i in ref.watch(ownedItemsProvider).value ?? const []) i.itemKey};
    final premium = ref.watch(premiumProvider);
    final cfg = ref.watch(appConfigProvider);
    final svc = ref.watch(shopServiceProvider);
    final now = ref.watch(clockProvider).now();
    final next = today.addDays(1);
    final until = DateTime(next.year, next.month, next.day, ref.watch(dayStartHourProvider)).difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = toPersianDigits('${two(until.inHours.clamp(0, 99))}:${two(until.inMinutes % 60)}:${two(until.inSeconds % 60)}');
    final activeSeasons = {for (final p in ref.watch(seasonalCatalogProvider).active(today)) p.key};
    final seasonal = !cfg.feature('seasonal_packs') ? <ShopItem>[] : [for (final i in items) if (i.seasonalKey != null && activeSeasons.contains(i.seasonalKey) && i.shop == widget.shop) i];
    final everyday = svc.permanent(widget.shop);
    final furniture = widget.shop == 'furniture';

    Widget grid(List<ShopItem> list, {int columns = 3}) => GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 3 ? 0.84 : 0.66,
          children: [
            for (final it in list)
              ShopItemTile(
                key: ValueKey('tile-${it.itemKey}'),
                item: it,
                color: theme.tile,
                label: copy.t(it.nameKey),
                owned: owned.contains(it.itemKey),
                ownedLabel: copy.t('shop.owned'),
                onTap: () => _open(it, list),
              ),
          ],
        );

    return Scaffold(
      backgroundColor: theme.panel,
      body: Column(children: [
        _ShopTopBar(shop: widget.shop),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            _KeeperScene(shop: widget.shop, premium: premium),
            Container(
              decoration: BoxDecoration(color: theme.panel, borderRadius: const BorderRadius.vertical(top: Radius.circular(36))),
              transform: Matrix4.translationValues(0, -24, 0),
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: false,
                      child: Text(copy.t('shop.items_refresh', {'time': clock}), style: const TextStyle(color: DS.onDark, fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  _RefreshPill(cost: cfg.shopRefreshCost, onTap: _refresh),
                ]),
                const SizedBox(height: 14),
                grid(_stock),
                if (seasonal.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(sticker: 'nature/pomegranate', title: copy.t('shop.seasonal'), subtitle: null),
                  const SizedBox(height: 12),
                  grid(seasonal),
                ],
                const SizedBox(height: 28),
                _SectionHeader(sticker: furniture ? 'nav/furniture' : 'nav/outfit', fallback: furniture ? 'home/lamp' : 'clothing/tshirt', title: copy.t('shop.everyday.title'), subtitle: copy.t('shop.everyday.subtitle')),
                const SizedBox(height: 14),
                grid(everyday, columns: 4),
              ]),
            ),
          ]),
        ),
        _ShopTabs(current: widget.shop),
      ]),
    );
  }
}

/// Scene above the stock: the premium card (free users), then the keeper and its speech bubble.
class _KeeperScene extends ConsumerWidget {
  const _KeeperScene({required this.shop, required this.premium});
  final String shop;
  final bool premium;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final theme = ShopTheme.of(shop);
    final furniture = shop == 'furniture';
    return Stack(children: [
      Positioned.fill(
        child: Image.asset('assets/art/background/shop_$shop.webp', fit: BoxFit.cover, excludeFromSemantics: true, errorBuilder: (_, _, _) => ColoredBox(color: theme.scene)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(children: [
          if (!premium) const _PremiumCard(),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            EmojiArt(furniture ? 'animals/keeper_furniture' : 'animals/keeper_outfit', size: 150, fallback: furniture ? 'animals/monkey' : 'animals/koala'),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 70),
                child: _KeeperBubble(
                  name: copy.t(furniture ? 'shop.keeper.furniture.name' : 'shop.keeper.name'),
                  text: copy.t(furniture ? 'shop.keeper.furniture.line' : 'shop.keeper.line'),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

class _KeeperBubble extends StatelessWidget {
  const _KeeperBubble({required this.name, required this.text});
  final String name, text;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '$name: $text',
        child: ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsetsDirectional.only(start: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: const BoxDecoration(color: DS.keeperTag, borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
              child: Text(name, style: const TextStyle(color: DS.onDark, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: DS.card, borderRadius: BorderRadius.circular(26)),
              child: Text(text, style: const TextStyle(color: DS.textDeep, fontSize: 16, fontWeight: FontWeight.w700, height: 1.5)),
            ),
          ]),
        ),
      );
}

class _PremiumCard extends ConsumerWidget {
  const _PremiumCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(color: DS.premiumCard, borderRadius: BorderRadius.circular(34), border: Border.all(color: DS.premiumCardRim, width: 5)),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                Text(copy.t('shop.premium.title'), style: _headline.copyWith(color: DS.onDark, fontSize: 24, fontWeight: FontWeight.w800)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: DS.card, borderRadius: BorderRadius.circular(8)),
                  child: Text(copy.t('shop.premium.badge'), style: const TextStyle(color: DS.premiumCard, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(copy.t('shop.premium.body'), style: const TextStyle(color: DS.onDark, fontSize: 16, height: 1.5)),
            ]),
          ),
          const EmojiArt('animals/cat', size: 96),
        ]),
        const SizedBox(height: 14),
        ChunkyButton(
          label: copy.t('shop.premium.try'),
          color: DS.card,
          edgeColor: DS.neutralButtonEdge,
          textColor: DS.textDeep,
          onPressed: () => context.push(Routes.paywall('shop')),
        ),
      ]),
    );
  }
}

/// Orange price pill ending in a yellow refresh disc.
class _RefreshPill extends ConsumerWidget {
  const _RefreshPill({required this.cost, required this.onTap});
  final int cost;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final label = cost == 0 ? copy.t('shop.refresh_free') : toPersianDigits(cost);
    return Semantics(
      button: true,
      label: copy.t('shop.refresh_now', {'n': cost}),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Stack(alignment: AlignmentDirectional.centerEnd, children: [
              Container(
                margin: const EdgeInsetsDirectional.only(end: 30),
                padding: const EdgeInsetsDirectional.fromSTEB(18, 6, 36, 6),
                decoration: BoxDecoration(color: DS.shopRefreshPill, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (cost > 0) ...[const EmojiArt('ui/coin', size: 22), const SizedBox(width: 4)],
                  Text(label, style: const TextStyle(color: DS.onDark, fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: DS.progressYellow, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const EmojiArt('ui/repeat', size: 34),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.sticker, required this.title, required this.subtitle, this.fallback});
  final String sticker;
  final String? fallback;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Row(children: [
          EmojiArt(sticker, size: 54, fallback: fallback),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: _headline.copyWith(color: DS.onDark, fontSize: 22, fontWeight: FontWeight.w800)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: DS.onDark, fontSize: 15)),
            ]),
          ),
        ]),
      );
}

/// Bottom tabs switching between the two shops.
class _ShopTabs extends ConsumerWidget {
  const _ShopTabs({required this.current});
  final String current;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final theme = ShopTheme.of(current);
    return ColoredBox(
      color: theme.panel,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            for (final s in const [('outfit', 'nav/outfit', 'clothing/tshirt', Routes.shopOutfit), ('furniture', 'nav/furniture', 'home/lamp', Routes.shopFurniture)])
              Expanded(
                child: Semantics(
                  button: true,
                  selected: s.$1 == current,
                  label: copy.t('shop.shop.${s.$1}'),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      onTap: s.$1 == current ? null : () => context.pushReplacement(s.$4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: s.$1 == current ? DS.shopTabSelected : null, borderRadius: BorderRadius.circular(24)),
                        child: Column(children: [
                          EmojiArt(s.$2, size: 50, fallback: s.$3),
                          Text(copy.t('shop.shop.${s.$1}'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
