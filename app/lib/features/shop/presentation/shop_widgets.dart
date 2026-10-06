import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../domain/shop_service.dart';

/// Colours of one shop: the scene behind the keeper, the panel holding the stock and its tiles.
class ShopTheme {
  const ShopTheme(this.scene, this.panel, this.tile);
  final Color scene, panel, tile;
  static ShopTheme of(String shop) =>
      shop == 'furniture' ? const ShopTheme(DS.shopFurnitureScene, DS.shopFurniturePanel, DS.shopFurnitureTile) : const ShopTheme(DS.bgShopScene, DS.bgShopPanel, DS.shopTile);
}

/// A filter of the closet, catalog and inventory: a glyph and the slots it covers (empty = everything).
class ShopCategory {
  const ShopCategory(this.key, this.slots, this.fallback);
  final String key;
  final List<String> slots;

  /// Shown until the white glyph `assets/art/emoji/glyph/cat_<key>.png` is in the bundle.
  final IconData fallback;

  bool matches(ShopItem i) => slots.isEmpty || slots.contains(i.slot);

  static const outfit = [
    ShopCategory('all', [], Icons.apps_rounded),
    ShopCategory('top', ['top'], Icons.checkroom_rounded),
    ShopCategory('bottom', ['bottom'], Icons.straighten_rounded),
    ShopCategory('onesie', ['onesie'], Icons.accessibility_new_rounded),
    ShopCategory('hat', ['hat'], Icons.school_rounded),
    ShopCategory('glasses', ['glasses'], Icons.visibility_rounded),
    ShopCategory('neck', ['scarf', 'collar'], Icons.waves_rounded),
    ShopCategory('shoes', ['shoes'], Icons.hiking_rounded),
    ShopCategory('held', ['held'], Icons.back_hand_rounded),
  ];

  static const furniture = [
    ShopCategory('all', [], Icons.apps_rounded),
    ShopCategory('bed', ['room_bed'], Icons.bed_rounded),
    ShopCategory('seat', ['room_seat'], Icons.chair_rounded),
    ShopCategory('lamp', ['room_lamp'], Icons.light_rounded),
    ShopCategory('wall', ['room_wall'], Icons.image_rounded),
    ShopCategory('storage', ['room_shelf', 'room_dresser'], Icons.shelves),
    ShopCategory('table', ['room_table'], Icons.table_restaurant_rounded),
    ShopCategory('plant', ['room_plant'], Icons.local_florist_rounded),
    ShopCategory('rug', ['room_floor'], Icons.texture_rounded),
    ShopCategory('doorside', ['room_doorside'], Icons.door_back_door_rounded),
    ShopCategory('interior', ['room_wallpaper', 'room_flooring', 'room_window', 'room_door'], Icons.wallpaper_rounded),
    ShopCategory('background', ['background'], Icons.landscape_rounded),
  ];

  static List<ShopCategory> forShop(String shop) => shop == 'furniture' ? furniture : outfit;
}

/// The item's art in its chosen colour. Until the art is drawn, a soft tile with the slot's icon stands in.
class ItemArt extends StatelessWidget {
  const ItemArt({super.key, required this.item, this.size = 56, this.hue = 0});
  final ShopItem item;
  final double size;
  final int hue;

  static IconData iconFor(String slot) => switch (slot) {
        'top' => Icons.checkroom_rounded,
        'bottom' => Icons.straighten_rounded,
        'onesie' => Icons.accessibility_new_rounded,
        'shoes' => Icons.hiking_rounded,
        'held' => Icons.back_hand_rounded,
        'collar' => Icons.radio_button_checked,
        'hat' => Icons.school_rounded,
        'glasses' => Icons.visibility,
        'scarf' => Icons.waves,
        'background' => Icons.landscape,
        'room_bed' => Icons.bed_rounded,
        'room_seat' => Icons.chair_rounded,
        'room_lamp' => Icons.light_rounded,
        'room_plant' => Icons.local_florist_rounded,
        'room_dresser' || 'room_shelf' => Icons.shelves,
        'room_table' => Icons.coffee,
        'room_floor' => Icons.texture_rounded,
        'room_wall' => Icons.image,
        'room_doorside' || 'room_door' => Icons.door_back_door_rounded,
        'room_window' => Icons.window_rounded,
        'room_wallpaper' || 'room_flooring' => Icons.wallpaper_rounded,
        _ => Icons.category,
      };

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: HueShift(
          degrees: hue,
          child: Image.asset(
            item.asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => Container(
              decoration: BoxDecoration(color: DS.glass, borderRadius: BorderRadius.circular(size * 0.3)),
              child: Icon(iconFor(item.slot), color: DS.onDark, size: size * 0.5),
            ),
          ),
        ),
      );
}

/// White pill with the coin sticker overlapping its start: the wallet in shop headers.
class CoinPill extends ConsumerWidget {
  const CoinPill({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final coins = ref.watch(walletProvider).value?.coins ?? 0;
    return Semantics(
      label: '${copy.t('wallet.coins')} ${toPersianDigits(coins)}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          child: Stack(alignment: AlignmentDirectional.centerStart, children: [
            Container(
              margin: const EdgeInsetsDirectional.only(start: 20),
              padding: const EdgeInsetsDirectional.fromSTEB(34, 6, 18, 6),
              decoration: BoxDecoration(color: DS.card, borderRadius: BorderRadius.circular(24)),
              child: Text(toPersianDigits(coins), style: const TextStyle(color: DS.coinPillText, fontSize: 19, fontWeight: FontWeight.w800)),
            ),
            const EmojiArt('ui/coin', size: 46),
          ]),
        ),
      ),
    );
  }
}

/// White category glyph (`glyph/cat_<key>`), Material icon until the glyph exists.
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({super.key, required this.category, this.color = DS.onDark, this.size = 30});
  final ShopCategory category;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/art/emoji/glyph/cat_${category.key}.png',
        width: size,
        height: size,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => Icon(category.fallback, color: color, size: size),
      );
}

/// Horizontal row of category glyphs; the selected one sits on a lighter rounded square.
class CategoryRow extends ConsumerWidget {
  const CategoryRow({super.key, required this.categories, required this.selected, required this.onSelect, this.leading, this.chipColor = DS.inventoryChip});
  final List<ShopCategory> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  final Widget? leading;
  final Color chipColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return SizedBox(
      height: 64,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
        ?leading,
        for (final c in categories)
          Semantics(
            button: true,
            selected: c.key == selected,
            label: copy.t('shop.cat.${c.key}'),
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: () => onSelect(c.key),
                child: Container(
                  width: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  decoration: BoxDecoration(color: c.key == selected ? chipColor : null, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: CategoryGlyph(category: c, color: c.key == selected ? DS.onDark : DS.glyphDim),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Price row: coin sticker + amount.
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.coins, this.color = DS.onDark, this.size = 18});
  final int coins;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        EmojiArt('ui/coin', size: size * 1.5),
        const SizedBox(width: 6),
        Text(toPersianDigits(coins), style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800)),
      ]);
}

/// A shop tile: the item over a soft glow, the price (or "owned") at the bottom.
class ShopItemTile extends StatelessWidget {
  const ShopItemTile({super.key, required this.item, required this.color, required this.label, required this.onTap, this.owned = false, this.ownedLabel, this.selected = false, this.hue = 0});
  final ShopItem item;
  final Color color;
  final String label; // semantics: the item's name
  final VoidCallback? onTap;
  final bool owned;
  final String? ownedLabel;
  final bool selected;
  final int hue;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: owned && ownedLabel != null ? '$label, $ownedLabel' : '$label, ${toPersianDigits(item.priceCoins)}',
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: onTap,
            child: LayoutBuilder(builder: (context, c) {
              final art = c.maxWidth * 0.62;
              return Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(28),
                  border: selected ? Border.all(color: DS.onDark, width: 4) : null,
                  gradient: RadialGradient(center: const Alignment(0, 0.75), radius: 0.7, colors: [Color.lerp(color, DS.onDark, 0.22)!, color]),
                ),
                child: Column(children: [
                  const Spacer(flex: 2),
                  ItemArt(item: item, size: art, hue: hue),
                  const Spacer(flex: 3),
                  if (owned)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded, color: DS.onDark, size: 20),
                      const SizedBox(width: 4),
                      Flexible(child: Text(ownedLabel ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w800))),
                    ])
                  else
                    FittedBox(child: PriceTag(coins: item.priceCoins)),
                  const SizedBox(height: 12),
                ]),
              );
            }),
          ),
        ),
      );
}

/// Off-white modal sheet with a title, an optional item, a message and two buttons (buy / sell / message flows).
Future<bool?> shopDialog(
  BuildContext context, {
  required String title,
  String? body,
  Widget? art,
  required String yes,
  String? no,
  Widget? extra,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: DS.sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusSheet))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (art != null) Center(child: art),
            if (art != null) const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: DS.textDeep, fontSize: 20, fontWeight: FontWeight.w800)),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(color: DS.textSecondary, height: 1.6)),
            ],
            if (extra != null) ...[const SizedBox(height: 12), Center(child: extra)],
            const SizedBox(height: 20),
            ChunkyButton(label: yes, onPressed: () => Navigator.pop(ctx, true)),
            if (no != null) ...[
              const SizedBox(height: 10),
              ChunkyButton.neutral(label: no, onPressed: () => Navigator.pop(ctx, false)),
            ],
          ]),
        ),
      ),
    );
