import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/cat_renderer.dart';

/// The final layered cat art (assets/art/cat): body, head with attached ears, two arms, two legs, a tail and two dot
/// eyes, stacked in a fixed design space and animated with a single looping controller (tail sway, arm swing, head
/// bob, blinking). Only the default orange cat without accessories uses it; everything else still falls back to the
/// vector placeholder until more art exists.
class LayeredCat extends StatefulWidget {
  const LayeredCat({super.key, required this.state, this.height = 140});
  final CatVisualState state;
  final double height;

  /// Whether [state] can be drawn by the layered art.
  static bool supports(CatVisualState s) =>
      !s.faceOnly &&
      s.accessories.isEmpty &&
      s.background == null &&
      s.fur == CatFur.orangeCream;

  @override
  State<LayeredCat> createState() => _LayeredCatState();
}

// Design space in source pixels (x already shifted so the leftmost part sits at 0).
const double _w = 870, _h = 1172, _ox = 345;

class _Part {
  const _Part(this.name, this.x, this.y, this.w, this.h);
  final String name;
  final double
  x,
  y,
  w,
  h; // x is the part's horizontal centre relative to the cat axis, y its top
  String get asset => 'assets/art/cat/$name.png';
}

const _body = _Part('body', 0, 430, 548, 463);
const _head = _Part('head', 0, 0, 602, 502);
const _armL = _Part('arm_left', -215, 470, 260, 363);
const _armR = _Part('arm_right', 215, 470, 257, 362);
const _legL = _Part('leg_left', -110, 760, 228, 412);
const _legR = _Part('leg_right', 110, 760, 228, 412);
const _tail = _Part('tail', 357, 520, 334, 414);
const _eyeL = _Part('eye_left', -135, 255, 55, 58);
const _eyeR = _Part('eye_right', 135, 255, 56, 58);

class _LayeredCatState extends State<LayeredCat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Widget _img(
    _Part p, {
    double angle = 0,
    Alignment pivot = Alignment.center,
    double scaleY = 1,
    double dy = 0,
  }) {
    Widget w = Image.asset(
      p.asset,
      width: p.w,
      height: p.h,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
    if (scaleY != 1) {
      w = Transform.scale(
        scaleY: scaleY,
        alignment: Alignment.center,
        child: w,
      );
    }
    if (angle != 0) {
      w = Transform.rotate(angle: angle, alignment: pivot, child: w);
    }
    return Positioned(
      left: p.x + _ox - p.w / 2,
      top: p.y + dy,
      width: p.w,
      height: p.h,
      child: w,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final eyesClosed =
        widget.state.mood == CatMood.sleepy ||
        widget.state.mood == CatMood.breathing;
    return SizedBox(
      height: widget.height,
      child: FittedBox(
        child: SizedBox(
          width: _w,
          height: _h,
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final t = reduce ? 0.0 : _loop.value;
              final tail = math.sin(t * 2 * math.pi) * 0.14;
              final arm = math.sin(t * 2 * math.pi) * 0.05;
              final bob = math.sin(t * 4 * math.pi) * 5;
              // two quick blinks per loop
              final blinking =
                  !reduce && ((t > 0.46 && t < 0.49) || (t > 0.93 && t < 0.96));
              final eye = (eyesClosed || blinking) ? 0.08 : 1.0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _img(_tail, angle: tail, pivot: const Alignment(-0.85, 0.85)),
                  _img(_legL),
                  _img(_legR),
                  _img(_body),
                  _img(_armL, angle: arm, pivot: const Alignment(0.7, -1)),
                  _img(_armR, angle: -arm, pivot: const Alignment(-0.7, -1)),
                  _img(_head, dy: bob),
                  _img(_eyeL, scaleY: eye, dy: bob),
                  _img(_eyeR, scaleY: eye, dy: bob),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
