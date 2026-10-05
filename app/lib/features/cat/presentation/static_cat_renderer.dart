import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/cat_renderer.dart';
import 'layered_cat.dart';

/// MVP renderer (docs/20 §9): a vector cat with code-driven motion (breathing, blinking, bounce).
/// It is a stand-in until the final WebP art exists; the [CatRenderer] contract stays the same.
class StaticCatRenderer implements CatRenderer {
  const StaticCatRenderer();
  @override
  Widget build(BuildContext context, CatVisualState state) => _AnimatedCat(state: state);
}

class _AnimatedCat extends StatefulWidget {
  const _AnimatedCat({required this.state});
  final CatVisualState state;
  @override
  State<_AnimatedCat> createState() => _AnimatedCatState();
}

class _AnimatedCatState extends State<_AnimatedCat> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  CatMood? _lastMood;

  @override
  void didUpdateWidget(_AnimatedCat old) {
    super.didUpdateWidget(old);
    if (_lastMood != widget.state.mood && _lastMood != null) _bounce.forward(from: 0);
    _lastMood = widget.state.mood;
  }

  @override
  void initState() {
    super.initState();
    _lastMood = widget.state.mood;
  }

  @override
  void dispose() {
    _breath.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return GestureDetector(
      onTap: () => _bounce.forward(from: 0),
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _bounce]),
        builder: (context, _) {
          final breathe = reduce ? 1.0 : 1.0 + 0.02 * _breath.value;
          final hop = reduce ? 0.0 : -16 * math.sin(_bounce.value * math.pi);
          return Opacity(
            opacity: widget.state.activity == CatActivity.away ? 0.35 : 1,
            child: Transform.translate(
              offset: Offset(0, hop),
              child: Transform.scale(
                scale: breathe,
                child: LayeredCat.supports(widget.state) ? LayeredCat(state: widget.state) : CustomPaint(size: const Size(180, 180), painter: _CatPainter(widget.state, _breath.value > 0.5)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CatPainter extends CustomPainter {
  _CatPainter(this.state, this.blink) : mood = state.mood;
  final CatVisualState state;
  final CatMood mood;
  final bool blink;

  static const _backdrops = DS.catBackdrops;

  /// Placeholder backdrop colour derived from the item key until real art exists.
  static Color backdropFor(String key) => _backdrops[key.codeUnits.fold<int>(0, (a, b) => a + b) % _backdrops.length];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final bg = state.background;
    if (bg != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)), Paint()..color = backdropFor(bg));
    }
    final (furColor, spotColor) = switch (state.fur) {
      CatFur.orangeCream => (AppColors.orange, AppColors.orangeDark),
      CatFur.smokeGray => (DS.textSecondary, DS.textPrimary),
      CatFur.tricolor => (DS.bgCat, AppColors.orangeDark),
    };
    final fur = Paint()..color = furColor;
    final dark = Paint()..color = spotColor;
    // Stage proportions: a kitten has a bigger head on a smaller body; an adult is rounder and larger overall.
    final headScale = switch (state.stage) { CatStage.kitten => 1.08, CatStage.young => 1.0, CatStage.adult => 0.94 };
    final bodyScale = switch (state.stage) { CatStage.kitten => 0.8, CatStage.young => 0.95, CatStage.adult => 1.1 };
    if (!state.faceOnly) {
      // chubby round body and thick tail behind the head (placeholder for the layered final art)
      canvas.drawOval(Rect.fromCenter(center: c.translate(0, 74), width: 110 * bodyScale, height: 70 * bodyScale), fur);
      final tail = Path()
        ..moveTo(c.dx + 46 * bodyScale, c.dy + 80)
        ..quadraticBezierTo(c.dx + 92 * bodyScale, c.dy + 70, c.dx + 80 * bodyScale, c.dy + 30)
        ..quadraticBezierTo(c.dx + 70 * bodyScale, c.dy + 60, c.dx + 44 * bodyScale, c.dy + 62)
        ..close();
      canvas.drawPath(tail, fur);
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(headScale);
    canvas.translate(-c.dx, -c.dy);
    final ink = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = AppColors.ink;
    // ears
    for (final s in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(c.dx + s * 22, c.dy - 40)
        ..lineTo(c.dx + s * 58, c.dy - 74)
        ..lineTo(c.dx + s * 62, c.dy - 20)
        ..close();
      canvas.drawPath(p, fur);
    }
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, 10), width: 128, height: 112), fur);
    // spot over one eye
    canvas.drawCircle(c.translate(-26, -4), 16, dark);
    // eyes
    final eyeY = c.dy - 2;
    final sleepy = mood == CatMood.sleepy || mood == CatMood.breathing || blink;
    for (final dx in [-26.0, 26.0]) {
      final e = Offset(c.dx + dx, eyeY);
      if (sleepy) {
        canvas.drawLine(e.translate(-8, 0), e.translate(8, 0), ink);
      } else if (mood == CatMood.sad) {
        canvas.drawCircle(e, 6, fill);
        canvas.drawLine(e.translate(-8, -12), e.translate(8, -8 * (dx < 0 ? 1 : -1) - 4), ink);
      } else if (mood == CatMood.proud) {
        canvas.drawArc(Rect.fromCenter(center: e, width: 18, height: 14), math.pi, math.pi, false, ink);
      } else {
        canvas.drawCircle(e, 7, fill);
      }
    }
    // nose + mouth
    canvas.drawCircle(c.translate(0, 18), 5, Paint()..color = AppColors.danger);
    final mouth = Path();
    if (mood == CatMood.sad) {
      mouth
        ..moveTo(c.dx - 12, c.dy + 38)
        ..quadraticBezierTo(c.dx, c.dy + 28, c.dx + 12, c.dy + 38);
    } else {
      mouth
        ..moveTo(c.dx - 12, c.dy + 28)
        ..quadraticBezierTo(c.dx, c.dy + 40, c.dx + 12, c.dy + 28);
    }
    canvas.drawPath(mouth, ink);
    // collar (default turquoise; an equipped collar item overrides it)
    final collar = state.accessories.where((a) => a.startsWith('collar_')).firstOrNull;
    final collarColor = collar == 'collar_red' ? AppColors.danger : AppColors.turquoise;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, 62), width: 84, height: 12), const Radius.circular(6)), Paint()..color = collarColor);
    canvas.drawCircle(c.translate(0, 72), 6, Paint()..color = AppColors.turquoiseDark);
    // glasses
    final glasses = state.accessories.where((a) => a.startsWith('glasses_')).firstOrNull;
    if (glasses != null) {
      final rim = Paint()
        ..color = DS.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (final dx in [-26.0, 26.0]) {
        canvas.drawCircle(c.translate(dx, -2), glasses == 'glasses_star' ? 14 : 13, rim);
      }
      canvas.drawLine(c.translate(-13, -2), c.translate(13, -2), rim);
    }
    // scarf
    final scarf = state.accessories.where((a) => a.startsWith('scarf_')).firstOrNull;
    if (scarf != null) {
      final color = switch (scarf) { 'scarf_stripe' => DS.areaNutrition, 'scarf_silk' => DS.areaSelfKindness, _ => DS.areaFocus };
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, 52), width: 96, height: 16), const Radius.circular(8)), Paint()..color = color);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(30, 66), width: 14, height: 28), const Radius.circular(6)), Paint()..color = color);
    }
    // hat
    final hat = state.accessories.where((a) => a.startsWith('hat_')).firstOrNull;
    if (hat == 'hat_beanie') {
      final p = Path()
        ..moveTo(c.dx - 40, c.dy - 36)
        ..quadraticBezierTo(c.dx, c.dy - 96, c.dx + 40, c.dy - 36)
        ..close();
      canvas.drawPath(p, Paint()..color = AppColors.turquoiseDark);
      canvas.drawCircle(c.translate(0, -82), 7, Paint()..color = DS.onDark);
    } else if (hat == 'hat_flower') {
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5;
        canvas.drawCircle(c.translate(math.cos(a) * 9, -62 + math.sin(a) * 9), 7, Paint()..color = DS.catFlowerPetal);
      }
      canvas.drawCircle(c.translate(0, -62), 5, Paint()..color = DS.catFlowerCore);
    } else if (hat == 'hat_felt') {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, -52), width: 70, height: 36), const Radius.circular(16)), Paint()..color = DS.bgShopPanel);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CatPainter old) => old.mood != mood || old.blink != blink || old.state.stage != state.stage || old.state.fur != state.fur || old.state.faceOnly != state.faceOnly || old.state.accessories.join() != state.accessories.join() || old.state.background != state.background;
}
