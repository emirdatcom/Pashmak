import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/duration_format.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../cat/presentation/cat_view.dart';
import '../domain/quest_engine.dart';
import '../domain/quest_service.dart';
import 'quest_art.dart';

/// Today's reflective question (`reflection_prompts` entry), picked deterministically per day; null when the pack is empty.
final todayReflectionProvider = Provider<Map<String, dynamic>?>((ref) {
  final prompts = ((ref.watch(contentRepositoryProvider).entries('reflection_prompts') as List?) ?? const []).cast<Map<String, dynamic>>();
  final today = ref.watch(todayProvider);
  return prompts.isEmpty ? null : prompts[(today.year * 400 + today.month * 31 + today.day) % prompts.length];
});

const _headline = TextStyle(fontFamily: AppText.headline, fontFamilyFallback: AppText.headlineFallback);

/// Quests tab (screenshots 01/04): season banner, daily quests on a timeline with a countdown to the next day, and
/// special quests with hints.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    ref.watch(tickProvider);
    final daily = ref.watch(dailyQuestsProvider).value ?? const <QuestView>[];
    final special = ref.watch(specialQuestsProvider).value ?? const <QuestView>[];
    final paused = ref.watch(pausedProvider).value ?? false;
    final now = ref.watch(clockProvider).now();
    final today = ref.watch(todayProvider);
    final startHour = ref.watch(dayStartHourProvider);
    final next = today.addDays(1);
    final untilNext = DateTime(next.year, next.month, next.day, startHour).difference(now);

    return Scaffold(
      backgroundColor: DS.bgQuests,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            _SeasonBanner(today: today),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _SectionTitle(copy.t('quest.daily.title'))),
                if (!paused) CountdownChip(label: formatRemaining(copy, untilNext)),
              ],
            ),
            const SizedBox(height: 10),
            if (paused)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  copy.t('quest.paused'),
                  style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w700),
                ),
              )
            else
              QuestTimeline(rows: [for (final q in daily) (q.state == QuestState.claimed, _QuestCard(view: q, special: false))]),
            const SizedBox(height: 24),
            _SectionTitle(copy.t('quest.special.title')),
            const SizedBox(height: 12),
            for (final q in special)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _QuestCard(view: q, special: true),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(color: DS.onDark, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.6),
    ),
  );
}

/// Dark seasonal card: kicker, outlined title, a big padlock over the art and a green ribbon with the days left.
/// The art (`assets/art/background/season_<key>.webp`) is optional: without it the card is a dark gradient.
class _SeasonBanner extends ConsumerWidget {
  const _SeasonBanner({required this.today});
  final LocalDay today;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).feature('seasonal_packs')) return const SizedBox.shrink();
    final copy = ref.watch(copyProvider);
    final catalog = ref.watch(seasonalCatalogProvider);
    final active = catalog.active(today);
    final upcoming = [
      for (final p in catalog.packs)
        if (p.startDate.isAfter(today.date)) p,
    ]..sort((a, b) => a.startDate.compareTo(b.startDate));
    if (active.isEmpty && upcoming.isEmpty) return const SizedBox.shrink();
    final locked = active.isEmpty;
    final pack = locked ? upcoming.first : active.first;
    final ribbon = locked ? copy.t('quest.season.locked', {'n': pack.startDate.difference(today.date).inDays}) : copy.t('quest.season.active');
    return Semantics(
      container: true,
      label: '${pack.name}. $ribbon',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1.62,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DS.radiusCard + 4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.1, colors: [DS.bgShopPanel, DS.seasonBanner]),
                  ),
                ),
                Image.asset(
                  'assets/art/background/season_${pack.key}.webp',
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                // Darken the art so the title and the lock read on top of it.
                if (locked) const ColoredBox(color: DS.seasonScrim),
                Column(
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      copy.t('quest.season.kicker'),
                      style: const TextStyle(color: DS.onDark, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                    ),
                    _OutlinedTitle(pack.name),
                    Expanded(
                      child: locked ? const Center(child: EmojiArt('misc/padlock', size: 96)) : const SizedBox(),
                    ),
                    Padding(padding: const EdgeInsets.fromLTRB(36, 0, 36, 20), child: _Ribbon(ribbon)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Big headline with a thick warm-brown outline, like a sticker title.
class _OutlinedTitle extends StatelessWidget {
  const _OutlinedTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    return Stack(
      children: [
        Text(
          text,
          style: _headline.copyWith(
            fontSize: size,
            fontWeight: FontWeight.w800,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeJoin = StrokeJoin.round
              ..color = DS.bgShopPanel,
          ),
        ),
        Text(
          text,
          style: _headline.copyWith(fontSize: size, fontWeight: FontWeight.w800, color: DS.onDark),
        ),
      ],
    );
  }
}

/// Green banner with notched (swallow-tail) ends and a lighter top half.
class _Ribbon extends StatelessWidget {
  const _Ribbon(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _RibbonClipper(),
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.5, 0.5], colors: [DS.seasonRibbonLight, DS.seasonRibbon]),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: DS.onDark, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8),
      ),
    ),
  );
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    const notch = 14.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width - notch, s.height / 2)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..lineTo(notch, s.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(_RibbonClipper old) => false;
}

class _QuestCard extends ConsumerWidget {
  const _QuestCard({required this.view, required this.special});
  final QuestView view;
  final bool special;

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final copy = ref.read(copyProvider);
    final r = await ref.read(questServiceProvider).claim(view.def.key, special: special);
    if (r.status == ClaimStatus.claimed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('quest.claimed_toast', {'n': r.coins}))));
    }
  }

  void _go(BuildContext context) => context.push(view.def.route);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final q = view.def;
    final art = QuestArt.of(q.key);
    final done = view.state == QuestState.claimed;
    final ready = view.state == QuestState.ready;
    // The daily question shows the question itself as the title, under a kicker.
    final reflection = q.metric == 'reflection_today' ? ref.watch(todayReflectionProvider) : null;
    final title = reflection != null && !done ? copy.t(reflection['prompt_key'] as String) : copy.t(q.titleKey);
    final kicker = done || art.kickerKey == null ? null : copy.t(art.kickerKey!);

    if (done) {
      return Semantics(
        label: title,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(color: DS.doneBg, borderRadius: BorderRadius.circular(DS.radiusCard + 4)),
          child: Row(
            children: [
              const _DoneSeal(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: DS.questDone,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: DS.questDone,
                    decorationThickness: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final Widget trailing;
    if (ready) {
      trailing = SizedBox(
        width: 96,
        child: ChunkyButton(label: copy.t('quest.claim'), height: 56, onPressed: () => _claim(context, ref)),
      );
    } else if (special && q.hintKey != null) {
      trailing = HintButton(label: copy.t('quest.hint'), onPressed: () => _showHint(context, ref));
    } else {
      trailing = SizedBox(
        width: 72,
        child: Semantics(
          button: true,
          label: copy.t('quest.go'),
          child: ChunkyButton.neutral(label: '', icon: Icons.arrow_forward_rounded, height: 60, onPressed: () => _go(context)),
        ),
      );
    }
    return Semantics(
      label: title,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(DS.radiusCard + 4),
          boxShadow: const [BoxShadow(color: DS.questCardEdge, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            QuestTile(art: art, size: special ? 64 : 72),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kicker != null)
                    Text(
                      kicker,
                      style: const TextStyle(color: DS.questKicker, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                    ),
                  Text(
                    title,
                    style: const TextStyle(color: DS.textDeep, fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  ProgressPill(value: view.shown, max: q.target, height: 30, knob: true, endEmoji: art.progressEmoji),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _showHint(BuildContext context, WidgetRef ref) {
    final copy = ref.read(copyProvider);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.t(view.def.titleKey),
                style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(copy.t(view.def.hintKey!), style: const TextStyle(color: DS.textPrimary, height: 1.6)),
              const SizedBox(height: 16),
              ChunkyButton(
                label: copy.t('quest.go'),
                onPressed: () {
                  Navigator.pop(ctx);
                  unawaited(context.push(view.def.route));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green scalloped seal with a white tick: the done state of a quest.
class _DoneSeal extends StatelessWidget {
  const _DoneSeal();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 58,
    height: 58,
    child: CustomPaint(
      painter: _SealPainter(),
      child: const Center(child: Icon(Icons.check_rounded, color: DS.onDark, size: 32)),
    ),
  );
}

class _SealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const bumps = 10;
    final path = Path();
    for (var i = 0; i <= bumps * 8; i++) {
      final a = i * 2 * math.pi / (bumps * 8);
      final rr = r * (0.9 + 0.1 * math.cos(a * bumps));
      final o = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = DS.questDone);
  }

  @override
  bool shouldRepaint(_SealPainter old) => false;
}

/// The daily question (screenshot: question bubble over a purple page with the cat below it). Two or three answers,
/// each a sticker in a white circle with its label; Submit stays disabled until one is picked. The answer stays on the
/// device.
class ReflectScreen extends ConsumerStatefulWidget {
  const ReflectScreen({super.key});
  @override
  ConsumerState<ReflectScreen> createState() => _ReflectScreenState();
}

class _ReflectScreenState extends ConsumerState<ReflectScreen> {
  String? _picked;
  bool _busy = false;

  // Opened from a notification or a deep link there is nothing to pop: fall back to the quests tab.
  void _leave() => context.canPop() ? context.pop() : context.go(Routes.quests);

  Future<void> _submit() async {
    final o = _picked;
    if (o == null || _busy) return;
    setState(() => _busy = true);
    final copy = ref.read(copyProvider);
    await ref.read(questServiceProvider).answerReflection(o);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('quest.reflect.saved'))));
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final p = ref.watch(todayReflectionProvider);
    final options = p == null
        ? const <String>[]
        : [
            for (final o in const ['a', 'b', 'c'])
              if (p['${o}_key'] != null) o,
          ];
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: DS.bgExercises,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The cat stands below the bubble, on the side the tail points to, on a soft ground shadow.
          const PositionedDirectional(
            start: 10,
            bottom: 150,
            width: 260,
            height: 34,
            child: DecoratedBox(decoration: BoxDecoration(color: DS.reflectGround, borderRadius: BorderRadius.all(Radius.elliptical(130, 17)))),
          ),
          const PositionedDirectional(
            start: -10,
            bottom: 160,
            width: 300,
            height: 400,
            child: ExcludeSemantics(child: FittedBox(child: CatView())),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              painter: _BubblePainter(rtl: rtl),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          onPressed: () => _leave(),
                          tooltip: copy.t('common.back'),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DS.questKicker, size: 30),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (p != null) ...[
                        Semantics(
                          header: true,
                          child: Text(
                            copy.t(p['prompt_key'] as String),
                            textAlign: TextAlign.center,
                            style: _headline.copyWith(color: DS.textDeep, fontSize: 26, fontWeight: FontWeight.w800, height: 1.35),
                          ),
                        ),
                        const SizedBox(height: 28),
                        LayoutBuilder(
                          builder: (context, c) {
                            final d = math.min(124.0, (c.maxWidth - 16 * (options.length - 1)) / 3);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final o in options)
                                  _Option(
                                    diameter: d,
                                    sticker: (p['${o}_icon'] as String?) ?? 'faces/thinking',
                                    label: copy.t(p['${o}_key'] as String),
                                    selected: _picked == o,
                                    onTap: () => setState(() => _picked = o),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        _picked == null
                            ? _DisabledSubmit(label: copy.t('quest.reflect.submit'))
                            : ChunkyButton(label: copy.t('quest.reflect.submit'), onPressed: _busy ? null : _submit),
                        const SizedBox(height: 12),
                        Text(
                          copy.t('quest.reflect.private'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: DS.textMuted, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.diameter, required this.sticker, required this.label, required this.selected, required this.onTap});
  final double diameter;
  final String sticker;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dur = MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 150);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: diameter + 8,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: dur,
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DS.card,
                    border: Border.all(color: selected ? DS.primaryGreen : DS.reflectOptionRing, width: selected ? 4 : 3),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedScale(
                    duration: dur,
                    scale: selected ? 1.12 : 1,
                    child: EmojiArt(sticker, size: diameter * 0.46),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(color: DS.textDeep, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisabledSubmit extends StatelessWidget {
  const _DisabledSubmit({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: false,
    label: label,
    child: ExcludeSemantics(
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(top: DS.buttonEdge),
        decoration: BoxDecoration(color: DS.submitDisabled, borderRadius: BorderRadius.circular(DS.radiusButton)),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: DS.submitDisabledText, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

/// Off-white speech bubble filling the top of the page: a wide curved bottom edge and a tail pointing down to the cat.
class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.rtl});
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything stays inside the painted box: the curve bottoms out 70dp above it and the tail tip touches it.
    final w = size.width, h = size.height;
    final edge = h - 140; // where the curve meets the sides
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, edge)
      ..quadraticBezierTo(w * 0.5, h, 0, edge)
      ..close();
    // Tail, drawn for a cat on the left and mirrored in RTL.
    double x(double f) => rtl ? w * (1 - f) : w * f;
    final tail = Path()
      ..moveTo(x(0.56), h - 80)
      ..quadraticBezierTo(x(0.6), h - 30, x(0.57), h - 4)
      ..quadraticBezierTo(x(0.64), h - 30, x(0.74), h - 86)
      ..close();
    path.addPath(tail, Offset.zero);
    canvas.drawPath(path, Paint()..color = DS.reflectBubble);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.rtl != rtl;
}
