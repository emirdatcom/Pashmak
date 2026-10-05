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
import '../../habits/domain/habit_service.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../../onboarding/domain/onboarding_answers.dart';
import '../domain/goal_recommender.dart';
import '../domain/goal_title.dart';
import 'goal_icons.dart';

const goalAreas = ['sleep', 'calm', 'movement', 'nutrition', 'connection', 'focus', 'self_kindness', 'home'];
const _suggestionTabs = ['suggested', 'easy_wins', 'calm', 'connection', 'gratitude', 'health', 'sleep', 'movement', 'tidy'];

/// Round icon on the colour of a care area.
class AreaIcon extends StatelessWidget {
  const AreaIcon({super.key, required this.icon, required this.area, this.size = 44});
  final String? icon;
  final String? area;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: DS.area(area ?? 'home').withValues(alpha: 0.28)),
        child: Icon(goalIcon(icon), color: DS.textPrimary, size: size * 0.55),
      );
}

/// "My goals": every active goal; creation goes through the premium gate (docs/60 §5).
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final goals = ref.watch(allHabitsProvider).value ?? const [];
    final library = {for (final g in ref.watch(goalLibraryProvider)) g.key: g};
    return Scaffold(
      backgroundColor: DS.bgSettings,
      appBar: AppBar(title: Text(copy.t('goal.list.title')), backgroundColor: DS.bgSettings),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: DS.primaryGreen,
        foregroundColor: DS.onDark,
        onPressed: () => context.push(Routes.goalNew),
        icon: const Icon(Icons.add),
        label: Text(copy.t('goal.add')),
      ),
      body: goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(copy.t('goal.empty.title'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(copy.t('goal.empty.body'), textAlign: TextAlign.center),
                ]),
              ),
            )
          : ReorderableListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              onReorderItem: (from, to) async {
                final ids = [for (final h in goals) h.id];
                ids.insert(to, ids.removeAt(from));
                await ref.read(habitServiceProvider).reorder(ids);
              },
              children: [
                for (final h in goals)
                  Padding(
                    key: ValueKey(h.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RoundCard(
                      onTap: () => context.push(Routes.goal(h.id)),
                      child: Row(children: [
                        AreaIcon(icon: library[h.goalKey ?? h.templateKey]?.icon, area: h.areaKey ?? library[h.goalKey ?? h.templateKey]?.areaKey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(goalTitle(copy, h.goalKey ?? h.templateKey, h.title), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                            if (h.isLocked) Text(copy.t('goal.locked.hint'), style: const TextStyle(color: DS.textSecondary, fontSize: 13)),
                          ]),
                        ),
                        const Icon(Icons.drag_handle, color: DS.textSecondary),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Create or edit a goal (docs/22 §8): a white card (icon, title, area/time/repeat rows) and suggestions with tabs.
class GoalEditorScreen extends ConsumerStatefulWidget {
  const GoalEditorScreen({super.key, this.goalId});
  final String? goalId;
  @override
  ConsumerState<GoalEditorScreen> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<GoalEditorScreen> {
  final _title = TextEditingController();
  String? _goalKey; // library goal, null = custom
  String _icon = 'check';
  String? _area;
  String _timeOfDay = 'any';
  String _repeat = 'daily'; // daily | weekly | once
  int _mask = 127;
  int? _reminder;
  String _tab = 'suggested';
  String _source = 'custom';
  bool _loaded = false;
  OnboardingProfile? _profile;
  int _seed = 0;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _loaded = true;
    _profile = await OnboardingAnswers(ref.read(databaseProvider)).load();
    _seed = stableHash(await ref.read(deviceIdentityProvider).installId());
    final id = widget.goalId;
    if (id != null) {
      final h = await ref.read(habitServiceProvider).byId(id);
      if (h != null) {
        _goalKey = h.goalKey ?? h.templateKey;
        _title.text = h.title ?? '';
        _icon = h.icon;
        _area = h.areaKey;
        _timeOfDay = h.timeOfDay;
        _repeat = h.repeatType == 'once' ? 'once' : (h.scheduleType == 'weekly' ? 'weekly' : 'daily');
        _mask = h.weekdaysMask;
        _reminder = h.reminderMinutes;
      }
    }
    if (mounted) setState(() {});
  }

  void _pick(GoalDef g, String tab) {
    final rec = ref.read(goalRecommenderProvider);
    setState(() {
      _goalKey = g.key;
      _title.clear();
      _icon = g.icon;
      _area = g.areaKey;
      _timeOfDay = rec.resolvedTimeOfDay(g, _profile?.chronotype ?? Chronotype.flexible);
      _repeat = g.repeatType == 'once' ? 'once' : (g.repeatType == 'weekly' ? 'weekly' : 'daily');
      _mask = g.weekdaysMask;
      _source = tab == 'suggested' ? 'suggested' : 'tab';
    });
  }

  Future<void> _save() async {
    final svc = ref.read(habitServiceProvider);
    final custom = _goalKey == null;
    if (custom && _title.text.trim().isEmpty) return;
    final today = ref.read(todayProvider);
    final draft = HabitDraft(
      templateKey: _goalKey,
      title: custom ? _title.text.trim() : null,
      icon: custom ? 'check' : _icon,
      scheduleType: _repeat == 'weekly' ? 'weekly' : 'daily',
      weekdaysMask: _repeat == 'weekly' ? _mask : 127,
      reminderMinutes: _reminder,
      areaKey: _area,
      timeOfDay: _timeOfDay,
      repeatType: _repeat,
      dueDay: _repeat == 'once' ? today.value : null,
      source: custom ? 'custom' : _source,
    );
    if (widget.goalId == null) {
      final gate = await svc.gateFor(draft, isPremium: ref.read(premiumProvider));
      if (gate != null) {
        if (!mounted) return;
        if (!await passGate(context, ref, gate.trigger)) return;
      }
      await svc.create(draft);
    } else {
      await svc.update(widget.goalId!, draft);
    }
    if (mounted) context.canPop() ? context.pop() : context.go(Routes.home);
  }

  Future<String?> _sheet(List<(String, String)> options, String title) => showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(8), child: Text(title, style: Theme.of(ctx).textTheme.titleMedium)),
            for (final o in options) ListTile(title: Text(o.$2), onTap: () => Navigator.pop(ctx, o.$1)),
          ]),
        ),
      );

  Widget _row(IconData icon, String text, VoidCallback onTap, {Widget? trailing}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(children: [
            Icon(icon, color: DS.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(color: DS.textPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
            ?trailing,
            const Icon(Icons.chevron_left, color: DS.textSecondary),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) unawaited(_load());
    final copy = ref.watch(copyProvider);
    final editing = widget.goalId != null;
    final library = ref.watch(goalLibraryProvider);
    final rec = ref.watch(goalRecommenderProvider);
    final existing = (ref.watch(allHabitsProvider).value ?? const []).map((h) => h.goalKey ?? h.templateKey).whereType<String>().toSet();
    final profile = _profile ?? const OnboardingProfile();
    final suggestions = _tab == 'suggested'
        ? rec.suggestedTab(profile, seed: _seed, existing: existing)
        : [for (final g in library) if (g.tabs.contains(_tab) && !existing.contains(g.key)) g];
    final areaLabel = _area == null ? copy.t('goal.editor.area') : copy.t('area.$_area.name');
    final whenLabel = '${copy.t('goal.editor.today_prefix')} · ${copy.t('goal.editor.when.$_timeOfDay')}';
    final repeatLabel = copy.t('goal.editor.repeat.$_repeat');
    final titleText = _goalKey != null ? goalTitle(copy, _goalKey, null) : '';
    return Scaffold(
      backgroundColor: DS.bgSettings,
      appBar: AppBar(title: Text(copy.t(editing ? 'goal.editor.edit' : 'goal.editor.new')), backgroundColor: DS.bgSettings),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        RoundCard(
          child: Column(children: [
            Row(children: [
              AreaIcon(icon: _icon, area: _area, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: _goalKey != null
                    ? Text(titleText, style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 18))
                    : TextField(controller: _title, maxLength: 60, decoration: InputDecoration(hintText: copy.t('goal.editor.title_hint'), counterText: '', border: InputBorder.none)),
              ),
              if (_goalKey != null)
                IconButton(
                  tooltip: copy.t('common.close'),
                  icon: const Icon(Icons.close, color: DS.textSecondary),
                  onPressed: () => setState(() {
                    _goalKey = null;
                    _icon = 'check';
                  }),
                ),
            ]),
            const Divider(),
            _row(Icons.category_outlined, areaLabel, () async {
              final v = await _sheet([for (final a in goalAreas) (a, copy.t('area.$a.name'))], copy.t('area.picker.title'));
              if (v != null) setState(() => _area = v);
            }),
            _row(Icons.schedule, whenLabel, () async {
              final v = await _sheet([for (final t in ['any', 'morning', 'afternoon', 'evening']) (t, copy.t('goal.editor.when.$t'))], copy.t('goal.editor.when'));
              if (v != null) setState(() => _timeOfDay = v);
            }),
            _row(Icons.repeat, repeatLabel, () async {
              final v = await _sheet([for (final r in ['daily', 'weekly', 'once']) (r, copy.t('goal.editor.repeat.$r'))], copy.t('goal.editor.repeat'));
              if (v != null) setState(() => _repeat = v);
            }),
            if (_repeat == 'weekly')
              Wrap(spacing: 4, children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(JalaliFormatter.weekdayNames[i]),
                    selected: (_mask >> i) & 1 == 1,
                    onSelected: (v) => setState(() => _mask = v ? (_mask | (1 << i)) : (_mask & ~(1 << i))),
                  ),
              ]),
            _row(Icons.notifications_none, _reminder == null ? copy.t('goal.editor.no_reminder') : JalaliFormatter.time(_reminder!), () async {
              final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: (_reminder ?? 540) ~/ 60, minute: (_reminder ?? 540) % 60));
              if (t != null) setState(() => _reminder = t.hour * 60 + t.minute);
            }, trailing: _reminder == null ? null : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _reminder = null))),
          ]),
        ),
        const SizedBox(height: 12),
        ChunkyButton(label: copy.t('goal.editor.save'), onPressed: _save),
        if (editing) ...[
          const SizedBox(height: 8),
          ChunkyButton.neutral(
            label: copy.t('goal.editor.archive'),
            onPressed: () async {
              await ref.read(habitServiceProvider).archive(widget.goalId!);
              if (context.mounted) context.go(Routes.home);
            },
          ),
        ],
        if (!editing) ...[
          const SizedBox(height: 20),
          Text(copy.t('goal.editor.suggestions'), style: const TextStyle(color: DS.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          TabPills(
            tabs: [for (final t in _suggestionTabs) PillTab(t, copy.t('goal.tab.$t'))],
            selected: _tab,
            onSelected: (t) => setState(() => _tab = t),
          ),
          if (suggestions.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(copy.t('goal.suggested.empty'))),
          for (final g in suggestions.take(20))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RoundCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onTap: () => _pick(g, _tab),
                semanticLabel: copy.t(g.titleKey),
                child: Row(children: [
                  AreaIcon(icon: g.icon, area: g.areaKey, size: 40),
                  const SizedBox(width: 12),
                  Expanded(child: Text(copy.t(g.titleKey), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w600))),
                  const Icon(Icons.add_circle_outline, color: DS.primaryGreen),
                ]),
              ),
            ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Goal detail with the Saturday-first week and Jalali dates.
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});
  final String goalId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final svc = ref.watch(habitServiceProvider);
    final today = ref.watch(todayProvider);
    final start = today.weekStart();
    return FutureBuilder(
      future: Future.wait([svc.byId(goalId), svc.doneDays(goalId, start, start.addDays(6))]),
      builder: (context, snap) {
        final habit = snap.data?[0] as dynamic;
        final done = (snap.data?[1] as Set<String>?) ?? const <String>{};
        return Scaffold(
          backgroundColor: DS.bgSettings,
          appBar: AppBar(
            backgroundColor: DS.bgSettings,
            title: Text(habit == null ? '' : goalTitle(copy, (habit.goalKey ?? habit.templateKey) as String?, habit.title as String?)),
            actions: [IconButton(icon: const Icon(Icons.edit_outlined), tooltip: copy.t('goal.editor.edit'), onPressed: () => context.push(Routes.goalEdit(goalId)))],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RoundCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(copy.t('goal.detail.week'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (var i = 0; i < 7; i++) _DayDot(day: start.addDays(i), done: done.contains(start.addDays(i).value), isToday: start.addDays(i) == today),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.done, required this.isToday});
  final LocalDay day;
  final bool done;
  final bool isToday;
  @override
  Widget build(BuildContext context) => Semantics(
        label: '${JalaliFormatter.weekday(day)} ${JalaliFormatter.dayMonth(day)}',
        checked: done,
        child: ExcludeSemantics(
          child: Column(children: [
            Text(JalaliFormatter.weekday(day).substring(0, 1)),
            const SizedBox(height: AppSpacing.xs),
            CircleAvatar(
              radius: 16,
              backgroundColor: done ? DS.primaryGreen : DS.progressRail,
              child: done
                  ? const Icon(Icons.check, size: 18, color: DS.onDark)
                  : Text(toPersianDigits(JalaliFormatter.toJalali(day).day), style: TextStyle(color: DS.textPrimary, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
            ),
          ]),
        ),
      );
}
