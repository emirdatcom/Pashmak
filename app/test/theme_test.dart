import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/theme/app_theme.dart';
import 'package:pashmak_app/core/theme/tokens.dart';

double _lum(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  test('key text/background pairs meet WCAG AA (4.5:1)', () {
    for (final pair in [
      (AppColors.ink, AppColors.cream),
      (AppColors.inkSoft, AppColors.cream),
      (Colors.white, AppColors.orangeDark),
      (Colors.white, AppColors.turquoiseDark),
      (AppColors.nightInk, AppColors.nightBg),
      (AppColors.ink, AppColors.orange),
      (AppColors.danger, AppColors.cream),
    ]) {
      expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5), reason: '${pair.$1} on ${pair.$2}');
    }
  });

  test('themes build with the Persian font', () {
    expect(AppTheme.light.textTheme.bodyLarge!.fontFamily, 'Vazirmatn');
    expect(AppTheme.dark.brightness, Brightness.dark);
  });
}
