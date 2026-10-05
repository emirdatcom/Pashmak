import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../home/presentation/home_screen.dart';
import '../../settings/settings_providers.dart';

/// MVP stats: streak, this Jalali week and per-habit completions. Deeper charts are premium (phase 2).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final stats = ref.watch(weekStatsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('stats.title'))),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(message: copy.t('error.generic'), retryLabel: copy.t('common.retry'), onRetry: () => ref.invalidate(weekStatsProvider)),
        data: (s) => ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
          Row(children: [
            Expanded(child: _Tile(icon: Icons.local_fire_department_outlined, text: copy.t('stats.streak.current', {'n': s.streak.current}))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _Tile(icon: Icons.emoji_events_outlined, text: copy.t('stats.streak.longest', {'n': s.streak.longest}))),
          ]),
          const SizedBox(height: AppSpacing.md),
          Text(copy.t('stats.week'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (final d in s.days)
              Semantics(
                label: '${JalaliFormatter.weekday(d.day)}${d.active ? '' : ''}',
                child: Column(children: [
                  Text(JalaliFormatter.weekday(d.day).substring(0, 1), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: d.active ? AppColors.orangeDark : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: d.active ? const Icon(Icons.check, size: 16, color: Colors.white) : (d.isToday ? const Icon(Icons.circle, size: 8) : null),
                  ),
                ]),
              ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Text(copy.t('stats.habits.title'), style: Theme.of(context).textTheme.titleMedium),
          if (s.perHabit.isEmpty) ConstrainedBox(constraints: const BoxConstraints(minHeight: 160), child: EmptyState(message: copy.t('stats.habits.empty'))),
          for (final h in s.perHabit)
            ListTile(
              title: Text(h.habit.templateKey != null ? copy.t('habit.template.${h.habit.templateKey}.title') : (h.habit.title ?? '')),
              trailing: Text(toPersianDigits(h.count)),
            ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.lock_outline),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(copy.t('stats.locked'))),
                ]),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () async {
                      final ok = await passGate(context, ref, 'stats_deep');
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('settings.placeholder'))));
                      }
                    },
                    child: Text(copy.t('stats.deep.cta')),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(children: [Icon(icon, color: AppColors.orangeDark), const SizedBox(height: 4), Text(text, textAlign: TextAlign.center)]),
        ),
      );
}
