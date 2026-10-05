import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../goals/domain/goal_recommender.dart';
import '../../goals/presentation/goal_screens.dart' show AreaIcon, goalAreas;

/// The questionnaire steps (docs/22 §5, steps 3–7), shared by onboarding and "retake from My care areas".
enum QuestionStep { energy, areas, answers, chronotype, time }

/// The "calm" question asks how often the mind is busy, so its answer is reversed: "often busy" means the
/// calm area *rarely* goes well. Stored answers always mean "how often it goes well".
AreaAnswer storedAnswerFor(String area, AreaAnswer uiAnswer) {
  if (area != 'calm') return uiAnswer;
  return switch (uiAnswer) { AreaAnswer.rarely => AreaAnswer.often, AreaAnswer.often => AreaAnswer.rarely, _ => AreaAnswer.sometimes };
}

class QuestionStepView extends ConsumerWidget {
  const QuestionStepView({super.key, required this.step, required this.profile, required this.onChanged});
  final QuestionStep step;
  final OnboardingProfile profile;
  final ValueChanged<OnboardingProfile> onChanged;

  OnboardingProfile _with({int? energy, List<String>? areas, Map<String, AreaAnswer>? answers, Chronotype? chrono, DailyTime? time}) => OnboardingProfile(
        energyLevel: energy ?? profile.energyLevel,
        areas: areas ?? profile.areas,
        areaAnswers: answers ?? profile.areaAnswers,
        chronotype: chrono ?? profile.chronotype,
        dailyTime: time ?? profile.dailyTime,
      );

  static const _energyIcons = [Icons.sentiment_very_dissatisfied, Icons.sentiment_dissatisfied, Icons.sentiment_neutral, Icons.sentiment_satisfied, Icons.sentiment_very_satisfied];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    Widget title(String key) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(copy.t(key), style: const TextStyle(color: DS.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, height: 1.5)));
    Widget choice(String label, bool on, VoidCallback tap, {IconData? icon, Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RoundCard(
            color: on ? DS.doneBg : DS.card,
            onTap: tap,
            semanticLabel: label,
            child: Row(children: [
              if (icon != null) ...[Icon(icon, color: color ?? DS.textPrimary), const SizedBox(width: 12)],
              Expanded(child: Text(label, style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 16))),
              Icon(on ? Icons.check_circle : Icons.circle_outlined, color: on ? DS.primaryGreen : DS.textSecondary),
            ]),
          ),
        );

    switch (step) {
      case QuestionStep.energy:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          title('onboarding.energy.title'),
          for (var i = 1; i <= 5; i++) choice(copy.t('onboarding.energy.$i'), profile.energyLevel == i, () => onChanged(_with(energy: i)), icon: _energyIcons[i - 1]),
        ]);
      case QuestionStep.areas:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          title('onboarding.areas.title'),
          Text(copy.t('onboarding.areas.body'), style: const TextStyle(color: DS.textSecondary)),
          const SizedBox(height: 8),
          for (final a in goalAreas)
            choice(copy.t('area.$a.name'), profile.areas.contains(a), () {
              final list = [...profile.areas];
              if (list.contains(a)) {
                list.remove(a);
              } else if (list.length < 4) {
                list.add(a);
              }
              onChanged(_with(areas: [for (final x in goalAreas) if (list.contains(x)) x]));
            }, icon: Icons.circle, color: DS.area(a)),
        ]);
      case QuestionStep.answers:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          title('onboarding.answers.title'),
          for (final a in profile.areas)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: RoundCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [AreaIcon(icon: null, area: a, size: 32), const SizedBox(width: 10), Expanded(child: Text(copy.t('onboarding.q.$a'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, height: 1.5)))]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    for (final ans in AreaAnswer.values)
                      ChoiceChip(
                        label: Text(copy.t('onboarding.answer.${ans.name}')),
                        selected: profile.areaAnswers[a] == storedAnswerFor(a, ans),
                        onSelected: (_) => onChanged(_with(answers: {...profile.areaAnswers, a: storedAnswerFor(a, ans)})),
                      ),
                  ]),
                ]),
              ),
            ),
        ]);
      case QuestionStep.chronotype:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          title('onboarding.chrono.title'),
          for (final c in Chronotype.values) choice(copy.t('onboarding.chrono.${c.name}'), profile.chronotype == c, () => onChanged(_with(chrono: c)), icon: switch (c) { Chronotype.morning => Icons.wb_sunny, Chronotype.night => Icons.nightlight, _ => Icons.contrast }),
        ]);
      case QuestionStep.time:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          title('onboarding.time.title'),
          for (final t in DailyTime.values) choice(copy.t('onboarding.time.${t.name}'), profile.dailyTime == t, () => onChanged(_with(time: t)), icon: Icons.timer_outlined),
        ]);
    }
  }
}
