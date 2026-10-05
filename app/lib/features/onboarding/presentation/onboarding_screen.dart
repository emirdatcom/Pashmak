import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/cat_renderer.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../goals/domain/goal_recommender.dart';
import '../../goals/presentation/goal_screens.dart' show AreaIcon;
import '../../monetization/domain/monetization_service.dart';
import '../../monetization/monetization_providers.dart';
import '../../notifications/data/notification_scheduler.dart' show NotifSettingKeys;
import '../../settings/settings_providers.dart';
import '../domain/onboarding_service.dart';
import 'question_steps.dart';

/// Resume only once per process: pressing "back" to step 1 must not bounce forward again.
class OnboardingResumed extends Notifier<bool> {
  @override
  bool build() => false;
  void mark() => state = true;
  void reset() => state = false;
}

final onboardingResumedProvider = NotifierProvider<OnboardingResumed, bool>(OnboardingResumed.new);

const _questionSteps = {3: QuestionStep.energy, 4: QuestionStep.areas, 5: QuestionStep.answers, 6: QuestionStep.chronotype, 7: QuestionStep.time};

/// `/onboarding/:step` (1..11): welcome, name, five questionnaire steps (skippable), the cat arrives, plan preview,
/// notifications, trial. Progress is stored, so a killed app continues from the same step (docs/22 §5).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.step});
  final int step;
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _userName = TextEditingController();
  final _catName = TextEditingController();
  String? _nameError;
  OnboardingProfile _profile = const OnboardingProfile();
  CatFur _fur = CatFur.orangeCream;
  String _trait = 'curious';
  List<GoalDef> _plan = [];
  final Set<String> _rejected = {};
  int _replaced = 0;
  int _seed = 0;
  int _morning = 8 * 60;
  int _evening = 21 * 60 + 30;
  bool _busy = false;
  bool _notifAsked = false;
  bool _notifGranted = false;
  String? _trialMessage;
  bool _catNameChanged = false;
  bool _ready = false;

  int get step => widget.step.clamp(1, OnboardingService.totalSteps);

  @override
  void initState() {
    super.initState();
    // Providers must not change during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_init()));
  }

  Future<void> _init() async {
    final svc = ref.read(onboardingServiceProvider);
    int? resumeAt;
    if (!ref.read(onboardingResumedProvider)) {
      ref.read(onboardingResumedProvider.notifier).mark();
      await svc.trackInstallOnce();
      final saved = await svc.currentStep();
      if (saved > step) resumeAt = saved;
    }
    if (resumeAt == null) {
      await svc.setStep(step);
      unawaited(svc.trackStep(step));
    }
    _profile = await svc.answers.load();
    _seed = stableHash(await ref.read(deviceIdentityProvider).installId());
    final db = ref.read(databaseProvider);
    _userName.text = await db.meta('user_name') ?? '';
    final saved = await svc.savedCatName();
    _catName.text = saved.isEmpty ? svc.defaultCatName : saved;
    final fur = await db.meta('cat_fur');
    _fur = CatFur.values.where((f) => f.name == fur).firstOrNull ?? CatFur.orangeCream;
    _trait = await db.meta('cat_trait') ?? 'curious';
    final keys = await svc.loadGoalSelection();
    final lib = {for (final g in ref.read(goalLibraryProvider)) g.key: g};
    _plan = [for (final k in keys) if (lib[k] != null) lib[k]!];
    if (ref.read(entitlementRepositoryProvider) != null) unawaited(ref.read(outboxWorkerProvider).runDue()); // e.g. a pending account deletion
    if (mounted) setState(() => _ready = true);
    // go_router may reuse this State for the next step, so the page is fully loaded before moving on.
    if (resumeAt != null && mounted) context.go(Routes.onboardingStep(resumeAt));
  }

  @override
  void dispose() {
    _userName.dispose();
    _catName.dispose();
    super.dispose();
  }

  void _go(int s) => context.go(Routes.onboardingStep(s));

  /// Next step; the per-area questions are skipped when no area was chosen.
  int _after(int s) => (s == 4 && _profile.areas.isEmpty) ? 6 : s + 1;
  int _before(int s) => (s == 6 && _profile.areas.isEmpty) ? 4 : s - 1;

  Future<void> _next() async {
    final svc = ref.read(onboardingServiceProvider);
    if (step >= 3 && step <= 7) await svc.answers.save(_profile);
    if (step == 4) await svc.trackAreas(_profile.areas);
    if (step == 7) await _buildPlan();
    _go(_after(step));
  }

  Future<void> _buildPlan() async {
    final svc = ref.read(onboardingServiceProvider);
    final cfg = ref.read(appConfigProvider);
    final count = svc.recommendCount(
        premiumOrTrial: ref.read(premiumProvider), free: cfg.recommendCountFree, trial: cfg.recommendCountTrial, freeActiveLimit: cfg.freeActiveHabits);
    _plan = ref.read(goalRecommenderProvider).recommend(_profile, count: count, seed: _seed);
    await svc.saveGoalSelection([for (final g in _plan) g.key]);
  }

  Future<void> _submitUserName() async {
    final svc = ref.read(onboardingServiceProvider);
    final v = _userName.text.trim();
    if (v.runes.length > 20) {
      setState(() => _nameError = ref.read(copyProvider).t('onboarding.name.error.long'));
      return;
    }
    await svc.saveUserName(v);
    _go(3);
  }

  Future<void> _submitArrival() async {
    final copy = ref.read(copyProvider);
    final svc = ref.read(onboardingServiceProvider);
    final value = _catName.text.trim();
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
    await svc.saveCatLook(fur: _fur, trait: _trait);
    _catNameChanged = value != svc.defaultCatName;
    ref.read(catNameProvider.notifier).set(value == svc.defaultCatName ? '' : value);
    ref.invalidate(catProfileProvider);
    _go(9);
  }

  Future<void> _savePlan() => ref.read(onboardingServiceProvider).saveGoalSelection([for (final g in _plan) g.key]);

  Future<void> _askNotif(bool allow) async {
    var granted = false;
    if (allow) granted = await ref.read(notificationServiceProvider).requestPermission();
    if (granted) {
      final db = ref.read(databaseProvider);
      await db.setSetting(NotifSettingKeys.morning, '$_morning');
      await db.setSetting(NotifSettingKeys.evening, '$_evening');
    }
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
    final rec = ref.read(goalRecommenderProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    await svc.complete(
      goals: [for (final g in _plan) PlannedGoal(g, rec.resolvedTimeOfDay(g, _profile.chronotype))],
      notifPermission: _notifGranted,
      catNameChanged: _catNameChanged || (await svc.savedCatName()).isNotEmpty,
      profile: _profile,
      replacedCount: _replaced,
    );
    await ref.read(notificationSchedulerProvider).replan();
    ref.invalidate(catProfileProvider);
    final copy = ref.read(copyProvider);
    ref.read(onboardingCompletedProvider.notifier).set(true); // router redirect → home
    messenger?.showSnackBar(SnackBar(content: Text(_trialMessage ?? copy.t('onboarding.done.welcome'))));
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final skippable = step >= 3 && step <= 7;
    Widget body;
    switch (step) {
      case 1:
        body = _page(children: [
          const SizedBox(height: 8),
          const Center(child: _Basket()),
          const SizedBox(height: AppSpacing.lg),
          Text(copy.t('onboarding.welcome.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(copy.t('onboarding.welcome.body'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          Text(copy.t('disclaimer.onboarding'), style: const TextStyle(color: DS.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          TextButton(onPressed: _showPrivacy, child: Text(copy.t('onboarding.privacy_link'))),
          if (ref.watch(appConfigProvider).feature('phone_link'))
            TextButton(onPressed: () => context.push('${Routes.settings}/phone'), child: Text(copy.t('onboarding.restore_link'))),
        ], action: ChunkyButton(onPressed: () => _go(2), label: copy.t('common.next')));
      case 2:
        body = _page(children: [
          Text(copy.t('onboarding.user_name.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback)),
          const SizedBox(height: 4),
          Text(copy.t('onboarding.user_name.body'), style: const TextStyle(color: DS.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          RoundCard(
            child: TextField(
              controller: _userName,
              maxLength: 20,
              decoration: InputDecoration(hintText: copy.t('onboarding.user_name.hint'), errorText: _nameError, border: InputBorder.none, counterText: ''),
              onChanged: (_) => setState(() => _nameError = null),
              onSubmitted: (_) => _submitUserName(),
            ),
          ),
        ], action: ChunkyButton(onPressed: _submitUserName, label: copy.t('common.next')));
      case >= 3 && <= 7:
        body = _page(
          children: [QuestionStepView(step: _questionSteps[step]!, profile: _profile, onChanged: (p) => setState(() => _profile = p))],
          action: ChunkyButton(onPressed: _next, label: copy.t('common.next')),
        );
      case 8:
        body = _page(children: [
          const Center(child: _Basket(open: true)),
          const SizedBox(height: 8),
          Text(copy.t('onboarding.arrival.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback), textAlign: TextAlign.center),
          Text(copy.t('onboarding.arrival.body'), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: Center(child: ref.watch(catRendererProvider).build(context, CatVisualState(fur: _fur, stage: CatStage.kitten)))),
          Text(copy.t('onboarding.fur.title'), style: const TextStyle(color: DS.textSecondary, fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final f in CatFur.values) ChoiceChip(label: Text(copy.t('onboarding.fur.${furKey(f)}')), selected: _fur == f, onSelected: (_) => setState(() => _fur = f)),
          ]),
          const SizedBox(height: 12),
          RoundCard(
            child: TextField(
              controller: _catName,
              maxLength: 16,
              decoration: InputDecoration(labelText: copy.t('onboarding.name.hint'), errorText: _nameError, border: InputBorder.none, counterText: ''),
              onChanged: (_) => setState(() => _nameError = null),
            ),
          ),
          const SizedBox(height: 8),
          Text(copy.t('onboarding.trait.title'), style: const TextStyle(color: DS.textSecondary, fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final t in const ['curious', 'kind', 'playful']) ChoiceChip(label: Text(copy.t('cat.trait.$t')), selected: _trait == t, onSelected: (_) => setState(() => _trait = t)),
          ]),
        ], action: ChunkyButton(onPressed: _submitArrival, label: copy.t('common.next')));
      case 9:
        body = _planPage(copy);
      case 10:
        body = _page(children: [
          Text(copy.t('onboarding.notif.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback)),
          const SizedBox(height: AppSpacing.sm),
          Text(copy.t('onboarding.notif.body'), style: const TextStyle(color: DS.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          if (_profile.chronotype != Chronotype.night) _timeRow(copy, 'onboarding.remind.morning', _morning, (v) => _morning = v),
          if (_profile.chronotype != Chronotype.morning) _timeRow(copy, 'onboarding.remind.evening', _evening, (v) => _evening = v),
        ], action: !_notifAsked
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                ChunkyButton(onPressed: () => _askNotif(true), label: copy.t('onboarding.notif.allow')),
                TextButton(onPressed: () => _askNotif(false), child: Text(copy.t('onboarding.notif.later'))),
              ])
            : ChunkyButton(onPressed: () => _go(11), label: copy.t('common.next')));
      default:
        body = _page(children: [
          Text(copy.t('onboarding.trial.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback)),
          const SizedBox(height: AppSpacing.sm),
          Text(copy.t('onboarding.trial.body'), style: const TextStyle(color: DS.textPrimary)),
        ], action: Column(mainAxisSize: MainAxisSize.min, children: [
          if (ref.watch(entitlementRepositoryProvider) != null && ref.watch(appConfigProvider).trialEnabled)
            ChunkyButton(onPressed: _busy ? null : _trial, label: copy.t('onboarding.trial.start')),
          TextButton(onPressed: _busy ? null : _finish, child: Text(copy.t('onboarding.trial.later'))),
        ]));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && step > 1) _go(_before(step));
      },
      child: Scaffold(
        backgroundColor: DS.cardCat,
        appBar: AppBar(
          backgroundColor: DS.cardCat,
          automaticallyImplyLeading: false,
          leading: step > 1 ? IconButton(tooltip: copy.t('common.back'), icon: const Icon(Icons.arrow_forward), onPressed: () => _go(_before(step))) : null,
          title: _Dots(current: step, total: OnboardingService.totalSteps),
          actions: [if (skippable) TextButton(onPressed: () => _go(_after(step)), child: Text(copy.t('onboarding.skip')))],
        ),
        body: SafeArea(child: _ready ? body : const SizedBox.shrink()),
      ),
    );
  }

  Widget _timeRow(CopyLike copy, String labelKey, int minutes, ValueChanged<int> set) => RoundCard(
        margin: const EdgeInsets.only(bottom: 10),
        onTap: () async {
          final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
          if (t != null) setState(() => set(t.hour * 60 + t.minute));
        },
        child: Row(children: [
          const Icon(Icons.alarm, color: DS.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(copy.t(labelKey), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700))),
          Text(toPersianDigits(JalaliFormatter.time(minutes)), style: const TextStyle(color: DS.textSecondary)),
        ]),
      );

  Widget _planPage(CopyLike copy) {
    final rec = ref.read(goalRecommenderProvider);
    return _page(children: [
      Text(copy.t('onboarding.plan.title'), style: const TextStyle(color: DS.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback)),
      const SizedBox(height: 4),
      Text(copy.t('onboarding.plan.body'), style: const TextStyle(color: DS.textSecondary)),
      const SizedBox(height: 12),
      if (_plan.isEmpty) Text(copy.t('onboarding.plan.empty'), style: const TextStyle(color: DS.textPrimary)),
      for (var i = 0; i < _plan.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RoundCard(
            child: Column(children: [
              Row(children: [
                AreaIcon(icon: _plan[i].icon, area: _plan[i].areaKey),
                const SizedBox(width: 12),
                Expanded(child: Text(copy.t(_plan[i].titleKey), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 16))),
              ]),
              Row(children: [
                Flexible(child: TextButton.icon(
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: Text(copy.t('onboarding.plan.another'), overflow: TextOverflow.ellipsis),
                  onPressed: () async {
                    _rejected.add(_plan[i].key);
                    final r = rec.replacement(_profile, _plan, i, seed: _seed, rejected: _rejected);
                    if (r == null) return;
                    setState(() {
                      _plan[i] = r;
                      _replaced++;
                    });
                    await _savePlan();
                  },
                )),
                const Spacer(),
                IconButton(tooltip: copy.t('onboarding.plan.up'), icon: const Icon(Icons.arrow_upward, size: 20), onPressed: i == 0 ? null : () async {
                  setState(() => _plan.insert(i - 1, _plan.removeAt(i)));
                  await _savePlan();
                }),
                IconButton(tooltip: copy.t('onboarding.plan.down'), icon: const Icon(Icons.arrow_downward, size: 20), onPressed: i == _plan.length - 1 ? null : () async {
                  setState(() => _plan.insert(i + 1, _plan.removeAt(i)));
                  await _savePlan();
                }),
                IconButton(tooltip: copy.t('onboarding.plan.remove'), icon: const Icon(Icons.close, size: 20), onPressed: () async {
                  setState(() => _plan.removeAt(i));
                  await _savePlan();
                }),
              ]),
            ]),
          ),
        ),
    ], action: ChunkyButton(onPressed: () => _go(10), label: copy.t('common.next')));
  }

  Widget _page({required List<Widget> children, required Widget action}) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: ListView(children: children)),
          const SizedBox(height: 8),
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

typedef CopyLike = dynamic;

/// Progress dots at the top of the page.
class _Dots extends StatelessWidget {
  const _Dots({required this.current, required this.total});
  final int current;
  final int total;
  @override
  Widget build(BuildContext context) => Semantics(
        label: '${toPersianDigits(current)}/${toPersianDigits(total)}',
        child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 1; i <= total; i++)
              Container(
                width: i == current ? 14 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: i <= current ? DS.primaryGreen : DS.progressRail, borderRadius: BorderRadius.circular(4)),
              ),
          ]),
        ),
      );
}

/// A wobbling basket (placeholder art): closed on the welcome page, open when the cat arrives.
class _Basket extends StatefulWidget {
  const _Basket({this.open = false});
  final bool open;
  @override
  State<_Basket> createState() => _BasketState();
}

class _BasketState extends State<_Basket> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Transform.rotate(
          angle: reduce ? 0 : (_c.value - 0.5) * 0.12,
          child: Icon(widget.open ? Icons.inventory_2_outlined : Icons.shopping_basket, size: 96, color: DS.bgQuests),
        ),
      ),
    );
  }
}
