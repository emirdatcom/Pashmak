import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/cat_renderer.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../domain/shop_service.dart';
import 'shop_screens.dart' show shopItemsOf;
import 'shop_widgets.dart';

/// Closet (dress-up screenshots): the cat on a light-blue stage, category glyphs with search, the owned items with a
/// "none" tile, and a colour sheet for items with variants. [shop] `furniture` shows the home's placed items instead
/// of the cat. The Appearance tab picks the fur colour.
class ClosetScreen extends ConsumerStatefulWidget {
  const ClosetScreen({super.key, this.shop = 'outfit'});
  final String shop;
  @override
  ConsumerState<ClosetScreen> createState() => _ClosetState();
}

class _ClosetState extends ConsumerState<ClosetScreen> {
  String _cat = 'all';
  bool _appearance = false;
  bool _searching = false;
  String _query = '';

  bool get _outfit => widget.shop == 'outfit';

  Future<void> _tap(ShopItem it, bool equipped) async {
    final svc = ref.read(shopServiceProvider);
    final premium = ref.read(premiumProvider);
    if (!equipped) {
      final r = await svc.toggleEquip(it.itemKey, isPremium: premium);
      if (r == EquipStatus.premiumLocked && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(copyProvider).t('shop.premium_only'))));
        return;
      }
      if (it.hues.length > 1 && mounted) await _colors(it);
    } else if (it.hues.length > 1) {
      await _colors(it);
    } else {
      await svc.toggleEquip(it.itemKey, isPremium: premium);
    }
  }

  /// Bottom sheet over a dimmed closet with the item in each of its colours.
  Future<void> _colors(ShopItem it) {
    final copy = ref.read(copyProvider);
    final db = ref.read(databaseProvider);
    return showModalBottomSheet<void>(
      context: context,
      barrierColor: DS.closetDim,
      backgroundColor: DS.closetSheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final current = ref.watch(itemHuesProvider).value?[it.itemKey] ?? 0;
        return SafeArea(
          child: SizedBox(
            height: 260,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(copy.t('closet.colors'), style: const TextStyle(color: DS.onDark, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: it.hues.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => Semantics(
                    button: true,
                    selected: it.hues[i] == current,
                    label: '${copy.t(it.nameKey)} ${i + 1}',
                    child: GestureDetector(
                      onTap: () async {
                        await db.setMeta('item_hue:${it.itemKey}', '${it.hues[i]}');
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 128,
                        decoration: BoxDecoration(
                          color: DS.closetTile,
                          borderRadius: BorderRadius.circular(30),
                          border: it.hues[i] == current ? Border.all(color: DS.onDark, width: 4) : null,
                        ),
                        alignment: Alignment.center,
                        child: ItemArt(item: it, size: 84, hue: it.hues[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final cats = ShopCategory.forShop(widget.shop);
    final cat = cats.firstWhere((c) => c.key == _cat);
    final rows = ref.watch(ownedItemsProvider).value ?? const [];
    final equipped = {for (final r in rows) if (r.equipped) r.itemKey};
    final hues = ref.watch(itemHuesProvider).value ?? const {};
    final owned = {for (final r in rows) r.itemKey};
    final all = shopItemsOf(ref);
    final q = _query.trim();
    final list = [
      for (final i in all)
        if (owned.contains(i.itemKey) && i.shop == widget.shop && cat.matches(i) && (q.isEmpty || copy.t(i.nameKey).contains(q))) i,
    ];

    return Scaffold(
      backgroundColor: DS.closetBottom,
      body: Column(children: [
        // Stage
        Container(
          height: MediaQuery.sizeOf(context).height * 0.36,
          color: DS.closetTop,
          child: SafeArea(
            bottom: false,
            child: Stack(children: [
              Align(
                alignment: const Alignment(0, 0.7),
                child: _outfit
                    ? const SizedBox(height: 200, child: FittedBox(child: CatView()))
                    : _HomeItems(items: [for (final i in all) if (equipped.contains(i.itemKey) && i.shop == 'furniture') i], hues: hues),
              ),
              PositionedDirectional(
                top: 8,
                start: 12,
                child: Semantics(
                  button: true,
                  label: copy.t('shop.close'),
                  child: GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go(Routes.bag),
                    child: Container(width: 48, height: 48, decoration: const BoxDecoration(color: DS.glass, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: DS.onDark, size: 30)),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _appearance
              ? const _Appearance()
              : Column(children: [
                  if (_searching)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: true,
                        style: const TextStyle(color: DS.onDark, fontSize: 17),
                        cursorColor: DS.onDark,
                        decoration: InputDecoration(
                          hintText: copy.t('closet.search.hint'),
                          hintStyle: const TextStyle(color: DS.glyphDim),
                          filled: true,
                          fillColor: DS.closetTile,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                          suffixIcon: IconButton(
                            tooltip: copy.t('common.close'),
                            icon: const Icon(Icons.close_rounded, color: DS.onDark),
                            onPressed: () => setState(() {
                              _searching = false;
                              _query = '';
                            }),
                          ),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    )
                  else
                    CategoryRow(
                      categories: cats,
                      selected: _cat,
                      chipColor: DS.closetTile,
                      onSelect: (k) => setState(() => _cat = k),
                      leading: IconButton(
                        tooltip: copy.t('closet.search'),
                        onPressed: () => setState(() => _searching = true),
                        icon: const Icon(Icons.search_rounded, color: DS.onDark, size: 32),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: list.isEmpty && cat.slots.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(copy.t('closet.empty'), textAlign: TextAlign.center, style: const TextStyle(color: DS.onDark, fontSize: 17, fontWeight: FontWeight.w700, height: 1.6)),
                          )
                        : GridView.count(
                            crossAxisCount: 3,
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: [
                              if (cat.slots.isNotEmpty)
                                _ClosetTile(
                                  label: copy.t('closet.none'),
                                  selected: !list.any((i) => equipped.contains(i.itemKey)),
                                  onTap: () async {
                                    for (final s in cat.slots) {
                                      await ref.read(shopServiceProvider).unequipSlot(s);
                                    }
                                  },
                                  child: Text(copy.t('closet.none'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                                ),
                              for (final it in list)
                                _ClosetTile(
                                  label: copy.t(it.nameKey),
                                  selected: equipped.contains(it.itemKey),
                                  onTap: () => _tap(it, equipped.contains(it.itemKey)),
                                  child: ItemArt(item: it, size: 80, hue: hues[it.itemKey] ?? 0),
                                ),
                            ],
                          ),
                  ),
                ]),
        ),
        if (_outfit)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(children: [
                for (final a in [false, true])
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: _appearance == a,
                      child: GestureDetector(
                        onTap: () => setState(() => _appearance = a),
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(color: _appearance == a ? DS.closetTile : null, borderRadius: BorderRadius.circular(20)),
                          alignment: Alignment.center,
                          child: Text(copy.t(a ? 'closet.appearance' : 'closet.items'), style: const TextStyle(color: DS.onDark, fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _ClosetTile extends StatelessWidget {
  const _ClosetTile({required this.label, required this.selected, required this.onTap, required this.child});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(color: DS.closetTile, borderRadius: BorderRadius.circular(28), border: selected ? Border.all(color: DS.onDark, width: 5) : null),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      );
}

/// The furniture placed at home, as a loose row of stickers (until the room view exists).
class _HomeItems extends ConsumerWidget {
  const _HomeItems({required this.items, required this.hues});
  final List<ShopItem> items;
  final Map<String, int> hues;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(copy.t('closet.home'), style: const TextStyle(color: DS.onDark, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        for (final i in items.take(10)) ItemArt(item: i, size: 64, hue: hues[i.itemKey] ?? 0),
      ]),
    ]);
  }
}

/// Fur colour, and a note that more looks open as the cat grows.
class _Appearance extends ConsumerWidget {
  const _Appearance();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final fur = ref.watch(catProfileProvider).value?.fur ?? CatFur.orangeCream;
    final stage = ref.watch(catStageProvider);
    const swatch = {CatFur.orangeCream: DS.areaMovement, CatFur.smokeGray: DS.textMuted, CatFur.tricolor: DS.bgCat};
    const names = {CatFur.orangeCream: 'orange_cream', CatFur.smokeGray: 'smoke_gray', CatFur.tricolor: 'tricolor'};
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
      Text(copy.t('closet.fur'), style: const TextStyle(color: DS.onDark, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Row(children: [
        for (final f in CatFur.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _ClosetTile(
                label: copy.t('onboarding.fur.${names[f]}'),
                selected: f == fur,
                onTap: () => ref.read(databaseProvider).setMeta('cat_fur', f.name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    Container(width: 52, height: 52, decoration: BoxDecoration(color: swatch[f], shape: BoxShape.circle, border: Border.all(color: DS.onDark, width: 3))),
                    const SizedBox(height: 8),
                    Text(copy.t('onboarding.fur.${names[f]}'), textAlign: TextAlign.center, style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
      if (stage != CatStage.adult) ...[
        const SizedBox(height: 28),
        const Icon(Icons.pets_rounded, size: 120, color: DS.closetTile),
        const SizedBox(height: 16),
        Text(copy.t('closet.grow'), textAlign: TextAlign.center, style: const TextStyle(color: DS.onDark, fontSize: 18, height: 1.6)),
      ],
    ]);
  }
}
