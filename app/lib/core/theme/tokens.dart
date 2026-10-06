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
  /// Round, wide, heavy face for titles and big numbers; Vazirmatn covers anything the subset lacks.
  static const headline = 'BalooBhaijaan2';
  static const headlineFallback = [family];
  static const textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.4, fontFamily: headline, fontFamilyFallback: headlineFallback),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.4, fontFamily: headline, fontFamilyFallback: headlineFallback),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6),
    bodyMedium: TextStyle(fontSize: 14, height: 1.6),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );
}

/// Design-system tokens of the redesign (prompt 22/23, docs/design-system.md). Backgrounds are sampled from the
/// reference screenshots (app/tool/visual_compare/sample_colors.py); AA is reached by choosing the text colour
/// (white / textDeep / textPrimary), never by moving a background (checked in test/theme_test.dart). No colour literals
/// outside this file.
class DS {
  const DS._();
  // tab backgrounds
  static const bgQuests = Color(0xFFAF7E56);
  static const bgShopPanel = Color(0xFF633F2F);
  static const shopTile = Color(0xFF9B614B);
  static const bgShopScene = Color(0xFF87A045);
  static const bgBag = Color(0xFFF4A838);
  static const bgBagScene = Color(0xFF3F3D6E);
  static const bgBagLocked = Color(0xFFEC910D);
  static const bgCat = Color(0xFFE9D3A1);
  static const cardCat = Color(0xFFFFF6ED);
  static const bgSettings = Color(0xFFD3E1EE);
  static const bgExercises = Color(0xFF6F52BC);
  static const bgBreathing = Color(0xFF96DFB2);
  static const bgHomeGround = Color(0xFF7BB65C);
  /// The pinned top bar of home once the page is scrolled (a deeper shade of the ground).
  static const bgHomeBar = Color(0xFF4E8F3E);
  static const bgHomeSky = Color(0xFFBFE3F2);
  static const bgHomeSkyEvening = Color(0xFFF4C79A);
  static const bgHomeSkyNight = Color(0xFF2F3E6B);
  // courtyard scene layers (depth like the reference forest: far hills, mid wall + tree, pond and pots, ground)
  static const sceneHillFar = Color(0xFFA9D18B);
  static const sceneHillNear = Color(0xFF8FC46F);
  static const sceneWall = Color(0xFFD9A77A);
  static const sceneWallShade = Color(0xFFC48E63);
  static const sceneTrunk = Color(0xFF9B6A4A);
  static const sceneLeaf = Color(0xFF3F9A55);
  static const sceneLeafDark = Color(0xFF2E7D4A);
  static const scenePond = Color(0xFF7CC4E8);
  static const scenePondRim = Color(0xFFE9D3A1);
  static const scenePot = Color(0xFFD9774A);
  static const sceneSun = Color(0xFFFFD36B);

  // actions and states
  static const primaryGreen = Color(0xFF55B752);
  static const primaryGreenEdge = Color(0xFF3E9440);
  static const neutralButton = Color(0xFFE3E7EA);
  static const neutralButtonEdge = Color(0xFFB9C1C6);
  static const progressYellow = Color(0xFFFFC845);
  static const progressRail = Color(0xFFEFEFEF);
  static const doneBg = Color(0xFFE8E9C1);
  static const doneText = Color(0xFF256D2A);
  static const premiumBadge = Color(0xFF566FD6);
  static const lockYellow = Color(0xFFFFC845);
  static const energy = Color(0xFFF5A623);
  static const coin = Color(0xFFE8A317);

  // surfaces and text
  static const card = Color(0xFFFFFFFF);
  /// Bottom sheets: an off-white panel holding white cards with a soft 2dp outline instead of a shadow.
  static const sheetBg = Color(0xFFF7F7F7);
  static const outline = Color(0xFFE6E6E6);
  static const chipBg = Color(0xFFEFEFEF);
  /// Secondary labels inside the goal card (lighter than textSecondary, as in the reference).
  static const textMuted = Color(0xFF8E9AA3);
  /// Translucent white over the green page: suggestion rows, the selected category, the close button.
  static const glass = Color(0x38FFFFFF);
  /// Dark translucent card over the home scene, and the backdrop of the focused goal.
  static const glassDark = Color(0x66123A1C);
  static const scrimDeep = Color(0xD9061A12);
  static const radiusSheet = 32.0;

  // exercise kinds (the blob behind an exercise sticker)
  static const exReflection = Color(0xFF6FBFD0);
  static const exBreathing = Color(0xFF7B6FE0);
  static const exGrounding = Color(0xFFE9525C);
  static const exMovement = Color(0xFFF0409A);
  static const exTimer = Color(0xFFFFCB5C);

  static Color exerciseKind(String kind) => switch (kind) {
        'reflection' => exReflection,
        'grounding' => exGrounding,
        'movement' => exMovement,
        'timer' => exTimer,
        _ => exBreathing,
      };

  static const radiusOutlineCard = 24.0;
  static const textPrimary = Color(0xFF2E3A3F);
  static const textSecondary = Color(0xFF47535A);
  static const onDark = Color(0xFFFFFFFF);
  /// Darkest text: used on mid-tone backgrounds (green, brown, grass) where white fails AA; also the label colour of green buttons.
  static const textDeep = Color(0xFF1A2226);
  static const onPrimary = textDeep;
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
  /// Home cards are low (about 66dp), so they take a smaller corner than the tall cards.
  static const radiusHomeCard = 20.0;
  static const radiusButton = 20.0;
  static const buttonEdge = 4.0;
}
