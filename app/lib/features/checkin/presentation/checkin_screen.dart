import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../core_loop_providers.dart';
import '../domain/checkin_service.dart';

/// Modal check-in: five moods, optional note, kind reply from the cat.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});
  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  int? _mood;
  final _note = TextEditingController();
  CheckinResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  static const _icons = [Icons.sentiment_very_dissatisfied, Icons.sentiment_dissatisfied, Icons.sentiment_neutral, Icons.sentiment_satisfied, Icons.sentiment_very_satisfied];

  Future<void> _submit() async {
    if (_mood == null || _busy) return;
    setState(() => _busy = true);
    final r = await ref.read(checkinServiceProvider).submit(_mood!, note: _note.text);
    if (_mood! <= 2) {
      ref.read(lowMoodSessionProvider.notifier).mark();
    }
    if (!mounted) return;
    setState(() {
      _result = r;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final done = _result;
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('checkin.title')), leading: IconButton(icon: const Icon(Icons.close), tooltip: copy.t('common.close'), onPressed: () => context.pop())),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: done != null ? _reply(copy, done) : _form(copy),
      ),
    );
  }

  Widget _reply(dynamic copy, CheckinResult r) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(copy.t('checkin.reply.${r.moodLevel}'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Text(copy.t('checkin.done'), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        if (r.showSafetyCard) ...[
          OutlinedButton(onPressed: () => context.pushReplacement(Routes.safety), child: Text(copy.t('checkin.low_mood_card.action'))),
          const SizedBox(height: AppSpacing.sm),
        ],
        FilledButton(onPressed: () => context.pop(), child: Text(copy.t('common.done'))),
      ]);

  Widget _form(dynamic copy) => ListView(children: [
        Text(copy.t('checkin.prompt'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        // Wrap, not Row: at large text scales the five moods flow onto a second line instead of overflowing.
        Wrap(alignment: WrapAlignment.spaceEvenly, runSpacing: AppSpacing.sm, children: [
          for (var i = 1; i <= 5; i++)
            Semantics(
              button: true,
              selected: _mood == i,
              label: copy.t('checkin.mood.$i'),
              child: InkResponse(
                onTap: () => setState(() => _mood = i),
                radius: 32,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_icons[i - 1], size: 40, color: _mood == i ? AppColors.orangeDark : AppColors.inkSoft),
                    Text(copy.t('checkin.mood.$i'), style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ),
              ),
            ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _note,
          maxLength: 1000,
          maxLines: 3,
          decoration: InputDecoration(hintText: copy.t('checkin.note.hint'), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: _mood == null || _busy ? null : _submit, child: Text(copy.t('checkin.submit'))),
      ]);
}
