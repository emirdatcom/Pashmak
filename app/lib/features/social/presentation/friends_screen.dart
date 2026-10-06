import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/network/api_error.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/cat_renderer.dart';
import '../../../core/widgets/widgets.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../domain/social.dart';

final socialServiceProvider = Provider<SocialService>((ref) {
  final brand = ref.watch(contentRepositoryProvider).bundledEntries('brand');
  return SocialService(ref.watch(databaseProvider), ref.watch(apiClientProvider),
      defaultCatName: (brand['cat_default_name'] as String?) ?? '', stage: () => ref.read(catStageProvider).name);
});

final socialSnapshotProvider = FutureProvider.autoDispose<SocialSnapshot>((ref) => ref.watch(socialServiceProvider).load());

/// Lifetime friend/vibe counters (companions unlock from these).
final socialStatsProvider = FutureProvider<SocialStats>((ref) {
  ref.watch(dbTickProvider);
  return ref.watch(socialServiceProvider).stats();
});

String socialErrorKey(Object e) {
  if (e is ApiError) {
    switch (e.code) {
      case 'FRIEND_CODE_INVALID':
        return 'social.err.code';
      case 'FRIEND_LIMIT':
        return 'social.err.limit';
      case 'VIBE_ALREADY_SENT':
        return 'social.err.vibed';
      case 'RATE_LIMITED':
        return 'social.err.slow';
      case 'NETWORK':
        return 'social.err.offline';
    }
  }
  return 'social.err.generic';
}

/// `/friends`: my friend code, add a friend by code, send each friend one good vibe a day, and the vibes I received.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});
  @override
  ConsumerState<FriendsScreen> createState() => _FriendsState();
}

class _FriendsState extends ConsumerState<FriendsScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  final _sentNow = <String>{};

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _toast(String key, [Map<String, String> vars = const {}]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(ref.read(copyProvider).t(key, vars))));
  }

  Future<void> _add() async {
    if (_code.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final f = await ref.read(socialServiceProvider).add(_code.text);
      _code.clear();
      ref.invalidate(socialSnapshotProvider);
      _toast('social.added', {'item': f.profile.nickname.isEmpty ? f.profile.catName : f.profile.nickname});
    } catch (e) {
      _toast(socialErrorKey(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _vibe(Friend f) async {
    final kind = await showModalBottomSheet<String>(context: context, builder: (_) => _VibePicker(friend: f));
    if (kind == null) return;
    try {
      await ref.read(socialServiceProvider).sendVibe(f.profile.code, kind);
      setState(() => _sentNow.add(f.profile.code));
      _toast('social.vibe.sent', {'item': f.profile.catName});
    } catch (e) {
      if (e is ApiError && e.code == 'VIBE_ALREADY_SENT') setState(() => _sentNow.add(f.profile.code));
      _toast(socialErrorKey(e));
    }
  }

  Future<void> _remove(Friend f) async {
    final copy = ref.read(copyProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(copy.t('social.remove.title', {'item': f.profile.nickname.isEmpty ? f.profile.catName : f.profile.nickname})),
        content: Text(copy.t('social.remove.body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(copy.t('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(copy.t('social.remove.yes'), style: const TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(socialServiceProvider).remove(f.profile.code);
      ref.invalidate(socialSnapshotProvider);
    } catch (e) {
      _toast(socialErrorKey(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final snap = ref.watch(socialSnapshotProvider);
    return Scaffold(
      backgroundColor: DS.cardCat,
      appBar: AppBar(title: Text(copy.t('social.title')), backgroundColor: DS.cardCat),
      body: snap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const EmojiArt('connection/people_search', size: 72),
              const SizedBox(height: 12),
              Text(copy.t(socialErrorKey(e)), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontSize: 16)),
              const SizedBox(height: 16),
              ChunkyButton(label: copy.t('common.retry'), expand: false, onPressed: () => ref.invalidate(socialSnapshotProvider)),
            ]),
          ),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(socialSnapshotProvider);
            await ref.read(socialSnapshotProvider.future);
          },
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            _MyCard(me: s.me),
            const SizedBox(height: 12),
            RoundCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(copy.t('social.add.title'), style: const TextStyle(color: DS.textDeep, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 12,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(hintText: copy.t('social.add.hint'), counterText: '', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                ChunkyButton(label: copy.t('social.add.button'), emoji: 'connection/people_hugging', onPressed: _busy ? null : _add),
              ]),
            ),
            if (s.vibes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Inbox(vibes: s.vibes),
            ],
            const SizedBox(height: 16),
            Text(copy.t('social.friends', {'n': toPersianDigits('${s.friends.length}')}), style: const TextStyle(color: DS.textDeep, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (s.friends.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const EmojiArt('connection/teddy_bear', size: 64),
                  const SizedBox(height: 8),
                  Text(copy.t('social.empty'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textSecondary)),
                ]),
              )
            else
              for (final f in s.friends)
                _FriendTile(
                  friend: _sentNow.contains(f.profile.code) ? f.copyWith(vibedToday: true) : f,
                  onVibe: _vibe,
                  onRemove: _remove,
                ),
            const SizedBox(height: 12),
            Text(copy.t('social.private'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textMuted, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

/// A friend's cat drawn from the look they published.
class FriendCat extends ConsumerWidget {
  const FriendCat({super.key, required this.profile, this.size = 64});
  final SocialProfile profile;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = CatVisualState(
      fur: CatFur.values.where((f) => f.name == profile.fur).firstOrNull ?? CatFur.orangeCream,
      stage: CatStage.values.where((s) => s.name == profile.stage).firstOrNull ?? CatStage.kitten,
      hue: profile.hue,
    );
    return SizedBox(width: size, height: size, child: ExcludeSemantics(child: FittedBox(child: ref.watch(catRendererProvider).build(context, state))));
  }
}

class _MyCard extends ConsumerWidget {
  const _MyCard({required this.me});
  final SocialProfile me;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final pretty = me.code.length == 8 ? '${me.code.substring(0, 4)}-${me.code.substring(4)}' : me.code;
    return RoundCard(
      child: Row(children: [
        const SizedBox(width: 90, height: 90, child: FittedBox(child: SizedBox(width: 200, height: 200, child: CatView()))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(copy.t('social.my_code'), style: const TextStyle(color: DS.textSecondary)),
            Semantics(
              label: copy.t('social.my_code'),
              value: me.code.split('').join(' '),
              child: Text(pretty, textDirection: TextDirection.ltr, style: const TextStyle(color: DS.textDeep, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 4, children: [
              IconButton(
                tooltip: copy.t('social.copy'),
                icon: const Icon(Icons.copy_rounded, color: DS.premiumBadge),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: me.code));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('social.copied'))));
                },
              ),
              IconButton(
                tooltip: copy.t('social.share'),
                icon: const Icon(Icons.share_rounded, color: DS.premiumBadge),
                onPressed: () => unawaited(SharePlus.instance.share(ShareParams(text: copy.t('social.share.text', {'item': pretty})))),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  const _FriendTile({required this.friend, required this.onVibe, required this.onRemove});
  final Friend friend;
  final void Function(Friend) onVibe;
  final void Function(Friend) onRemove;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final p = friend.profile;
    final title = p.nickname.isEmpty ? p.catName : p.nickname;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RoundCard(
        semanticLabel: copy.t('social.friend.semantics', {'item': title, 'cat': p.catName}),
        child: Row(children: [
          FriendCat(profile: p),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DS.textDeep, fontSize: 16, fontWeight: FontWeight.w800)),
              if (p.nickname.isNotEmpty)
                Text(copy.t('social.friend.cat', {'item': p.catName}), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DS.textSecondary)),
            ]),
          ),
          if (friend.vibedToday)
            Semantics(
              label: copy.t('social.vibe.done'),
              child: const Padding(padding: EdgeInsets.all(8), child: EmojiArt('hearts/two_hearts', size: 32)),
            )
          else
            IconButton(
              tooltip: copy.t('social.vibe.send'),
              icon: const EmojiArt('hearts/sparkling_heart', size: 32),
              onPressed: () => onVibe(friend),
            ),
          PopupMenuButton<String>(
            tooltip: copy.t('social.more'),
            onSelected: (_) => onRemove(friend),
            itemBuilder: (_) => [PopupMenuItem(value: 'remove', child: Text(copy.t('social.remove.yes')))],
          ),
        ]),
      ),
    );
  }
}

class _VibePicker extends ConsumerWidget {
  const _VibePicker({required this.friend});
  final Friend friend;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(copy.t('social.vibe.pick', {'item': friend.profile.catName}), textAlign: TextAlign.center,
              style: const TextStyle(color: DS.textDeep, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
            for (final k in VibeKind.all)
              Semantics(
                button: true,
                label: copy.t('social.vibe.${k.key}'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(DS.radiusHomeCard),
                  onTap: () => Navigator.pop(context, k.key),
                  child: Container(
                    width: 96,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: DS.cardCat, borderRadius: BorderRadius.circular(DS.radiusHomeCard)),
                    child: Column(children: [
                      EmojiArt(k.icon, size: 44),
                      const SizedBox(height: 4),
                      ExcludeSemantics(child: Text(copy.t('social.vibe.${k.key}'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontSize: 13))),
                    ]),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _Inbox extends ConsumerStatefulWidget {
  const _Inbox({required this.vibes});
  final List<ReceivedVibe> vibes;
  @override
  ConsumerState<_Inbox> createState() => _InboxState();
}

class _InboxState extends ConsumerState<_Inbox> {
  @override
  void initState() {
    super.initState();
    if (widget.vibes.any((v) => v.unread)) {
      // seen on screen → read on the server; failures are harmless (they stay highlighted next time)
      unawaited(ref.read(socialServiceProvider).markRead().catchError((_) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(copy.t('social.inbox'), style: const TextStyle(color: DS.textDeep, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      for (final v in widget.vibes.take(20))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RoundCard(
            color: v.unread ? DS.lockYellow : DS.card,
            child: Row(children: [
              EmojiArt(VibeKind.of(v.kind).icon, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  copy.t('social.inbox.item', {'item': v.fromNickname.isEmpty ? v.fromCatName : v.fromNickname, 'vibe': copy.t('social.vibe.${VibeKind.of(v.kind).key}')}),
                  style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}
