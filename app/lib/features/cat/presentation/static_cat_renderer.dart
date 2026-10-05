import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/cat_renderer.dart';

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
                child: CustomPaint(size: const Size(160, 160), painter: _CatPainter(widget.state.mood, _breath.value > 0.5)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CatPainter extends CustomPainter {
  _CatPainter(this.mood, this.blink);
  final CatMood mood;
  final bool blink;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final fur = Paint()..color = AppColors.orange;
    final dark = Paint()..color = AppColors.orangeDark;
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
    final sleepy = mood == CatMood.sleepy || blink;
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
    // turquoise collar
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, 62), width: 84, height: 12), const Radius.circular(6)), Paint()..color = AppColors.turquoise);
    canvas.drawCircle(c.translate(0, 72), 6, Paint()..color = AppColors.turquoiseDark);
  }

  @override
  bool shouldRepaint(_CatPainter old) => old.mood != mood || old.blink != blink;
}
