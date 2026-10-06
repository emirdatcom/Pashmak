import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Rotates the hue of [child] by [degrees] (colour variants of one piece of item art). 0 leaves it untouched.
class HueShift extends StatelessWidget {
  const HueShift({super.key, required this.degrees, required this.child});
  final int degrees;
  final Widget child;

  @override
  Widget build(BuildContext context) => degrees % 360 == 0 ? child : ColorFiltered(colorFilter: ColorFilter.matrix(hueMatrix(degrees)), child: child);

  /// Standard luminance-preserving hue rotation.
  static List<double> hueMatrix(int degrees) {
    final a = degrees * math.pi / 180;
    final c = math.cos(a), s = math.sin(a);
    const lr = 0.213, lg = 0.715, lb = 0.072;
    return [
      lr + c * (1 - lr) + s * (-lr), lg + c * (-lg) + s * (-lg), lb + c * (-lb) + s * (1 - lb), 0, 0,
      lr + c * (-lr) + s * 0.143, lg + c * (1 - lg) + s * 0.140, lb + c * (-lb) + s * (-0.283), 0, 0,
      lr + c * (-lr) + s * (-(1 - lr)), lg + c * (-lg) + s * lg, lb + c * (1 - lb) + s * lb, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}
