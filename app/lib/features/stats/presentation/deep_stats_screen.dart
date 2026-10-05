import '../../goals/domain/goal_title.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../core_loop_providers.dart';
import '../domain/insights.dart';
import 'charts/charts.dart';

final insightsServiceProvider = Provider<InsightsService>((ref) => InsightsService(ref.watch(databaseProvider)));

final _rangeProvider = NotifierProvider<_RangeNotifier, StatsRange>(_RangeNotifier.new);

class _RangeNotifier extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.week;
  void set(StatsRange r) => state = r;
}

final insightsProvider = FutureProvider.autoDispose<Insights>((ref) {
  ref.watch(todayHabitsProvider); // refresh when habit logs change
  return ref.watch(insightsServiceProvider).compute(ref.watch(_rangeProvider), ref.watch(todayProvider));
});

/// Premium mood chart, habit heatmap, best weekday and descriptive habit↔mood hints. Fully local.
class DeepStatsScreen extends ConsumerStatefulWidget {
  const DeepStatsScreen({super.key});
  @override
  ConsumerState<DeepStatsScreen> createState() => _DeepStatsState();
}

class _DeepStatsState extends ConsumerState<DeepStatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _track());
  }

  void _track() => unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.statsViewed, {'range': ref.read(_rangeProvider).name}));

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final range = ref.watch(_rangeProvider);
    final theme = Theme.of(context);
    final data = ref.watch(insightsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('stats.deep.title'))),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        SegmentedButton<StatsRange>(
          segments: [
            ButtonSegment(value: StatsRange.week, label: Text(copy.t('stats.week'))),
            ButtonSegment(value: StatsRange.month, label: Text(copy.t('stats.month'))),
          ],
          selected: {range},
          onSelectionChanged: (s) {
            ref.read(_rangeProvider.notifier).set(s.first);
            _track();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        data.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: CircularProgressIndicator())),
          error: (_, _) => Text(copy.t('error.generic')),
          data: (i) {
            final hasMood = i.mood.any((p) => p.mood != null);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(copy.t('stats.mood.title'), style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (!hasMood)
                EmptyState(message: copy.t('stats.mood.empty'))
              else
                Semantics(
                  label: copy.t('stats.mood.title'),
                  child: MoodLineChart(points: i.mood, color: AppColors.orangeDark, gridColor: theme.colorScheme.outlineVariant),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(copy.t('stats.heatmap.title'), style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (i.heat.isEmpty)
                EmptyState(message: copy.t('stats.habits.empty'))
              else
                for (final r in i.heat) ...[
                  Text(goalTitle(copy, r.habit.goalKey ?? r.habit.templateKey, r.habit.title), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  HabitHeatmap(rows: [r], on: AppColors.turquoiseDark, off: theme.colorScheme.surfaceContainerHighest, cell: i.days.length > 10 ? 8 : 14),
                  const SizedBox(height: AppSpacing.sm),
                ],
              const SizedBox(height: AppSpacing.md),
              if (i.bestWeekday != null)
                Card(child: ListTile(leading: const Icon(Icons.calendar_today_outlined), title: Text(copy.t('stats.best_day', {'item': JalaliFormatter.weekdayNames[i.bestWeekday!]})))),
              for (final c in i.correlations.take(3))
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.insights_outlined),
                    title: Text(copy.t('stats.correlation', {'habit': goalTitle(copy, c.habit.goalKey ?? c.habit.templateKey, c.habit.title)})),
                  ),
                ),
              if (i.bestWeekday == null && i.correlations.isEmpty)
                Padding(padding: const EdgeInsets.all(AppSpacing.sm), child: Text(copy.t('stats.insights.more_data'), style: theme.textTheme.bodySmall)),
            ]);
          },
        ),
      ]),
    );
  }
}
