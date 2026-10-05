import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../core_loop_providers.dart';
import '../../support/support_providers.dart';

String _date(DateTime d) => toPersianDigits(JalaliFormatter.date(LocalDay.fromDate(d)));

/// Calm "what now?" page when the trial ended (docs/60 §4): free vs premium, no pressure.
class TrialEndedScreen extends ConsumerWidget {
  const TrialEndedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(copy.t('paywall.trial_ended.title'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Text(copy.t('paywall.trial_ended.body')),
            const Spacer(),
            FilledButton(onPressed: () => context.pushReplacement(Routes.paywall('trial_end')), child: Text(copy.t('trial.banner.action'))),
            TextButton(onPressed: () => context.go(Routes.home), child: Text(copy.t('lock.later'))),
          ]),
        ),
      ),
    );
  }
}

/// After premium ended with more active habits than the free tier allows: choose which stay active.
/// The rest are only locked (never deleted); premium restores them.
class LockSelectionScreen extends ConsumerStatefulWidget {
  const LockSelectionScreen({super.key});
  @override
  ConsumerState<LockSelectionScreen> createState() => _LockSelectionState();
}

class _LockSelectionState extends ConsumerState<LockSelectionScreen> {
  List<Habit> _habits = const [];
  final Set<String> _keep = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ref.read(habitServiceProvider).activeHabits();
    final max = ref.read(appConfigProvider).freeActiveHabits;
    if (!mounted) return;
    setState(() {
      _habits = all;
      _keep
        ..clear()
        ..addAll(all.where((h) => !h.isLocked).take(max).map((h) => h.id));
      if (_keep.length < max) _keep.addAll(all.take(max).map((h) => h.id));
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final max = ref.watch(appConfigProvider).freeActiveHabits;
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('lock.title'))),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(copy.t('lock.body', {'n': toPersianDigits(max)}))),
              Expanded(
                child: ListView(children: [
                  for (final h in _habits)
                    CheckboxListTile(
                      value: _keep.contains(h.id),
                      title: Text(h.templateKey != null ? copy.t('habit.template.${h.templateKey}.title') : (h.title ?? '')),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          if (_keep.length < max) _keep.add(h.id);
                        } else {
                          _keep.remove(h.id);
                        }
                      }),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(copy.t('lock.selected', {'n': toPersianDigits('${_keep.length}/$max')}), textAlign: TextAlign.center),
                  FilledButton(
                    onPressed: () async {
                      await ref.read(habitServiceProvider).lockExcept(_keep);
                      if (context.mounted) context.go(Routes.home);
                    },
                    child: Text(copy.t('lock.confirm')),
                  ),
                ]),
              ),
            ]),
    );
  }
}

/// "My subscription": status from the signed state, never from a raw flag.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final s = ref.watch(premiumStatusProvider);
    final String text;
    if (!s.isPremium) {
      text = copy.t('sub.status.free');
    } else if (s.source == 'pending') {
      text = copy.t('sub.status.pending');
    } else if (s.inGrace) {
      text = copy.t('sub.status.grace');
    } else if (s.source == 'trial') {
      text = copy.t('sub.status.trial', {'date': s.endsAt == null ? '' : _date(s.endsAt!)});
    } else {
      text = copy.t('sub.status.premium', {'date': s.endsAt == null ? '' : _date(s.endsAt!)});
    }
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('sub.title'))),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: () => context.push(Routes.paywall('settings')), child: Text(copy.t('sub.upgrade'))),
          if (ref.watch(supportEnabledProvider)) TextButton(onPressed: () => context.push(Routes.support(source: 'subscription')), child: Text(copy.t('support.purchase_help'))),
        ]),
      ),
    );
  }
}

/// Home banner the day before the trial ends (docs/60 §4).
class TrialEndingBanner extends ConsumerWidget {
  const TrialEndingBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(premiumStatusProvider);
    final cfg = ref.watch(appConfigProvider);
    final now = ref.watch(clockProvider).now();
    final ends = s.source == 'trial' ? s.endsAt : null;
    if (ends == null) return const SizedBox.shrink();
    final dayOfTrial = cfg.trialDays - ends.difference(now).inDays; // 1-based, rounds toward the end
    if (dayOfTrial < cfg.trialReminderDay) return const SizedBox.shrink();
    final copy = ref.watch(copyProvider);
    return Card(
      color: AppColors.creamDeep,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(copy.t('paywall.trial_ending.title'), style: Theme.of(context).textTheme.titleSmall),
          Text(copy.t('paywall.trial_ending.body')),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: () => context.push(Routes.paywall('trial_end')), child: Text(copy.t('trial.banner.action'))),
          ),
        ]),
      ),
    );
  }
}
