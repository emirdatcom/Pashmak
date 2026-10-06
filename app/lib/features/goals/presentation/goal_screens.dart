import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/content/copy_resolver.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../exercises/presentation/exercise_picker.dart';
import '../../habits/domain/habit_service.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../../onboarding/domain/onboarding_answers.dart';
import '../domain/goal_recommender.dart';
import '../domain/goal_title.dart';
import 'goal_icons.dart';
import 'goal_sheets.dart';

export 'goal_sheets.dart' show goalAreas;

const _suggestionTabs = ['suggested', 'easy_wins', 'calm', 'connection', 'gratitude', 'health', 'sleep', 'movement', 'tidy'];

/// Sticker of a goal on the colour of its care area.
class AreaIcon extends StatelessWidget {
  const AreaIcon({super.key, required this.icon, required this.area, this.goalKey, this.size = 44});
  final String? icon;
  final String? goalKey;
  final String? area;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: DS.area(area ?? 'home').withValues(alpha: 0.28)),
        alignment: Alignment.center,
        child: EmojiArt(goalEmoji(goalKey: goalKey, icon: icon, area: area), size: size * 0.8),
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
        foregroundColor: DS.onPrimary,
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
                        AreaIcon(icon: h.icon.contains('/') ? h.icon : library[h.goalKey ?? h.templateKey]?.icon, goalKey: h.goalKey ?? h.templateKey, area: h.areaKey ?? library[h.goalKey ?? h.templateKey]?.areaKey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(goalTitle(copy, h.goalKey ?? h.templateKey, h.title), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                            if (h.isLocked) Text(copy.t('goal.locked.hint'), style: const TextStyle(color: DS.textSecondary, fontSize: 13)),
                          ]),
                        ),
                        const GlyphArt('drag', color: DS.neutralButtonEdge, size: 22),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Create or edit a goal (docs/22 §8): a white card (icon, title, area / date-time / repeat rows that open sheets)
/// and suggestions with tabs.
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
  LocalDay? _pickedDay; // null = today
  String _timeOfDay = 'any';
  String _repeat = 'once'; // once | daily | weekdays | weekly_on | monthly | custom
  int _mask = 127;
  int? _reminder;
  int _times = 1;
  bool _keep = false;
  String? _exerciseKey;
  late bool _more = widget.goalId != null; // the "more options" layout; editing starts there
  bool _dateOpen = false, _timeOpen = false; // inline pickers of that layout
  final _focus = FocusNode();
  String _tab = 'suggested';
  String _source = 'custom';
  bool _loaded = false;
  OnboardingProfile? _profile;
  int _seed = 0;

  static const _maxTimes = 10;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {})); // the save button follows the title
    _focus.addListener(() => setState(() {})); // the footer appears while typing
  }

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Editor repeat mode of a stored / library schedule.
  static String _repeatOf(String repeatType, String scheduleType, int mask) => repeatType == 'once' || repeatType == 'monthly'
      ? repeatType
      : (repeatType == 'weekly' || scheduleType == 'weekly')
          ? (mask == weekdaysMask ? 'weekdays' : 'custom')
          : 'daily';

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
        _repeat = _repeatOf(h.repeatType, h.scheduleType, h.weekdaysMask);
        _mask = h.weekdaysMask;
        _reminder = h.reminderMinutes;
        _times = h.targetPerDay.clamp(1, _maxTimes);
        _keep = h.keepUntilDone ?? false;
        _exerciseKey = h.exerciseKey;
        final due = h.dueDay == null ? null : LocalDay.parse(h.dueDay!);
        // A monthly goal keeps its anchor day; other past days fall back to today.
        if (due != null && (_repeat == 'monthly' || due.compareTo(ref.read(todayProvider)) > 0)) _pickedDay = due;
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
      _repeat = _repeatOf(g.repeatType, g.repeatType, g.weekdaysMask);
      _mask = g.weekdaysMask;
      _source = tab == 'suggested' ? 'suggested' : 'tab';
    });
  }

  bool get _canSave => _goalKey != null || _title.text.trim().isNotEmpty;

  Future<void> _save() async {
    final svc = ref.read(habitServiceProvider);
    final custom = _goalKey == null;
    if (!_canSave) return;
    final today = ref.read(todayProvider);
    final day = _pickedDay ?? today;
    final weekly = _repeat == 'weekdays' || _repeat == 'weekly_on' || _repeat == 'custom';
    final draft = HabitDraft(
      templateKey: _goalKey,
      title: custom ? _title.text.trim() : null,
      icon: _icon,
      scheduleType: weekly ? 'weekly' : 'daily',
      weekdaysMask: weekly ? _mask : 127,
      targetPerDay: _times,
      reminderMinutes: _reminder,
      areaKey: _area,
      timeOfDay: _timeOfDay,
      repeatType: weekly ? 'weekly' : _repeat,
      // once / monthly always carry their day; other repeats only when they start later than today.
      dueDay: _repeat == 'once' || _repeat == 'monthly' || day.compareTo(today) > 0 ? day.value : null,
      exerciseKey: _exerciseKey,
      keepUntilDone: _repeat == 'once' && _keep,
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
    if (mounted) _close();
  }

  void _close() => context.canPop() ? context.pop() : context.go(Routes.home);

  // --- the three sheets and the pickers, shared by both layouts ------------------------------------------------------

  void _openArea() {
    final copy = ref.read(copyProvider);
    showGoalSheet<void>(context, title: copy.t('area.picker.title'), builder: (_) => GoalAreaSheet(area: _area, onChanged: (a) => setState(() => _area = a)));
  }

  void _openWhen() {
    final copy = ref.read(copyProvider);
    final today = ref.read(todayProvider);
    showGoalSheet<void>(
      context,
      title: copy.t('goal.sheet.datetime.title'),
      builder: (_) => GoalWhenSheet(
        day: _pickedDay ?? today,
        timeOfDay: _timeOfDay,
        reminder: _reminder,
        onChanged: (d, t, r) => setState(() {
          _pickedDay = d == today ? null : d;
          _timeOfDay = t;
          _reminder = r;
          if (_repeat == 'weekly_on') _mask = 1 << d.weekdayIndex;
        }),
      ),
    );
  }

  void _openRepeat() {
    final copy = ref.read(copyProvider);
    showGoalSheet<void>(
      context,
      title: copy.t('goal.editor.repeat'),
      builder: (_) => GoalRepeatSheet(
        repeat: _repeat,
        mask: _mask,
        day: _pickedDay ?? ref.read(todayProvider),
        onChanged: (r, m) => setState(() {
          _repeat = r;
          _mask = m;
        }),
      ),
    );
  }

  Future<void> _pickReminder() async {
    final v = await pickGoalTime(context, ref.read(copyProvider), _reminder);
    if (v != null && mounted) setState(() => _reminder = v);
  }

  Future<void> _pickExercise() async {
    final key = await Navigator.of(context).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ExercisePickerScreen()));
    if (key != null && mounted) setState(() => _exerciseKey = key);
  }

  // --- pieces --------------------------------------------------------------------------------------------------------

  static const _titleStyle = TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 20);

  Widget _iconBox({bool editable = false}) {
    final box = Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: DS.chipBg, borderRadius: BorderRadius.circular(24)),
      child: EmojiArt(goalEmoji(goalKey: _goalKey, icon: _icon, area: _area), size: 52),
    );
    if (!editable) return box;
    final copy = ref.read(copyProvider);
    return Semantics(
      button: true,
      label: copy.t('goal.options.icon'),
      child: GestureDetector(
        onTap: () async {
          final id = await pickGoalIcon(context, copy);
          if (id != null && mounted) setState(() => _icon = id);
        },
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(children: [
            box,
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: DS.chipBg, shape: BoxShape.circle, border: Border.all(color: DS.card, width: 3)),
                alignment: Alignment.center,
                child: const EmojiArt('ui/pencil', size: 16),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _titleField(CopyResolver copy) => Row(children: [
        Expanded(
          child: _goalKey != null
              ? Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(goalTitle(copy, _goalKey, null), style: _titleStyle))
              : TextField(
                  controller: _title,
                  focusNode: _focus,
                  maxLength: 60,
                  style: _titleStyle,
                  decoration: InputDecoration(
                    hintText: copy.t('goal.editor.title_hint'),
                    hintStyle: _titleStyle.copyWith(color: DS.neutralButtonEdge),
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
        ),
      ]);

  /// "More / less options" on one side, the save button on the other.
  Widget _footer(CopyResolver copy) => Row(children: [
        TextButton(
          onPressed: () => setState(() => _more = !_more),
          child: Text(copy.t(_more ? 'goal.editor.less' : 'goal.editor.more'), style: const TextStyle(color: DS.textSecondary, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        ChunkyButton(label: copy.t('common.save'), expand: false, height: 44, onPressed: _canSave ? _save : null),
      ]);

  Widget _row(String emoji, String text, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            IconChip(emoji, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(color: DS.textMuted, fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
        ),
      );

  /// One card of the "more options" layout: chip, optional small caption, value and a trailing control.
  Widget _option(Widget chip, String text, {String? caption, String? hint, VoidCallback? onTap, Widget? trailing, String? arrow, Widget? below}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlineCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
           ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(children: [
              chip,
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (caption != null) Text(caption, style: const TextStyle(color: DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(text, style: const TextStyle(color: DS.textSecondary, fontSize: 16, fontWeight: FontWeight.w700)),
                  if (hint != null) Text(hint, style: const TextStyle(color: DS.textSecondary, fontSize: 13)),
                ]),
              ),
              ?trailing,
              // `arrow` is a glyph name; `chevron_up` is the down chevron turned over.
              if (arrow != null) GlyphArt(arrow == 'chevron_up' ? 'chevron_down' : arrow, quarterTurns: arrow == 'chevron_up' ? 2 : 0, color: DS.neutralButtonEdge, size: 18),
            ]),
           ),
           if (below != null) Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: below),
          ]),
        ),
      );

  Widget _stepButton(String glyph, String label, VoidCallback? onPressed) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: DS.chipBg,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onPressed, child: SizedBox(width: 44, height: 44, child: Center(child: GlyphArt(glyph, size: 18, color: onPressed == null ? DS.neutralButtonEdge : DS.textSecondary)))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) unawaited(_load());
    final copy = ref.watch(copyProvider);
    final today = ref.watch(todayProvider);
    final day = _pickedDay ?? today;
    final areaLabel = _area == null ? copy.t('goal.editor.area') : copy.t('area.$_area.name');
    final repeatLabel = goalRepeatLabel(copy, _repeat, _mask, day);
    return Scaffold(
      backgroundColor: DS.bgHomeGround,
      body: SafeArea(bottom: !_more, child: _more ? _moreOptions(copy, today, day, areaLabel, repeatLabel) : _compact(copy, today, day, areaLabel, repeatLabel)),
    );
  }

  void _undoPick() => setState(() {
        _goalKey = null;
        _icon = 'check';
        _area = null;
        _timeOfDay = 'any';
        _repeat = 'once';
        _mask = 127;
        _source = 'custom';
      });

  /// The card stays put, the suggestions scroll under it and the category bar is pinned to the bottom. With the
  /// keyboard open (or nothing to suggest) everything is one scrolling column so short screens never overflow.
  Widget _compact(CopyResolver copy, LocalDay today, LocalDay day, String areaLabel, String repeatLabel) {
    final editing = widget.goalId != null;
    final picked = _goalKey != null;
    final library = ref.watch(goalLibraryProvider);
    final rec = ref.watch(goalRecommenderProvider);
    final existing = (ref.watch(allHabitsProvider).value ?? const []).map((h) => h.goalKey ?? h.templateKey).whereType<String>().toSet();
    final profile = _profile ?? const OnboardingProfile();
    final suggestions = _tab == 'suggested'
        ? rec.suggestedTab(profile, seed: _seed, existing: existing)
        : [for (final g in library) if (g.tabs.contains(_tab) && !existing.contains(g.key)) g];
    // A goal with a single day shows its date; a repeating one only shows the time of day.
    final dated = _repeat == 'once' || _pickedDay != null;
    final whenLabel = [
      if (dated) goalDayLabel(copy, day, today),
      copy.t('goal.editor.when.$_timeOfDay'),
      if (_reminder != null) JalaliFormatter.time(_reminder!),
    ].join(' · ');
    final showFooter = _focus.hasFocus || _canSave;
    final showSuggestions = !editing && !picked;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    final top = <Widget>[
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: RoundCloseButton(label: copy.t('common.close'), color: DS.glass, iconColor: DS.onDark, onPressed: _close),
      ),
      const SizedBox(height: 12),
      Material(
        color: DS.card,
        elevation: 2,
        shadowColor: DS.shadow,
        borderRadius: BorderRadius.circular(DS.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _iconBox(),
              const SizedBox(height: 8),
              _titleField(copy),
              _row('ui/plus', areaLabel, _openArea),
              _row(dated ? 'ui/calendar' : 'ui/clock', whenLabel, _openWhen),
              _row(_repeat == 'once' ? 'ui/repeat_off' : 'ui/repeat', repeatLabel, _openRepeat),
            ]),
          ),
          if (showFooter) Container(color: DS.sheetBg, padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 16, 12), child: _footer(copy)),
        ]),
      ),
      if (picked && !editing)
        Center(
          child: TextButton.icon(
            onPressed: _undoPick,
            icon: const EmojiArt('ui/undo', size: 22),
            label: Text(copy.t('goal.undo'), style: const TextStyle(color: DS.onDark, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      if (editing) ...[
        const SizedBox(height: 12),
        ChunkyButton.neutral(
          label: copy.t('goal.editor.archive'),
          onPressed: () async {
            await ref.read(habitServiceProvider).archive(widget.goalId!);
            if (mounted) context.go(Routes.home);
          },
        ),
      ],
    ];

    final label = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(copy.t('goal.editor.suggestions'), style: const TextStyle(color: DS.onDark, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ),
    );
    final rows = <Widget>[
      if (suggestions.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(copy.t('goal.suggested.empty'), style: const TextStyle(color: DS.onDark))),
      for (final g in suggestions.take(30))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            button: true,
            label: copy.t(g.titleKey),
            child: Material(
              color: DS.glass,
              borderRadius: BorderRadius.circular(DS.radiusCard),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _pick(g, _tab),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    EmojiArt(goalEmoji(goalKey: g.key, icon: g.icon, area: g.areaKey), size: 48),
                    const SizedBox(width: 12),
                    Expanded(child: ExcludeSemantics(child: Text(copy.t(g.titleKey), style: const TextStyle(color: DS.onDark, fontSize: 17, fontWeight: FontWeight.w700)))),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ];

    if (!showSuggestions || keyboard) {
      return ListView(padding: const EdgeInsets.all(16), children: [...top, if (showSuggestions) ...[label, ...rows]]);
    }
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Column(mainAxisSize: MainAxisSize.min, children: [...top, label])),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), children: rows)),
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            for (final t in _suggestionTabs)
              Semantics(
                button: true,
                selected: t == _tab,
                child: Material(
                  color: t == _tab ? DS.glass : DS.bgHomeGround,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _tab = t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Center(child: Text(copy.t('goal.tab.$t'), style: const TextStyle(color: DS.onDark, fontSize: 14, fontWeight: FontWeight.w800))),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  /// Every option as its own card on an off-white panel, with the footer pinned to the bottom.
  Widget _moreOptions(CopyResolver copy, LocalDay today, LocalDay day, String areaLabel, String repeatLabel) {
    final exercise = exerciseByKey(ref.watch(contentRepositoryProvider), _exerciseKey);
    final once = _repeat == 'once';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(color: DS.sheetBg, borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusSheet))),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _iconBox(editable: true),
              const Spacer(),
              RoundCloseButton(label: copy.t('common.close'), onPressed: _close),
            ]),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: OutlineCard(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: _titleField(copy))),
            _option(const IconChip('ui/plus', color: DS.areaFocus), areaLabel, onTap: _openArea, arrow: 'chevron_right'),
            _option(
              const IconChip('ui/calendar'),
              goalDayLabel(copy, day, today),
              caption: copy.t('goal.sheet.date'),
              onTap: () => setState(() => _dateOpen = !_dateOpen),
              arrow: _dateOpen ? 'chevron_up' : 'chevron_down',
              below: !_dateOpen
                  ? null
                  : GoalDateChoices(
                      day: day,
                      onChanged: (d) => setState(() {
                        _pickedDay = d == today ? null : d;
                        if (_repeat == 'weekly_on') _mask = 1 << d.weekdayIndex;
                      }),
                    ),
            ),
            _option(
              const IconChip('ui/clock'),
              copy.t('goal.editor.when.$_timeOfDay'),
              caption: copy.t('goal.options.time_of_day'),
              onTap: () => setState(() => _timeOpen = !_timeOpen),
              arrow: _timeOpen ? 'chevron_up' : 'chevron_down',
              below: !_timeOpen ? null : GoalTimeChoices(timeOfDay: _timeOfDay, onChanged: (t) => setState(() => _timeOfDay = t)),
            ),
            _option(
              const IconChip('ui/bell', color: DS.energy),
              _reminder == null ? copy.t('goal.sheet.remind') : '${copy.t('goal.sheet.remind')} · ${JalaliFormatter.time(_reminder!)}',
              onTap: _reminder == null ? null : _pickReminder,
              trailing: Switch(
                value: _reminder != null,
                activeTrackColor: DS.primaryGreen,
                onChanged: (on) => on ? _pickReminder() : setState(() => _reminder = null),
              ),
            ),
            _option(IconChip(once ? 'ui/repeat_off' : 'ui/repeat', color: DS.areaFocus), repeatLabel, caption: copy.t('goal.editor.repeat'), onTap: _openRepeat, arrow: 'chevron_down'),
            // Carry-over only makes sense for a goal with a single day.
            _option(
              const IconChip('ui/pin', color: DS.energy),
              copy.t('goal.options.keep'),
              trailing: Switch(value: once && _keep, activeTrackColor: DS.primaryGreen, onChanged: once ? (v) => setState(() => _keep = v) : null),
            ),
            const SizedBox(height: 16),
            _option(
              const IconChip('ui/tally', color: DS.areaSelfKindness),
              copy.t('goal.options.times'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _stepButton('minus', copy.t('goal.options.times'), _times > 1 ? () => setState(() => _times--) : null),
                SizedBox(width: 40, child: Text(toPersianDigits(_times), textAlign: TextAlign.center, style: const TextStyle(color: DS.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
                _stepButton('plus', copy.t('goal.options.times'), _times < _maxTimes ? () => setState(() => _times++) : null),
              ]),
            ),
            _option(
              exercise == null ? const IconChip('ui/arrow', color: DS.areaMovement) : ExerciseBlob(exercise, size: 40),
              exercise == null ? copy.t('goal.options.link') : copy.t('exercise.${exercise['key']}.name'),
              caption: exercise == null ? null : copy.t('goal.options.link'),
              hint: exercise == null ? copy.t('goal.options.link.hint') : null,
              onTap: _pickExercise,
              trailing: exercise == null
                  ? null
                  : IconButton(tooltip: copy.t('goal.options.link.remove'), icon: const GlyphArt('close', size: 16), onPressed: () => setState(() => _exerciseKey = null)),
              arrow: exercise == null ? 'chevron_right' : null,
            ),
          ]),
        ),
        Container(
          decoration: const BoxDecoration(color: DS.card, border: Border(top: BorderSide(color: DS.outline, width: 2))),
          padding: EdgeInsetsDirectional.fromSTEB(8, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
          child: _footer(copy),
        ),
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
