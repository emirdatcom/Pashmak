import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../domain/journal.dart';

final journalRepositoryProvider = Provider<JournalRepository>((ref) => JournalRepository(ref.watch(databaseProvider)));
final journalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) => ref.watch(journalRepositoryProvider).watch());

/// `/journal`: every written entry (structured journals and prompt exercises), newest first, and the templates to start
/// a new one.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final entries = ref.watch(journalEntriesProvider).value ?? const [];
    final premium = ref.watch(premiumProvider);
    return Scaffold(
      backgroundColor: DS.cardCat,
      appBar: AppBar(title: Text(copy.t('journal.title')), backgroundColor: DS.cardCat),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Text(copy.t('journal.pick'), style: const TextStyle(color: DS.textDeep, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final t in JournalTemplate.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RoundCard(
              semanticLabel: copy.t('journal.${t.key}.name'),
              onTap: () async {
                if (t.premium && !premium && !await passGate(context, ref, 'premium_exercise')) return;
                if (context.mounted) unawaited(context.push(Routes.journalWrite(t.key)));
              },
              child: Row(children: [
                EmojiArt(t.icon, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(copy.t('journal.${t.key}.name'), style: const TextStyle(color: DS.textDeep, fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(copy.t('journal.${t.key}.desc'), style: const TextStyle(color: DS.textSecondary)),
                  ]),
                ),
                if (t.premium && !premium) const EmojiArt('misc/padlock', size: 24, fallback: 'ui/lock'),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        Text(copy.t('journal.title'), style: const TextStyle(color: DS.textDeep, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Padding(padding: const EdgeInsets.all(24), child: Text(copy.t('journal.empty'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textSecondary)))
        else
          for (final e in entries) _EntryCard(entry: e),
        const SizedBox(height: 12),
        Text(copy.t('journal.private'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textMuted, fontSize: 13)),
      ]),
    );
  }
}

String _entryTitle(dynamic copy, JournalEntry e) =>
    e.template != null ? copy.t('journal.${e.template!.key}.name') as String : copy.t('exercise.${e.exerciseKey}.name') as String;

String _preview(dynamic copy, JournalEntry e) {
  if (e.text != null) return e.text!;
  for (final f in e.template!.fields) {
    final v = e.answers[f.key];
    if (v is String && v.trim().isNotEmpty) return v;
    if (v is List && v.isNotEmpty) return v.join(' · ');
  }
  return '';
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry});
  final JournalEntry entry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RoundCard(
        semanticLabel: _entryTitle(copy, entry),
        onTap: () => _open(context, ref),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_entryTitle(copy, entry), style: const TextStyle(color: DS.textDeep, fontWeight: FontWeight.w800))),
            Text(JalaliFormatter.dayMonth(LocalDay.parse(entry.localDay)), style: const TextStyle(color: DS.textMuted, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Text(_preview(copy, entry), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DS.textSecondary, height: 1.5)),
        ]),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) {
    final copy = ref.read(copyProvider);
    final e = entry;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DS.sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusSheet))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 20, 20, 16), children: [
            Text(_entryTitle(copy, e), style: const TextStyle(color: DS.textDeep, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(JalaliFormatter.weekdayDate(LocalDay.parse(e.localDay)), style: const TextStyle(color: DS.textMuted)),
            const SizedBox(height: 14),
            if (e.text != null)
              Text(e.text!, style: const TextStyle(color: DS.textPrimary, height: 1.7, fontSize: 15))
            else
              for (final f in e.template!.fields)
                if (e.answers[f.key] case final v?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(copy.t('journal.${e.template!.key}.${f.key}'), style: const TextStyle(color: DS.textSecondary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        switch (f.type) {
                          JournalFieldType.intensity => copy.t('journal.intensity', {'n': v}),
                          JournalFieldType.choice => copy.t('journal.${e.template!.key}.${f.key}.opt.$v'),
                          JournalFieldType.list3 => [for (final x in (v as List)) if ('$x'.trim().isNotEmpty) '• $x'].join('\n'),
                          JournalFieldType.text => '$v',
                        },
                        style: const TextStyle(color: DS.textPrimary, height: 1.7, fontSize: 15),
                      ),
                    ]),
                  ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(content: Text(copy.t('journal.delete.confirm')), actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(copy.t('common.cancel'))),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: Text(copy.t('journal.delete'))),
                  ]),
                );
                if (ok == true) {
                  await ref.read(journalRepositoryProvider).deleteText(e.sessionId);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              label: Text(copy.t('journal.delete'), style: const TextStyle(color: AppColors.danger)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// `/journal/write/:template`: one question per page, progress dots, then save (energy like any exercise).
class JournalWriteScreen extends ConsumerStatefulWidget {
  const JournalWriteScreen({super.key, required this.templateKey});
  final String templateKey;
  @override
  ConsumerState<JournalWriteScreen> createState() => _JournalWriteState();
}

class _JournalWriteState extends ConsumerState<JournalWriteScreen> {
  late final JournalTemplate _t = JournalTemplate.all.firstWhere((t) => t.key == widget.templateKey);
  final _answers = <String, Object?>{};
  final _text = <String, TextEditingController>{};
  int _page = 0;
  bool _busy = false;

  TextEditingController _ctl(String k) => _text.putIfAbsent(k, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _collect() {
    for (final f in _t.fields) {
      if (f.type == JournalFieldType.text) _answers[f.key] = _ctl(f.key).text.trim();
      if (f.type == JournalFieldType.list3) _answers[f.key] = [for (var i = 0; i < 3; i++) _ctl('${f.key}.$i').text.trim()];
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    _collect();
    final visible = {for (final f in _t.visible(_answers)) f.key};
    final svc = ref.read(exerciseServiceProvider);
    final id = await svc.start(_t.exerciseKey);
    await svc.complete(id, durationS: 0, journalText: encodeJournal(_t.key, {for (final e in _answers.entries) if (visible.contains(e.key)) e.key: e.value}));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(copyProvider).t('journal.saved'))));
    context.canPop() ? context.pop() : context.go(Routes.journal);
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    _collect();
    final fields = _t.visible(_answers);
    final page = _page.clamp(0, fields.length - 1);
    final f = fields[page];
    final last = page == fields.length - 1;
    final base = 'journal.${_t.key}.${f.key}';
    final hint = copy.has('$base.hint') ? copy.t('$base.hint') : '';
    Widget input() => switch (f.type) {
          JournalFieldType.text => TextField(
              controller: _ctl(f.key),
              maxLines: 7,
              minLines: 4,
              maxLength: 1000,
              autofocus: true,
              decoration: InputDecoration(hintText: hint.isEmpty ? null : hint, filled: true, fillColor: DS.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)),
            ),
          JournalFieldType.list3 => Column(children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _ctl('${f.key}.$i'),
                    maxLength: 200,
                    decoration: InputDecoration(
                      prefixText: '${toPersianDigits(i + 1)}. ',
                      hintText: i == 0 && hint.isNotEmpty ? hint : null,
                      counterText: '',
                      filled: true,
                      fillColor: DS.card,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    ),
                  ),
                ),
            ]),
          JournalFieldType.intensity => Column(children: [
              Text(copy.t('journal.intensity', {'n': (_answers[f.key] as int?) ?? 50}), style: const TextStyle(color: DS.textDeep, fontSize: 22, fontWeight: FontWeight.w800)),
              Slider(
                value: ((_answers[f.key] as int?) ?? 50).toDouble(),
                max: 100,
                divisions: 20,
                label: toPersianDigits((_answers[f.key] as int?) ?? 50),
                onChanged: (v) => setState(() => _answers[f.key] = v.round()),
              ),
            ]),
          JournalFieldType.choice => Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in f.options)
                ChoiceChip(label: Text(copy.t('$base.opt.$o')), selected: _answers[f.key] == o, onSelected: (_) => setState(() => _answers[f.key] = o)),
            ]),
        };
    return Scaffold(
      backgroundColor: DS.cardCat,
      appBar: AppBar(title: Text(copy.t('journal.${_t.key}.name')), backgroundColor: DS.cardCat),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < fields.length; i++)
              Container(
                width: i == page ? 22 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: i <= page ? DS.primaryGreen : DS.neutralButton, borderRadius: BorderRadius.circular(4)),
              ),
          ]),
          const SizedBox(height: 20),
          Center(child: EmojiArt(_t.icon, size: 72)),
          const SizedBox(height: 12),
          Text(copy.t(base), textAlign: TextAlign.center, style: const TextStyle(color: DS.textDeep, fontSize: 20, fontWeight: FontWeight.w800, height: 1.5)),
          const SizedBox(height: 16),
          input(),
          const SizedBox(height: 16),
          Row(children: [
            if (page > 0) ...[
              Expanded(child: ChunkyButton.neutral(label: copy.t('journal.back'), onPressed: () => setState(() => _page = page - 1))),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: ChunkyButton(
                label: copy.t(last ? 'journal.save' : 'journal.next'),
                onPressed: _busy ? null : () => last ? _save() : setState(() => _page = page + 1),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(copy.t('journal.private'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textMuted, fontSize: 13)),
        ]),
      ),
    );
  }
}
