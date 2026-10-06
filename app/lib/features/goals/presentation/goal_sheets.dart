import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoPicker, FixedExtentScrollController;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../core/content/copy_resolver.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widgets/widgets.dart';
import 'goal_icons.dart';

const goalAreas = ['sleep', 'calm', 'movement', 'nutrition', 'connection', 'focus', 'self_kindness', 'home'];
const goalTimesOfDay = ['morning', 'afternoon', 'evening', 'bedtime'];

/// Saturday to Wednesday (bit0 = Saturday).
const weekdaysMask = 31;

const _label = TextStyle(color: DS.textSecondary, fontSize: 16, fontWeight: FontWeight.w700);

/// Bottom sheet of the goal flow: off-white panel, round close button, centred title, scrolling body.
Future<T?> showGoalSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder}) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DS.sheetBg,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusSheet))),
      builder: (ctx) => _SheetFrame(title: title, child: builder(ctx)),
    );

class _SheetFrame extends ConsumerWidget {
  const _SheetFrame({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              RoundCloseButton(label: ref.watch(copyProvider).t('common.close'), onPressed: () => Navigator.pop(context)),
              Expanded(child: Text(title, textAlign: TextAlign.center, style: _label.copyWith(fontSize: 17))),
              const SizedBox(width: 44),
            ]),
          ),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), child: child)),
        ]),
      ),
    );
  }
}

class RoundCloseButton extends StatelessWidget {
  const RoundCloseButton({super.key, required this.label, required this.onPressed, this.color = DS.chipBg, this.iconColor = DS.textSecondary});
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onPressed, child: SizedBox(width: 44, height: 44, child: Center(child: GlyphArt('close', color: iconColor, size: 18)))),
        ),
      );
}

/// White card with a soft outline (no shadow); the outline turns green when [selected].
class OutlineCard extends StatelessWidget {
  const OutlineCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.selected = false, this.radius = DS.radiusOutlineCard});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: selected ? DS.primaryGreen : DS.outline, width: selected ? 3 : 2),
    );
    return Material(
      color: DS.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// A pill-like option; one of a group is [selected].
class ChoiceBox extends StatelessWidget {
  const ChoiceBox({super.key, required this.label, required this.selected, required this.onTap, this.emoji, this.caption});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji; // sticker id, see EmojiArt
  final String? caption;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: OutlineCard(
          radius: 16,
          selected: selected,
          onTap: onTap,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: emoji == null ? 12 : 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (emoji != null) ...[EmojiArt(emoji!, size: 44), const SizedBox(height: 6)],
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: _label.copyWith(fontSize: 15)),
            if (caption != null) Text(caption!, style: _label.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

/// A small sticker on a tinted circle.
class IconChip extends StatelessWidget {
  const IconChip(this.emoji, {super.key, this.color = DS.primaryGreen, this.size = 40});
  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.14)),
        alignment: Alignment.center,
        child: EmojiArt(emoji, size: size * 0.58),
      );
}

const _divider = Divider(height: 2, thickness: 2, color: DS.outline);

Widget _checkRow(String text, bool selected, VoidCallback onTap, {Widget? leading}) => Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(children: [
              if (leading != null) ...[leading, const SizedBox(width: 14)],
              Expanded(child: Text(text, style: _label)),
              if (selected) const EmojiArt('ui/check', size: 28),
            ]),
          ),
        ),
      ),
    );

String goalDayLabel(CopyResolver copy, LocalDay day, LocalDay today) => day == today
    ? copy.t('goal.sheet.date.today')
    : day == today.addDays(1)
        ? copy.t('goal.sheet.date.tomorrow')
        : JalaliFormatter.dayMonth(day);

/// [repeat] is one of: once | daily | weekdays | weekly_on | monthly | custom.
String goalRepeatLabel(CopyResolver copy, String repeat, int mask, LocalDay day) => switch (repeat) {
      'once' => copy.t('goal.editor.repeat.once'),
      'weekdays' => copy.t('goal.editor.repeat.weekdays'),
      'weekly_on' => copy.t('goal.editor.repeat.weekly_on', {'day': JalaliFormatter.weekday(day)}),
      'monthly' => copy.t('goal.editor.repeat.monthly_on', {'n': JalaliFormatter.toJalali(day).day}),
      'custom' => copy.t('goal.editor.repeat.custom_days', {
          'days': [for (var i = 0; i < 7; i++) if ((mask >> i) & 1 == 1) JalaliFormatter.weekdayNames[i]].join('، '),
        }),
      _ => copy.t('goal.editor.repeat.daily'),
    };

// ---------------------------------------------------------------------------------------------------------------------
// Date and time

/// Date (today / tomorrow / a day), time of day and the reminder. Every change is reported at once; there is no save.
class GoalWhenSheet extends ConsumerStatefulWidget {
  const GoalWhenSheet({super.key, required this.day, required this.timeOfDay, required this.reminder, required this.onChanged});
  final LocalDay day;
  final String timeOfDay;
  final int? reminder;
  final void Function(LocalDay day, String timeOfDay, int? reminder) onChanged;

  @override
  ConsumerState<GoalWhenSheet> createState() => _GoalWhenState();
}

class _GoalWhenState extends ConsumerState<GoalWhenSheet> {
  late LocalDay _day = widget.day;
  late String _time = widget.timeOfDay;
  late int? _reminder = widget.reminder;

  void _emit() => widget.onChanged(_day, _time, _reminder);

  Future<void> _pickTime() async {
    final v = await pickGoalTime(context, ref.read(copyProvider), _reminder);
    if (v == null || !mounted) return;
    setState(() => _reminder = v);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    Widget head(String emoji, String text, {Color color = DS.primaryGreen, Widget? trailing}) => Row(children: [
          IconChip(emoji, color: color),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: _label.copyWith(fontSize: 17))),
          ?trailing,
        ]);
    void setDay(LocalDay d) {
      setState(() => _day = d);
      _emit();
    }

    void setTime(String t) {
      setState(() => _time = t);
      _emit();
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      OutlineCard(
        child: Column(children: [
          head('ui/calendar', copy.t('goal.sheet.date')),
          const SizedBox(height: 14),
          GoalDateChoices(day: _day, onChanged: setDay),
        ]),
      ),
      const SizedBox(height: 14),
      OutlineCard(
        child: Column(children: [
          head('ui/clock', copy.t('goal.sheet.time_of_day')),
          const SizedBox(height: 14),
          GoalTimeChoices(timeOfDay: _time, onChanged: setTime),
        ]),
      ),
      const SizedBox(height: 14),
      OutlineCard(
        onTap: _reminder == null ? null : _pickTime,
        child: head(
          'ui/bell',
          _reminder == null ? copy.t('goal.sheet.remind') : '${copy.t('goal.sheet.remind')} · ${JalaliFormatter.time(_reminder!)}',
          color: DS.energy,
          trailing: Switch(
            value: _reminder != null,
            activeTrackColor: DS.primaryGreen,
            onChanged: (on) {
              if (on) {
                _pickTime();
              } else {
                setState(() => _reminder = null);
                _emit();
              }
            },
          ),
        ),
      ),
    ]);
  }
}

/// Today / tomorrow / a day from the Persian calendar.
class GoalDateChoices extends ConsumerWidget {
  const GoalDateChoices({super.key, required this.day, required this.onChanged});
  final LocalDay day;
  final ValueChanged<LocalDay> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final today = ref.watch(todayProvider);
    final other = day != today && day != today.addDays(1);
    return Row(children: [
      Expanded(child: ChoiceBox(label: copy.t('goal.sheet.date.today'), selected: day == today, onTap: () => onChanged(today))),
      const SizedBox(width: 8),
      Expanded(child: ChoiceBox(label: copy.t('goal.sheet.date.tomorrow'), selected: day == today.addDays(1), onTap: () => onChanged(today.addDays(1)))),
      const SizedBox(width: 8),
      Expanded(
        child: ChoiceBox(
          label: other ? JalaliFormatter.dayMonth(day) : copy.t('goal.sheet.date.pick'),
          selected: other,
          onTap: () async {
            final d = await showModalBottomSheet<LocalDay>(
              context: context,
              backgroundColor: DS.card,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusSheet))),
              builder: (_) => _JalaliCalendar(today: today, selected: day),
            );
            if (d != null) onChanged(d);
          },
        ),
      ),
    ]);
  }
}

/// Four illustrated tiles (morning, afternoon, evening, bedtime) and "any time".
class GoalTimeChoices extends ConsumerWidget {
  const GoalTimeChoices({super.key, required this.timeOfDay, required this.onChanged});
  final String timeOfDay;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var r = 0; r < 2; r++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final t in goalTimesOfDay.sublist(r * 2, r * 2 + 2)) ...[
                if (t != goalTimesOfDay[r * 2]) const SizedBox(width: 8),
                Expanded(child: ChoiceBox(label: copy.t('goal.editor.when.$t'), emoji: 'time/$t', selected: timeOfDay == t, onTap: () => onChanged(t))),
              ],
            ]),
          ),
        ),
      SizedBox(width: double.infinity, child: ChoiceBox(label: copy.t('goal.editor.when.any'), selected: timeOfDay == 'any', onTap: () => onChanged('any'))),
    ]);
  }
}

/// Grid of every goal sticker (from the art manifest); returns the chosen sticker id.
Future<String?> pickGoalIcon(BuildContext context, CopyResolver copy) => showGoalSheet<String>(
      context,
      title: copy.t('goal.options.icon'),
      builder: (ctx) => FutureBuilder<String>(
        future: DefaultAssetBundle.of(ctx).loadString('assets/art/emoji/manifest.json'),
        builder: (ctx, snap) {
          if (!snap.hasData) return const SizedBox(height: 120);
          final ids = [
            for (final m in (jsonDecode(snap.data!) as List).cast<Map<String, dynamic>>())
              if (!const ['ui', 'nav', 'glyph'].contains((m['id'] as String).split('/').first)) m['id'] as String,
          ];
          return Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (final id in ids)
              Material(
                color: DS.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: DS.outline, width: 2)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: () => Navigator.pop(ctx, id), child: Padding(padding: const EdgeInsets.all(8), child: EmojiArt(id, size: 44))),
              ),
          ]);
        },
      ),
    );

/// Persian month grid, Saturday first; days before [today] cannot be chosen.
class _JalaliCalendar extends ConsumerStatefulWidget {
  const _JalaliCalendar({required this.today, required this.selected});
  final LocalDay today;
  final LocalDay selected;

  @override
  ConsumerState<_JalaliCalendar> createState() => _JalaliCalendarState();
}

class _JalaliCalendarState extends ConsumerState<_JalaliCalendar> {
  late Jalali _month = _firstOf(JalaliFormatter.toJalali(widget.selected));

  static Jalali _firstOf(Jalali j) => Jalali(j.year, j.month, 1);

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final thisMonth = _firstOf(JalaliFormatter.toJalali(widget.today));
    final canGoBack = _month.year > thisMonth.year || (_month.year == thisMonth.year && _month.month > thisMonth.month);
    final lead = LocalDay.fromDate(_month.toDateTime()).weekdayIndex;
    final cells = lead + _month.monthLength;
    const dayStyle = TextStyle(color: DS.textPrimary, fontSize: 16, fontWeight: FontWeight.w600);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Text('${JalaliFormatter.monthNames[_month.month - 1]} ${toPersianDigits(_month.year)}', style: _label.copyWith(fontSize: 18, color: DS.textPrimary)),
            ),
            IconButton(
              tooltip: copy.t('goal.sheet.month.prev'),
              onPressed: canGoBack ? () => setState(() => _month = _month.month == 1 ? Jalali(_month.year - 1, 12, 1) : Jalali(_month.year, _month.month - 1, 1)) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            IconButton(
              tooltip: copy.t('goal.sheet.month.next'),
              onPressed: () => setState(() => _month = _month.month == 12 ? Jalali(_month.year + 1, 1, 1) : Jalali(_month.year, _month.month + 1, 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            for (final n in JalaliFormatter.weekdayNames) Expanded(child: Center(child: ExcludeSemantics(child: Text(n.substring(0, 1), style: _label.copyWith(fontSize: 14))))),
          ]),
          const SizedBox(height: 4),
          for (var row = 0; row * 7 < cells; row++)
            Row(children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: Builder(builder: (context) {
                      final n = row * 7 + col - lead + 1;
                      if (n < 1 || n > _month.monthLength) return const SizedBox();
                      final day = LocalDay.fromDate(Jalali(_month.year, _month.month, n).toDateTime());
                      final past = day.compareTo(widget.today) < 0;
                      final selected = day == widget.selected;
                      return Semantics(
                        button: !past,
                        selected: selected,
                        label: JalaliFormatter.weekdayDate(day),
                        child: ExcludeSemantics(
                          child: InkResponse(
                            onTap: past ? null : () => Navigator.pop(context, day),
                            radius: 24,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected ? DS.primaryGreen : null,
                                  border: day == widget.today && !selected ? Border.all(color: DS.textSecondary, width: 1.5) : null,
                                ),
                                child: Text(
                                  toPersianDigits(n),
                                  style: dayStyle.copyWith(color: selected ? DS.onPrimary : (past ? DS.neutralButtonEdge : DS.textPrimary)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ]),
        ]),
      ),
    );
  }
}

/// Opens the time sheet; returns minutes from midnight, or null when it is closed without saving.
Future<int?> pickGoalTime(BuildContext context, CopyResolver copy, int? initial) =>
    showGoalSheet<int>(context, title: copy.t('goal.sheet.time.title'), builder: (_) => _TimeSheet(initial: initial ?? 9 * 60));

/// Hour and minute wheels (24h), three presets and a save button; pops minutes from midnight.
class _TimeSheet extends ConsumerStatefulWidget {
  const _TimeSheet({required this.initial});
  final int initial;

  @override
  ConsumerState<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends ConsumerState<_TimeSheet> {
  late int _minutes = widget.initial;
  late final _hour = FixedExtentScrollController(initialItem: widget.initial ~/ 60);
  late final _minute = FixedExtentScrollController(initialItem: widget.initial % 60);

  static const _presets = {'morning': 9 * 60, 'noon': 13 * 60, 'evening': 20 * 60};

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  Widget _wheel(FixedExtentScrollController controller, int count, ValueChanged<int> onChanged) => SizedBox(
        width: 72,
        height: 180,
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: 44,
          looping: true,
          selectionOverlay: const SizedBox(),
          onSelectedItemChanged: onChanged,
          children: [
            for (var i = 0; i < count; i++)
              Center(child: Text(toPersianDigits(i.toString().padLeft(2, '0')), style: const TextStyle(color: DS.textPrimary, fontSize: 26, fontWeight: FontWeight.w700))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(alignment: Alignment.center, children: [
        Container(height: 48, decoration: BoxDecoration(color: DS.chipBg, borderRadius: BorderRadius.circular(12))),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _wheel(_hour, 24, (h) => setState(() => _minutes = (h % 24) * 60 + _minutes % 60)),
            const Text(':', style: TextStyle(color: DS.textPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
            _wheel(_minute, 60, (m) => setState(() => _minutes = (_minutes ~/ 60) * 60 + m % 60)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        for (final p in _presets.entries) ...[
          if (p.key != 'morning') const SizedBox(width: 8),
          Expanded(
            child: ChoiceBox(
              label: copy.t('goal.sheet.time.preset.${p.key}'),
              caption: JalaliFormatter.time(p.value),
              selected: _minutes == p.value,
              onTap: () {
                _hour.jumpToItem(p.value ~/ 60);
                _minute.jumpToItem(p.value % 60);
                setState(() => _minutes = p.value);
              },
            ),
          ),
        ],
      ]),
      const SizedBox(height: 20),
      ChunkyButton(label: copy.t('common.save'), onPressed: () => Navigator.pop(context, _minutes)),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Repeat

class GoalRepeatSheet extends ConsumerStatefulWidget {
  const GoalRepeatSheet({super.key, required this.repeat, required this.mask, required this.day, required this.onChanged});
  final String repeat;
  final int mask;
  final LocalDay day;
  final void Function(String repeat, int mask) onChanged;

  @override
  ConsumerState<GoalRepeatSheet> createState() => _GoalRepeatState();
}

class _GoalRepeatState extends ConsumerState<GoalRepeatSheet> {
  late String _repeat = widget.repeat;
  late int _mask = widget.mask;

  void _set(String repeat, [int? mask]) {
    setState(() {
      _repeat = repeat;
      if (mask != null) _mask = mask;
    });
    widget.onChanged(_repeat, _mask);
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    String label(String r) => goalRepeatLabel(copy, r, _mask, widget.day);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      OutlineCard(padding: EdgeInsets.zero, child: _checkRow(label('once'), _repeat == 'once', () => _set('once'))),
      const SizedBox(height: 14),
      OutlineCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          _checkRow(label('daily'), _repeat == 'daily', () => _set('daily')),
          _divider,
          _checkRow(label('weekdays'), _repeat == 'weekdays', () => _set('weekdays', weekdaysMask)),
          _divider,
          _checkRow(label('weekly_on'), _repeat == 'weekly_on', () => _set('weekly_on', 1 << widget.day.weekdayIndex)),
          _divider,
          _checkRow(label('monthly'), _repeat == 'monthly', () => _set('monthly')),
          _divider,
          _checkRow(_repeat == 'custom' ? label('custom') : copy.t('goal.editor.repeat.custom'), _repeat == 'custom', () async {
            final m = await showGoalSheet<int>(context, title: copy.t('goal.sheet.custom_days.title'), builder: (_) => _CustomDaysSheet(mask: _repeat == 'custom' ? _mask : 0));
            if (m != null && m != 0) _set('custom', m);
          }),
        ]),
      ),
    ]);
  }
}

class _CustomDaysSheet extends ConsumerStatefulWidget {
  const _CustomDaysSheet({required this.mask});
  final int mask;

  @override
  ConsumerState<_CustomDaysSheet> createState() => _CustomDaysState();
}

class _CustomDaysState extends ConsumerState<_CustomDaysSheet> {
  late int _mask = widget.mask;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        OutlineCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) _divider,
              _checkRow(JalaliFormatter.weekdayNames[i], (_mask >> i) & 1 == 1, () => setState(() => _mask ^= 1 << i)),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        ChunkyButton(label: ref.watch(copyProvider).t('common.save'), onPressed: _mask == 0 ? null : () => Navigator.pop(context, _mask)),
      ]);
}

// ---------------------------------------------------------------------------------------------------------------------
// Area

class GoalAreaSheet extends ConsumerStatefulWidget {
  const GoalAreaSheet({super.key, required this.area, required this.onChanged});
  final String? area;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<GoalAreaSheet> createState() => _GoalAreaState();
}

class _GoalAreaState extends ConsumerState<GoalAreaSheet> {
  late String? _area = widget.area;

  void _set(String? a) {
    setState(() => _area = a);
    widget.onChanged(a);
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    Widget chip(Widget child) => Container(width: 40, height: 40, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: DS.sheetBg), child: child);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      OutlineCard(
        padding: EdgeInsets.zero,
        child: _checkRow(copy.t('area.none'), _area == null, () => _set(null), leading: chip(const EmojiArt('ui/minus', size: 22))),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 8),
        child: Text(copy.t('area.picker.more'), style: _label.copyWith(fontSize: 13)),
      ),
      OutlineCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final a in goalAreas) ...[
            if (a != goalAreas.first) _divider,
            _checkRow(copy.t('area.$a.name'), _area == a, () => _set(a), leading: chip(EmojiArt(goalEmoji(area: a), size: 30))),
          ],
        ]),
      ),
      const SizedBox(height: 20),
      ChunkyButton(label: copy.t('common.done'), onPressed: () => Navigator.pop(context)),
    ]);
  }
}
