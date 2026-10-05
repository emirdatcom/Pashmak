import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import 'cat_view.dart';

/// Cat profile tab (docs/22 §12): a card with the cat, name, adventures and stage; About / Details / Traits tabs;
/// streak card; companions (phase 2) and the discoveries collection. The share button exports the card as an image only.
class CatProfileScreen extends ConsumerStatefulWidget {
  const CatProfileScreen({super.key});
  @override
  ConsumerState<CatProfileScreen> createState() => _CatProfileState();
}

class _CatProfileState extends ConsumerState<CatProfileScreen> {
  String _tab = 'about';
  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(questServiceProvider).recordVisit('cat'));
  }

  Future<void> _share() async {
    final copy = ref.read(copyProvider);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cat_card.png');
      await file.writeAsBytes(bytes);
      // Image only: no names of the user, no stats, nothing personal besides the cat itself.
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: copy.t('cat.share.text')));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final stage = ref.watch(catStageProvider);
    final count = ref.watch(adventuresCountProvider).value ?? 0;
    final profile = ref.watch(catProfileProvider).value;
    final streak = ref.watch(streakProvider).value;
    final found = ref.watch(foundDiscoveriesProvider).value ?? const <String>{};
    final today = ref.watch(todayProvider);
    final arrived = profile?.arrivedAt;
    final days = arrived == null ? 0 : today.date.difference(DateTime(arrived.year, arrived.month, arrived.day)).inDays + 1;
    final totalDone = ref.watch(goalsDoneTotalProvider).value ?? 0;

    final Widget body = switch (_tab) {
      'about' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kv(copy.t('cat.trait.label'), copy.t('cat.trait.${profile?.trait ?? 'curious'}')),
          if (arrived != null) _kv(copy.t('cat.arrived', {'date': JalaliFormatter.date(LocalDay.fromDate(arrived))}), ''),
        ]),
      'details' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kv(copy.t('cat.days_together', {'n': days}), ''),
          _kv(copy.t('cat.goals_done', {'n': totalDone}), ''),
          _kv(copy.t('cat.discoveries_count', {'n': found.length}), ''),
        ]),
      _ => Text(copy.t('cat.traits_soon'), style: const TextStyle(color: DS.textSecondary)),
    };

    return Scaffold(
      backgroundColor: DS.bgCat,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Row(children: [
            Expanded(child: Text(copy.t('cat.profile.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback))),
            IconButton(tooltip: copy.t('cat.share'), icon: const Icon(Icons.ios_share, color: DS.textPrimary), onPressed: _share),
            IconButton(tooltip: copy.t('cat.edit'), icon: const Icon(Icons.edit_outlined, color: DS.textPrimary), onPressed: () => context.push(Routes.catEdit)),
          ]),
          RepaintBoundary(
            key: _cardKey,
            child: RoundCard(
              color: DS.cardCat,
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(color: DS.bgCat.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24)),
                    child: const FittedBox(child: SizedBox(width: 200, height: 200, child: CatView())),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(copy.t('cat.profile.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback)),
                      Text('${copy.t('cat.profile.adventures', {'n': count})} · ${copy.t('cat.stage.${stage.name}')}', style: const TextStyle(color: DS.textSecondary)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                TabPills(
                  tabs: [for (final t in const ['about', 'details', 'traits']) PillTab(t, copy.t('cat.tab.$t'))],
                  selected: _tab,
                  onSelected: (t) => setState(() => _tab = t),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          RoundCard(child: SizedBox(width: double.infinity, child: body)),
          const SizedBox(height: 12),
          RoundCard(
            child: Row(children: [
              const Icon(Icons.local_fire_department, color: DS.energy, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(copy.t('cat.streak_current', {'n': streak?.current ?? 0}), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w800)),
                  Text(copy.t('cat.streak_best', {'n': streak?.longest ?? 0}), style: const TextStyle(color: DS.textSecondary)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          RoundCard(
            onTap: () => context.push(Routes.discoveries),
            semanticLabel: copy.t('cat.discoveries'),
            child: Row(children: [
              const Icon(Icons.collections_bookmark, color: DS.areaFocus, size: 30),
              const SizedBox(width: 12),
              Expanded(child: Text(copy.t('cat.discoveries'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w800))),
              Text(copy.t('cat.discoveries.progress', {'n': found.length}), style: const TextStyle(color: DS.textSecondary)),
              const Icon(Icons.chevron_left, color: DS.textSecondary),
            ]),
          ),
          const SizedBox(height: 12),
          RoundCard(
            color: DS.neutralButton,
            child: Row(children: [
              const Icon(Icons.lock, color: DS.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(copy.t('cat.companions'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700))),
              Text(copy.t('cat.companions_soon'), style: const TextStyle(color: DS.textSecondary)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _kv(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(a, style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w600))),
          if (b.isNotEmpty) Text(b, style: const TextStyle(color: DS.textSecondary)),
        ]),
      );
}

/// Edit the cat's name and trait.
class CatEditScreen extends ConsumerStatefulWidget {
  const CatEditScreen({super.key});
  @override
  ConsumerState<CatEditScreen> createState() => _CatEditState();
}

class _CatEditState extends ConsumerState<CatEditScreen> {
  late final _name = TextEditingController(text: ref.read(catNameProvider));
  String? _trait;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final n = _name.text.trim();
    if (n.isNotEmpty && n.runes.length <= 16) {
      await db.setMeta('cat_name', n);
      ref.read(catNameProvider.notifier).set(n);
    }
    if (_trait != null) await db.setMeta('cat_trait', _trait!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final trait = _trait ?? ref.watch(catProfileProvider).value?.trait ?? 'curious';
    return Scaffold(
      backgroundColor: DS.bgCat,
      appBar: AppBar(title: Text(copy.t('cat.edit.title')), backgroundColor: DS.bgCat),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        RoundCard(child: TextField(controller: _name, maxLength: 16, decoration: InputDecoration(hintText: copy.t('onboarding.name.hint'), border: InputBorder.none, counterText: ''))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final t in const ['curious', 'kind', 'playful'])
            ChoiceChip(label: Text(copy.t('cat.trait.$t')), selected: trait == t, onSelected: (_) => setState(() => _trait = t)),
        ]),
        const SizedBox(height: 20),
        ChunkyButton(label: copy.t('cat.edit.save'), onPressed: _save),
      ]),
    );
  }
}
