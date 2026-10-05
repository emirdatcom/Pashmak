import 'package:flutter/material.dart';

/// Design tokens (docs/20 §6): warm cream, cat orange, collar turquoise. Text/background pairs are
/// chosen for WCAG AA contrast (checked in test/theme_test.dart).
class AppColors {
  const AppColors._();
  static const cream = Color(0xFFFFF6E8);
  static const creamDeep = Color(0xFFF6E7CF);
  static const orange = Color(0xFFE07B2A);
  static const orangeDark = Color(0xFF9A4A0C);
  static const turquoise = Color(0xFF1F8F8A);
  static const turquoiseDark = Color(0xFF0F5F5B);
  static const ink = Color(0xFF2B2118);
  static const inkSoft = Color(0xFF5B4A3A);
  static const danger = Color(0xFFB3261E);

  static const nightBg = Color(0xFF1E1812);
  static const nightSurface = Color(0xFF2A2219);
  static const nightInk = Color(0xFFF6E7CF);
}

class AppSpacing {
  const AppSpacing._();
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0;
}

class AppRadius {
  const AppRadius._();
  static const sm = 8.0, md = 16.0, lg = 24.0;
}

class AppText {
  const AppText._();
  static const family = 'Vazirmatn';
  static const textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.4),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.4),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6),
    bodyMedium: TextStyle(fontSize: 14, height: 1.6),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );
}
