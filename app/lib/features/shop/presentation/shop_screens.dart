import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/l10n/duration_format.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../domain/shop_service.dart';

List<ShopItem> shopItemsOf(WidgetRef ref) => shopCatalog(ref.watch(contentRepositoryProvider), ref.watch(seasonalCatalogProvider));

/// Placeholder item art: a coloured rounded square with the slot icon (final art comes from docs/art-brief.md).
class ItemArt extends StatelessWidget {
  const ItemArt({super.key, required this.item, this.size = 56});
  final ShopItem item;
  final double size;

  static IconData iconFor(String slot) => switch (slot) {
        'collar' => Icons.radio_button_checked,
        'hat' => Icons.emoji_nature,
        'glasses' => Icons.visibility,
        'scarf' => Icons.waves,
        'background' => Icons.landscape,
        'room_table' => Icons.coffee,
        'room_floor' => Icons.grid_on,
        'room_wall' => Icons.image,
        'room_shelf' => Icons.shelves,
        _ => Icons.category,
      };

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: DS.area(const ['sleep', 'calm', 'movement', 'nutrition', 'connection', 'focus', 'self_kindness', 'home'][item.itemKey.codeUnits.fold<int>(0, (a, b) => a + b) % 8]).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(18)),
        child: Icon(iconFor(item.slot), color: DS.textPrimary, size: size * 0.5),
      );
}

/// "Shops": the two shops as big cards (outfit, furniture).
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    unawaited(ref.read(questServiceProvider).recordVisit('shop'));
    return Scaffold(
      backgroundColor: DS.bgShopPanel,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(copy.t('shop.shops.title'), style: const TextStyle(color: DS.onDark, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const _CoinsBar(),
          const SizedBox(height: 16),
          for (final s in const [('outfit', Icons.checkroom, Routes.shopOutfit), ('furniture', Icons.chair, Routes.shopFurniture)])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: RoundCard(
                onTap: () => context.push(s.$3),
                semanticLabel: copy.t('shop.shop.${s.$1}'),
                child: Row(children: [
                  Container(width: 64, height: 64, decoration: BoxDecoration(color: DS.bgShopScene.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)), child: Icon(s.$2, size: 34, color: DS.textPrimary)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(copy.t('shop.shop.${s.$1}'), style: const TextStyle(color: DS.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(copy.t('shop.shop.${s.$1}.hint'), style: const TextStyle(color: DS.textSecondary)),
                    ]),
                  ),
                  const Icon(Icons.chevron_left, color: DS.textSecondary),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _CoinsBar extends ConsumerWidget {
  const _CoinsBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final coins = ref.watch(walletProvider).value?.coins ?? 0;
    return Semantics(
      label: '${copy.t('wallet.coins')} ${toPersianDigits(coins)}',
      child: ExcludeSemantics(
        child: Row(children: [
          const Icon(Icons.monetization_on, color: DS.coin),
          const SizedBox(width: 6),
          Text(toPersianDigits(coins), style: const TextStyle(color: DS.onDark, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// One shop: the shopkeeper, today's rotating stock with a refresh countdown/price, the permanent collection,
/// the catalog and selling.
class ShopDetailScreen extends ConsumerStatefulWidget {
  const ShopDetailScreen({super.key, required this.shop});
  final String shop; // outfit | furniture
  @override
  ConsumerState<ShopDetailScreen> createState() => _ShopDetailState();
}

class _ShopDetailState extends ConsumerState<ShopDetailScreen> {
  List<ShopItem> _stock = const [];
  String? _stockDay;
  int _version = 0;

  Future<void> _loadStock() async {
    final svc = ref.read(shopServiceProvider);
    final s = await svc.stock(widget.shop);
    if (mounted) setState(() => _stock = s);
  }

  Future<void> _buy(ShopItem it) async {
    final copy = ref.read(copyProvider);
    final premium = ref.read(premiumProvider);
    if (it.premiumOnly && !premium) {
      await passGate(context, ref, 'premium_item');
      return;
    }
    final r = await ref.read(shopServiceProvider).buy(it.itemKey, isPremium: premium);
    if (!mounted) return;
    final msg = switch (r) {
      BuyStatus.bought => copy.t('shop.bought'),
      BuyStatus.outOfSeason => copy.t('shop.out_of_season'),
      BuyStatus.notEnoughCoins => copy.t('shop.not_enough_coins'),
      _ => null,
    };
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        action: r == BuyStatus.notEnoughCoins ? SnackBarAction(label: copy.t('quest.screen.title'), onPressed: () => context.go(Routes.quests)) : null,
      ));
    }
    setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    ref.watch(tickProvider);
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
    final untilNext = DateTime(next.year, next.month, next.day, ref.watch(dayStartHourProvider)).difference(now);
    final activeSeasons = {for (final p in ref.watch(seasonalCatalogProvider).active(today)) p.key};
    final seasonal = !cfg.feature('seasonal_packs') ? <ShopItem>[] : [for (final i in items) if (i.seasonalKey != null && activeSeasons.contains(i.seasonalKey) && i.shop == widget.shop) i];
    final lines = copy.t('shop.keeper.line');
    final messenger = ScaffoldMessenger.of(context);

    Widget grid(List<ShopItem> list) => GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: [
            for (final it in list)
              ItemTile(
                key: ValueKey('tile-${it.itemKey}-$_version'),
                name: copy.t(it.nameKey),
                art: ItemArt(item: it),
                owned: owned.contains(it.itemKey),
                ownedLabel: copy.t('shop.owned'),
                priceCoins: it.priceCoins,
                premiumLabel: it.premiumOnly && !premium && !owned.contains(it.itemKey) ? copy.t('shop.premium_short') : null,
                onTap: owned.contains(it.itemKey) ? null : () => _buy(it),
              ),
          ],
        );

    return Scaffold(
      backgroundColor: DS.bgShopPanel,
      appBar: AppBar(
        title: Text(copy.t('shop.shop.${widget.shop}')),
        backgroundColor: DS.bgShopPanel,
        foregroundColor: DS.onDark,
        actions: [
          TextButton(onPressed: () => _catalog(items, owned), child: Text(copy.t('shop.catalog'), style: const TextStyle(color: DS.onDark))),
          TextButton(onPressed: _sell, child: Text(copy.t('shop.sell'), style: const TextStyle(color: DS.onDark))),
        ],
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          color: DS.bgShopScene,
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(width: 72, height: 72, decoration: const BoxDecoration(shape: BoxShape.circle, color: DS.card), child: const Icon(Icons.pets, color: DS.textPrimary, size: 40)),
            const SizedBox(width: 12),
            Expanded(child: SpeechBubble(text: lines, speaker: copy.t('shop.keeper.name'))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _CoinsBar(),
            const SizedBox(height: 12),
            if (!premium)
              RoundCard(
                color: DS.premiumBadge,
                onTap: () => context.push(Routes.paywall('settings')),
                child: Row(children: [
                  const Icon(Icons.workspace_premium, color: DS.lockYellow),
                  const SizedBox(width: 10),
                  Expanded(child: Text(copy.t('shop.sub_banner'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700))),
                ]),
              ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(copy.t('shop.today'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700))),
              Flexible(child: CountdownChip(label: '${copy.t('shop.refresh_in')}: ${formatRemaining(copy, untilNext)}')),
            ]),
            const SizedBox(height: 8),
            grid(_stock),
            const SizedBox(height: 10),
            ChunkyButton.neutral(
              icon: Icons.refresh,
              label: copy.t('shop.refresh_now', {'n': cfg.shopRefreshCost}),
              onPressed: () async {
                final r = await svc.refresh(widget.shop);
                if (!mounted) return;
                if (r == RefreshStatus.refreshed) {
                  await _loadStock();
                  messenger.showSnackBar(SnackBar(content: Text(copy.t('shop.refreshed'))));
                } else {
                  messenger.showSnackBar(SnackBar(content: Text(copy.t('shop.not_enough_coins'))));
                }
              },
            ),
            if (seasonal.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(copy.t('shop.seasonal'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              grid(seasonal),
            ],
            const SizedBox(height: 20),
            Text(copy.t('shop.permanent'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            grid(svc.permanent(widget.shop)),
          ]),
        ),
      ]),
    );
  }

  Future<void> _catalog(List<ShopItem> items, Set<String> owned) {
    final copy = ref.read(copyProvider);
    final list = [for (final i in items) if (i.shop == widget.shop && i.seasonalKey == null) i];
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final i in list)
            ListTile(
              leading: ItemArt(item: i, size: 40),
              title: Text(copy.t(i.nameKey)),
              subtitle: Text(copy.t('shop.slot.${i.slot}')),
              trailing: owned.contains(i.itemKey) ? const Icon(Icons.check_circle, color: DS.doneText) : (i.premiumOnly ? const Icon(Icons.lock, color: DS.premiumBadge) : Text(toPersianDigits(i.priceCoins))),
            ),
        ]),
      ),
    );
  }

  Future<void> _sell() async {
    final copy = ref.read(copyProvider);
    final svc = ref.read(shopServiceProvider);
    final owned = [for (final i in await ref.read(databaseProvider).select(ref.read(databaseProvider).inventory).get()) if (svc.item(i.itemKey)?.shop == widget.shop) i];
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: owned.isEmpty
            ? Padding(padding: const EdgeInsets.all(24), child: Text(copy.t('shop.sell_empty')))
            : ListView(shrinkWrap: true, children: [
                for (final i in owned)
                  ListTile(
                    leading: ItemArt(item: svc.item(i.itemKey)!, size: 40),
                    title: Text(copy.t(svc.item(i.itemKey)!.nameKey)),
                    subtitle: i.equipped ? Text(copy.t('shop.sell_equipped')) : null,
                    trailing: Text(copy.t('shop.sell_value', {'n': svc.sellValue(i.itemKey)})),
                    onTap: () async {
                      final r = await svc.sell(i.itemKey);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      final msg = r == SellStatus.sold ? copy.t('shop.sold', {'n': svc.sellValue(i.itemKey)}) : copy.t('shop.sell_equipped');
                      messenger.showSnackBar(SnackBar(content: Text(msg)));
                    },
                  ),
              ]),
      ),
    );
  }
}
