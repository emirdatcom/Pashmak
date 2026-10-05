import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../core_loop_providers.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../domain/habit_service.dart';

String habitTitle(dynamic copy, String? templateKey, String? title) =>
    templateKey != null ? copy.t('habit.template.$templateKey.title') as String : (title ?? '');

/// List of all active habits; creation goes through the premium gate (docs/60 §5).
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final habits = ref.watch(allHabitsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('habit.list.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.habitNew),
        icon: const Icon(Icons.add),
        label: Text(copy.t('habit.add.title')),
      ),
      body: habits.isEmpty
          ? Center(child: Text(copy.t('home.empty_habits.body'), textAlign: TextAlign.center))
          : ListView(children: [
              for (final h in habits)
                ListTile(
                  title: Text(habitTitle(copy, h.templateKey, h.title)),
                  subtitle: h.isLocked ? Text(copy.t('habit.locked.hint')) : null,
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push(Routes.habit(h.id)),
                ),
            ]),
    );
  }
}

/// Create or edit a habit: pick a template or write your own, schedule, optional reminder.
class HabitEditorScreen extends ConsumerStatefulWidget {
  const HabitEditorScreen({super.key, this.habitId});
  final String? habitId;
  @override
  ConsumerState<HabitEditorScreen> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<HabitEditorScreen> {
  String? _template;
  final _title = TextEditingController();
  String _schedule = 'daily';
  int _mask = 127;
  int? _reminder;
  bool _loaded = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _loaded = true;
    final id = widget.habitId;
    if (id == null) return;
    final h = await ref.read(habitServiceProvider).byId(id);
    if (h != null && mounted) {
      setState(() {
        _template = h.templateKey;
        _title.text = h.title ?? '';
        _schedule = h.scheduleType;
        _mask = h.weekdaysMask;
        _reminder = h.reminderMinutes;
      });
    }
  }

  Future<void> _save() async {
    final svc = ref.read(habitServiceProvider);
    final draft = HabitDraft(
        templateKey: _template, title: _template == null ? _title.text.trim() : null, scheduleType: _schedule, weekdaysMask: _mask, reminderMinutes: _reminder);
    if (_template == null && draft.title!.isEmpty) return;
    if (widget.habitId == null) {
      final gate = await svc.gateFor(draft, isPremium: ref.read(premiumProvider));
      if (gate != null) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        if (!await passGate(context, ref, gate.trigger)) return;
      }
      await svc.create(draft);
    } else {
      await svc.update(widget.habitId!, draft);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) _load();
    final copy = ref.watch(copyProvider);
    final templates = (ref.watch(contentRepositoryProvider).entries('habit_templates') as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final editing = widget.habitId != null;
    return Scaffold(
      appBar: AppBar(title: Text(copy.t(editing ? 'habit.editor.edit' : 'habit.editor.new'))),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        if (!editing) ...[
          Wrap(spacing: AppSpacing.sm, children: [
            for (final t in templates)
              ChoiceChip(
                label: Text(copy.t(t['title_key'] as String)),
                selected: _template == t['key'],
                onSelected: (_) => setState(() {
                  _template = t['key'] as String;
                  _reminder ??= t['default_reminder_minutes'] as int?;
                }),
              ),
            ChoiceChip(label: Text(copy.t('habit.custom.title')), selected: _template == null, onSelected: (_) => setState(() => _template = null)),
          ]),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_template == null) TextField(controller: _title, decoration: InputDecoration(hintText: copy.t('habit.custom.name_hint'), border: const OutlineInputBorder())),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<String>(
          segments: [ButtonSegment(value: 'daily', label: Text(copy.t('habit.editor.daily'))), ButtonSegment(value: 'weekly', label: Text(copy.t('habit.editor.weekly')))],
          selected: {_schedule},
          onSelectionChanged: (s) => setState(() => _schedule = s.first),
        ),
        if (_schedule == 'weekly')
          Wrap(spacing: AppSpacing.xs, children: [
            for (var i = 0; i < 7; i++)
              FilterChip(
                label: Text(JalaliFormatter.weekdayNames[i]),
                selected: (_mask >> i) & 1 == 1,
                onSelected: (v) => setState(() => _mask = v ? (_mask | (1 << i)) : (_mask & ~(1 << i))),
              ),
          ]),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(copy.t('habit.reminder.label')),
          subtitle: Text(_reminder == null ? copy.t('habit.editor.no_reminder') : JalaliFormatter.time(_reminder!)),
          trailing: _reminder == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _reminder = null)),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: (_reminder ?? 540) ~/ 60, minute: (_reminder ?? 540) % 60));
            if (t != null) setState(() => _reminder = t.hour * 60 + t.minute);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: _save, child: Text(copy.t('common.save'))),
        if (editing) TextButton(onPressed: () async {
          await ref.read(habitServiceProvider).archive(widget.habitId!);
          if (context.mounted) context.go(Routes.habits);
        }, child: Text(copy.t('habit.archive'))),
      ]),
    );
  }
}

/// Detail with the Saturday-first week (Persian weekday names) and Jalali dates.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final String habitId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final svc = ref.watch(habitServiceProvider);
    final today = ref.watch(todayProvider);
    final start = today.weekStart();
    return FutureBuilder(
      future: Future.wait([svc.byId(habitId), svc.doneDays(habitId, start, start.addDays(6))]),
      builder: (context, snap) {
        final habit = snap.data?[0] as dynamic;
        final done = (snap.data?[1] as Set<String>?) ?? const <String>{};
        return Scaffold(
          appBar: AppBar(title: Text(habit == null ? '' : habitTitle(copy, habit.templateKey as String?, habit.title as String?)), actions: [
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: copy.t('habit.editor.edit'), onPressed: () => context.push(Routes.habitEdit(habitId))),
          ]),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(copy.t('habit.detail.week'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var i = 0; i < 7; i++) _DayDot(day: start.addDays(i), done: done.contains(start.addDays(i).value), isToday: start.addDays(i) == today),
              ]),
            ]),
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
              backgroundColor: done ? AppColors.turquoiseDark : AppColors.creamDeep,
              child: done ? const Icon(Icons.check, size: 18, color: Colors.white) : Text(toPersianDigits(JalaliFormatter.toJalali(day).day), style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
            ),
          ]),
        ),
      );
}
