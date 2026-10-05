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

/// Design-system tokens of the redesign (prompt 22, docs/design-system.md). Sampled from the reference look and
/// nudged where needed so text on them reaches WCAG AA (checked in test/theme_test.dart). No colour literals
/// outside this file.
class DS {
  const DS._();
  // tab backgrounds
  static const bgQuests = Color(0xFF946A47);
  static const bgShopPanel = Color(0xFF5E3F33);
  static const bgShopScene = Color(0xFF7FA04B);
  static const bgBag = Color(0xFFF2A93B);
  static const bgCat = Color(0xFFEAD9B0);
  static const cardCat = Color(0xFFFFF8EE);
  static const bgSettings = Color(0xFFD5E1EE);
  static const bgExercises = Color(0xFF6D51BE);
  static const bgBreathing = Color(0xFF98DFB2);
  static const bgHomeGround = Color(0xFF7DB85C);
  static const bgHomeSky = Color(0xFFBFE3F2);
  static const bgHomeSkyEvening = Color(0xFFF4C79A);
  static const bgHomeSkyNight = Color(0xFF2F3E6B);

  // actions and states
  static const primaryGreen = Color(0xFF2B7F3A);
  static const primaryGreenEdge = Color(0xFF1E5C29);
  static const neutralButton = Color(0xFFE3E7EA);
  static const neutralButtonEdge = Color(0xFFB9C1C6);
  static const progressYellow = Color(0xFFFFC845);
  static const progressRail = Color(0xFFEFEFEF);
  static const doneBg = Color(0xFFE9E8C2);
  static const doneText = Color(0xFF256D2A);
  static const premiumBadge = Color(0xFF4A5FC9);
  static const lockYellow = Color(0xFFFFC845);
  static const energy = Color(0xFFF5A623);
  static const coin = Color(0xFFE8A317);

  // surfaces and text
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2E3A3F);
  static const textSecondary = Color(0xFF5F6C74);
  static const onDark = Color(0xFFFFFFFF);
  static const scrim = Color(0x66000000);
  static const shadow = Color(0x1F000000);

  // area colours (care areas)
  static const areaSleep = Color(0xFF7C8FD6);
  static const areaCalm = Color(0xFF6FC3B2);
  static const areaMovement = Color(0xFFF08D5B);
  static const areaNutrition = Color(0xFFE2655F);
  static const areaConnection = Color(0xFFE88BB0);
  static const areaFocus = Color(0xFF5BA3E0);
  static const areaSelfKindness = Color(0xFFB98BE0);
  static const areaHome = Color(0xFFC9A26B);

  static Color area(String key) => switch (key) {
        'sleep' => areaSleep,
        'calm' => areaCalm,
        'movement' => areaMovement,
        'nutrition' => areaNutrition,
        'connection' => areaConnection,
        'focus' => areaFocus,
        'self_kindness' => areaSelfKindness,
        _ => areaHome,
      };

  // placeholder cat art
  static const catBackdrops = [Color(0xFFFBE3C2), Color(0xFFCFE8E6), Color(0xFFD9D2EE), Color(0xFFE6EFC9)];
  static const catFlowerPetal = Color(0xFFE8739E);
  static const catFlowerCore = Color(0xFFFFD166);

  static const radiusCard = 28.0;
  static const radiusButton = 20.0;
  static const buttonEdge = 4.0;
}
