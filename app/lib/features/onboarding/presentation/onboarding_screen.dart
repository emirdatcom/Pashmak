import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../cat/presentation/cat_view.dart';
import '../../core_loop_providers.dart';
import '../../monetization/domain/monetization_service.dart';
import '../../monetization/monetization_providers.dart';
import '../../settings/settings_providers.dart';
import '../domain/onboarding_service.dart';

/// Resume only once per process: pressing "back" to step 1 must not bounce forward again.
class OnboardingResumed extends Notifier<bool> {
  @override
  bool build() => false;
  void mark() => state = true;
  void reset() => state = false;
}

final onboardingResumedProvider = NotifierProvider<OnboardingResumed, bool>(OnboardingResumed.new);

/// `/onboarding/:step` (1..4). Progress is stored, so a killed app continues from the same step.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.step});
  final int step;
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  String? _nameError;
  Map<String, int?> _habits = {};
  bool _busy = false;
  bool _notifAsked = false;
  bool _notifGranted = false;
  String? _trialMessage;
  bool _catNameChanged = false;

  int get step => widget.step.clamp(1, 4);

  @override
  void initState() {
    super.initState();
    // Providers must not change during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_init()));
  }

  Future<void> _init() async {
    final svc = ref.read(onboardingServiceProvider);
    if (!ref.read(onboardingResumedProvider)) {
      ref.read(onboardingResumedProvider.notifier).mark();
      await svc.trackInstallOnce();
      final saved = await svc.currentStep();
      if (saved > step && mounted) {
        context.go(Routes.onboardingStep(saved));
        return;
      }
    }
    await svc.setStep(step);
    unawaited(svc.trackStep(step));
    _habits = await svc.loadSelection();
    final saved = await svc.savedCatName();
    _name.text = saved.isEmpty ? svc.defaultCatName : saved;
    if (ref.read(entitlementRepositoryProvider) != null) unawaited(ref.read(outboxWorkerProvider).runDue()); // e.g. a pending account deletion
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _go(int s) => context.go(Routes.onboardingStep(s));

  Future<void> _submitName() async {
    final copy = ref.read(copyProvider);
    final svc = ref.read(onboardingServiceProvider);
    final value = _name.text.trim();
    final check = checkCatName(value, ref.read(nameBlocklistProvider));
    if (check != NameCheck.ok) {
      setState(() => _nameError = copy.t(switch (check) {
            NameCheck.empty => 'onboarding.name.error.empty',
            NameCheck.tooLong => 'onboarding.name.error.long',
            _ => 'onboarding.name.error.blocked',
          }));
      return;
    }
    await svc.saveCatName(value);
    _catNameChanged = value != svc.defaultCatName;
    ref.read(catNameProvider.notifier).set(value == svc.defaultCatName ? '' : value);
    _go(3);
  }

  Future<void> _toggleHabit(String key, bool on, int? defaultReminder) async {
    setState(() {
      if (on) {
        if (_habits.length < OnboardingService.maxHabits) _habits[key] = defaultReminder;
      } else {
        _habits.remove(key);
      }
    });
    await ref.read(onboardingServiceProvider).saveSelection(_habits);
  }

  Future<void> _pickReminder(String key) async {
    final current = _habits[key] ?? 9 * 60;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60));
    if (t == null) return;
    setState(() => _habits[key] = t.hour * 60 + t.minute);
    await ref.read(onboardingServiceProvider).saveSelection(_habits);
  }

  Future<void> _askNotif(bool allow) async {
    var granted = false;
    if (allow) granted = await ref.read(notificationServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() {
      _notifAsked = true;
      _notifGranted = granted;
    });
  }

  Future<void> _trial() async {
    setState(() => _busy = true);
    final o = await ref.read(monetizationServiceProvider).startTrial();
    if (!mounted) return;
    if (o == TrialOutcome.alreadyUsed) {
      _trialMessage = ref.read(copyProvider).t('paywall.trial_used');
    }
    setState(() => _busy = false);
    await _finish();
  }

  Future<void> _finish() async {
    final svc = ref.read(onboardingServiceProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    await svc.complete(habits: _habits, notifPermission: _notifGranted, catNameChanged: _catNameChanged || (await svc.savedCatName()).isNotEmpty);
    await ref.read(notificationSchedulerProvider).replan();
    final copy = ref.read(copyProvider);
    ref.read(onboardingCompletedProvider.notifier).set(true); // router redirect → home
    messenger?.showSnackBar(SnackBar(content: Text(_trialMessage ?? copy.t('onboarding.done.welcome'))));
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final theme = Theme.of(context);
    Widget body;
    switch (step) {
      case 1:
        body = _page(children: [
          const Center(child: CatView()),
          const SizedBox(height: AppSpacing.lg),
          Text(copy.t('onboarding.welcome.title'), style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(copy.t('onboarding.welcome.body'), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(copy.t('disclaimer.onboarding'), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          TextButton(onPressed: _showPrivacy, child: Text(copy.t('onboarding.privacy_link'))),
          if (ref.watch(appConfigProvider).feature('phone_link'))
            TextButton(onPressed: () => context.push('${Routes.settings}/phone'), child: Text(copy.t('onboarding.restore_link'))),
        ], action: FilledButton(onPressed: () => _go(2), child: Text(copy.t('common.next'))));
      case 2:
        body = _page(children: [
          Text(copy.t('onboarding.name.title'), style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            maxLength: 16,
            decoration: InputDecoration(labelText: copy.t('onboarding.name.hint'), errorText: _nameError),
            onChanged: (_) => setState(() => _nameError = null),
            onSubmitted: (_) => _submitName(),
          ),
        ], action: FilledButton(onPressed: _submitName, child: Text(copy.t('common.next'))));
      case 3:
        final templates = (ref.watch(contentRepositoryProvider).entries('habit_templates') as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
        body = _page(children: [
          Text(copy.t('onboarding.habits.title'), style: theme.textTheme.headlineSmall),
          Text(copy.t('onboarding.habits.body')),
          const SizedBox(height: AppSpacing.sm),
          Text(copy.t('onboarding.habits.selected', {'n': toPersianDigits('${_habits.length}/${OnboardingService.maxHabits}')})),
          for (final t in templates)
            _habitTile(copy, t['key'] as String, (t['default_reminder_minutes'] as int?)),
        ], action: FilledButton(onPressed: _habits.isEmpty ? null : () => _go(4), child: Text(copy.t('common.next'))));
      default:
        body = _page(children: [
          if (!_notifAsked) ...[
            Text(copy.t('onboarding.notif.title'), style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(copy.t('onboarding.notif.body')),
          ] else ...[
            Text(copy.t('onboarding.trial.title'), style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(copy.t('onboarding.trial.body')),
          ],
        ], action: !_notifAsked
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                FilledButton(onPressed: () => _askNotif(true), child: Text(copy.t('onboarding.notif.allow'))),
                TextButton(onPressed: () => _askNotif(false), child: Text(copy.t('onboarding.notif.later'))),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                if (ref.watch(entitlementRepositoryProvider) != null && ref.watch(appConfigProvider).trialEnabled)
                  FilledButton(onPressed: _busy ? null : _trial, child: Text(copy.t('onboarding.trial.start'))),
                TextButton(onPressed: _busy ? null : _finish, child: Text(copy.t('onboarding.trial.later'))),
              ]));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && step > 1) _go(step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: step > 1 ? IconButton(tooltip: copy.t('common.back'), icon: const Icon(Icons.arrow_forward), onPressed: () => _go(step - 1)) : null,
          title: Text(copy.t('onboarding.step', {'n': toPersianDigits(step)}), style: theme.textTheme.bodyMedium),
        ),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _habitTile(dynamic copy, String key, int? defaultReminder) {
    final on = _habits.containsKey(key);
    final minutes = _habits[key];
    return CheckboxListTile(
      value: on,
      onChanged: (v) => _toggleHabit(key, v ?? false, defaultReminder),
      title: Text(copy.t('habit.template.$key.title')),
      subtitle: on && minutes != null ? Text('${copy.t('onboarding.habits.reminder')}: ${toPersianDigits(JalaliFormatter.time(minutes))}') : null,
      secondary: on ? IconButton(tooltip: copy.t('onboarding.habits.reminder'), icon: const Icon(Icons.alarm), onPressed: () => _pickReminder(key)) : null,
    );
  }

  Widget _page({required List<Widget> children, required Widget action}) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: ListView(children: children)),
          action,
        ]),
      );

  void _showPrivacy() {
    final copy = ref.read(copyProvider);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(copy.t('settings.privacy.title')),
        content: Text(copy.t('settings.privacy.body')),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(copy.t('common.close')))],
      ),
    );
  }
}
