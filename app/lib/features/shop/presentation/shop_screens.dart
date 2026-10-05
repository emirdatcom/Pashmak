import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../../wallet/presentation/wallet_bar.dart';
import '../domain/shop_service.dart';

List<ShopItem> _items(WidgetRef ref) {
  ref.watch(contentRepositoryProvider);
  return [for (final j in ((ref.read(contentRepositoryProvider).entries('shop_items') as List?) ?? const []).cast<Map<String, dynamic>>()) ShopItem.fromJson(j)];
}

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final items = _items(ref);
    final owned = {for (final i in ref.watch(ownedItemsProvider).value ?? const []) i.itemKey};
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(copy.t('shop.title')),
          actions: [TextButton(onPressed: () => context.push(Routes.closet), child: Text(copy.t('shop.closet')))],
          bottom: TabBar(tabs: [Tab(text: copy.t('shop.tab.cat')), Tab(text: copy.t('shop.tab.room')), Tab(text: copy.t('shop.tab.background'))]),
        ),
        body: Column(children: [
          const Padding(padding: EdgeInsets.all(AppSpacing.sm), child: WalletBar()),
          Expanded(
            child: TabBarView(children: [
              for (final tab in ['cat', 'room', 'background'])
                ListView(children: [for (final it in items.where((i) => i.tab == tab)) _ShopTile(item: it, owned: owned.contains(it.itemKey))]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ShopTile extends ConsumerWidget {
  const _ShopTile({required this.item, required this.owned});
  final ShopItem item;
  final bool owned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return ListTile(
      title: Text(copy.t(item.nameKey)),
      subtitle: item.premiumOnly ? Text(copy.t('shop.premium_only')) : null,
      trailing: owned
          ? Chip(label: Text(copy.t('shop.owned')))
          : FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () async {
                final premium = ref.read(premiumProvider);
                if (item.premiumOnly && !premium) {
                  await passGate(context, ref, 'premium_item');
                  return;
                }
                final r = await ref.read(shopServiceProvider).buy(item.itemKey, isPremium: premium);
                if (!context.mounted) return;
                if (r == BuyStatus.notEnoughCoins) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(copy.t('shop.not_enough_coins')),
                    action: SnackBarAction(label: copy.t('adventure.title'), onPressed: () => context.push(Routes.adventure)),
                  ));
                }
              },
              child: Text('${copy.t('shop.buy')} ${toPersianDigits(item.priceCoins)}'),
            ),
    );
  }
}

/// Owned items with live preview on the cat.
class ClosetScreen extends ConsumerWidget {
  const ClosetScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final svc = ref.watch(shopServiceProvider);
    final owned = ref.watch(ownedItemsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('shop.closet'))),
      body: ListView(children: [
        const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CatView())),
        if (owned.isEmpty) Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(copy.t('shop.closet.empty'), textAlign: TextAlign.center)),
        for (final i in owned)
          SwitchListTile(
            title: Text(copy.t(svc.item(i.itemKey)?.nameKey ?? 'shop.title')),
            subtitle: Text(copy.t('shop.slot.${i.slot}')),
            value: i.equipped,
            onChanged: (_) async {
              final r = await svc.toggleEquip(i.itemKey, isPremium: ref.read(premiumProvider));
              if (r == EquipStatus.premiumLocked && context.mounted) await passGate(context, ref, 'premium_item');
            },
          ),
      ]),
    );
  }
}
