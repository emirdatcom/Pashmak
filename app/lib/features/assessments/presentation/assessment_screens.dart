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
import '../domain/assessments.dart';

final assessmentStoreProvider = Provider<AssessmentStore>((ref) => AssessmentStore(ref.watch(databaseProvider), ref.watch(clockProvider)));
final assessmentResultsProvider = StreamProvider<List<AssessmentResult>>((ref) => ref.watch(assessmentStoreProvider).watch());

/// `/assessments`: the self-checks with the latest result of each.
class AssessmentsScreen extends ConsumerWidget {
  const AssessmentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final results = ref.watch(assessmentResultsProvider).value ?? const [];
    return Scaffold(
      backgroundColor: DS.bgSettings,
      appBar: AppBar(title: Text(copy.t('assess.title')), backgroundColor: DS.bgSettings),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(copy.t('assess.intro'), style: const TextStyle(color: DS.textSecondary, height: 1.6)),
        const SizedBox(height: 14),
        for (final a in Assessment.all) ...[
          RoundCard(
            semanticLabel: copy.t('assess.${a.key}.name'),
            onTap: () => context.push(Routes.assessment(a.key)),
            child: Row(children: [
              EmojiArt(a.icon, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(copy.t('assess.${a.key}.name'), style: const TextStyle(color: DS.textDeep, fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(copy.t('assess.${a.key}.desc'), style: const TextStyle(color: DS.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    switch (results.where((r) => r.key == a.key).firstOrNull) {
                      final r? => copy.t('assess.last', {'date': JalaliFormatter.dayMonth(LocalDay.parse(r.day)), 'n': r.score}),
                      null => copy.t('assess.never'),
                    },
                    style: const TextStyle(color: DS.textMuted, fontSize: 13),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Text(copy.t('assess.repeat'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textMuted, fontSize: 13)),
      ]),
    );
  }
}

/// `/assessments/:key`: one question per page, then the result (with the safety resources when needed).
class AssessmentRunScreen extends ConsumerStatefulWidget {
  const AssessmentRunScreen({super.key, required this.assessmentKey});
  final String assessmentKey;
  @override
  ConsumerState<AssessmentRunScreen> createState() => _AssessmentRunState();
}

class _AssessmentRunState extends ConsumerState<AssessmentRunScreen> {
  late final Assessment _a = Assessment.byKey(widget.assessmentKey);
  late final List<int?> _answers = List.filled(_a.questions, null);
  int _q = 0;
  int? _score;
  bool _safety = false;

  Future<void> _answer(int v) async {
    setState(() => _answers[_q] = v);
    if (_q < _a.questions - 1) {
      setState(() => _q++);
      return;
    }
    final answers = [for (final x in _answers) x!];
    final score = _a.score(answers);
    await ref.read(assessmentStoreProvider).save(_a.key, score, ref.read(todayProvider));
    if (mounted) {
      setState(() {
        _score = score;
        _safety = _a.needsSafety(answers);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    return PopScope(
      canPop: _score != null || _q == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _q--);
      },
      child: Scaffold(
        backgroundColor: DS.bgSettings,
        appBar: AppBar(title: Text(copy.t('assess.${_a.key}.name')), backgroundColor: DS.bgSettings),
        body: SafeArea(child: _score == null ? _question(copy) : _result(copy, _score!)),
      ),
    );
  }

  Widget _question(dynamic copy) => ListView(padding: const EdgeInsets.all(20), children: [
        LinearProgressIndicator(value: (_q + 1) / _a.questions, minHeight: 8, borderRadius: BorderRadius.circular(4), color: DS.primaryGreen, backgroundColor: DS.neutralButton),
        const SizedBox(height: 8),
        Text(copy.t('assess.progress', {'n': '${toPersianDigits(_q + 1)} / ${toPersianDigits(_a.questions)}'}), style: const TextStyle(color: DS.textMuted)),
        const SizedBox(height: 20),
        Text(copy.t('assess.${_a.key}.stem'), style: const TextStyle(color: DS.textSecondary, fontSize: 15)),
        const SizedBox(height: 8),
        Semantics(header: true, child: Text(copy.t('assess.${_a.key}.q.${_q + 1}'), style: const TextStyle(color: DS.textDeep, fontSize: 20, fontWeight: FontWeight.w800, height: 1.5))),
        const SizedBox(height: 20),
        for (final v in _a.optionValues) ...[
          ChunkyButton(
            label: copy.t('assess.${_a.key}.opt.$v'),
            color: _answers[_q] == v ? DS.primaryGreen : DS.card,
            edgeColor: _answers[_q] == v ? DS.primaryGreenEdge : DS.neutralButtonEdge,
            textColor: DS.textDeep,
            onPressed: () => _answer(v),
          ),
          const SizedBox(height: 10),
        ],
      ]);

  Widget _result(dynamic copy, int score) {
    final band = _a.band(score);
    final history = (ref.watch(assessmentResultsProvider).value ?? const []).where((r) => r.key == _a.key).take(6).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      if (_safety) ...[
        RoundCard(
          color: DS.doneBg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(copy.t('assess.safety'), style: const TextStyle(color: DS.textDeep, fontSize: 16, fontWeight: FontWeight.w700, height: 1.6)),
            const SizedBox(height: 12),
            ChunkyButton(label: copy.t('assess.safety.cta'), onPressed: () => context.push(Routes.safety)),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      Center(child: EmojiArt(_a.icon, size: 80)),
      const SizedBox(height: 12),
      Text(copy.t('assess.score', {'n': score, 'item': toPersianDigits(_a.maxScore)}), textAlign: TextAlign.center, style: const TextStyle(color: DS.textDeep, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Text(copy.t('assess.${_a.key}.band.${band.name}'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontSize: 16, height: 1.6)),
      if (band.suggestHelp) ...[
        const SizedBox(height: 12),
        RoundCard(child: Text(copy.t('assess.help'), style: const TextStyle(color: DS.textPrimary, height: 1.6))),
      ],
      const SizedBox(height: 12),
      Text(copy.t('assess.not_diagnosis'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textMuted, fontSize: 13)),
      if (history.length > 1) ...[
        const SizedBox(height: 20),
        Text(copy.t('assess.history'), style: const TextStyle(color: DS.textDeep, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final r in history)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 90, child: Text(JalaliFormatter.dayMonth(LocalDay.parse(r.day)), style: const TextStyle(color: DS.textSecondary))),
              Expanded(
                child: LinearProgressIndicator(
                  value: r.score / _a.maxScore,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                  color: DS.premiumBadge,
                  backgroundColor: DS.neutralButton,
                ),
              ),
              SizedBox(width: 44, child: Text(toPersianDigits(r.score), textAlign: TextAlign.end, style: const TextStyle(color: DS.textDeep, fontWeight: FontWeight.w700))),
            ]),
          ),
      ],
      const SizedBox(height: 20),
      ChunkyButton(label: copy.t('assess.done'), onPressed: () => context.canPop() ? context.pop() : context.go(Routes.assessments)),
    ]);
  }
}
