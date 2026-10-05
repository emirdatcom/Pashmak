import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
        ColorScheme.fromSeed(seedColor: AppColors.orange, brightness: Brightness.light).copyWith(
          primary: AppColors.orangeDark,
          onPrimary: Colors.white,
          secondary: AppColors.turquoiseDark,
          onSecondary: Colors.white,
          surface: AppColors.cream,
          onSurface: AppColors.ink,
          error: AppColors.danger,
        ),
        AppColors.cream,
      );

  static ThemeData get dark => _build(
        ColorScheme.fromSeed(seedColor: AppColors.orange, brightness: Brightness.dark).copyWith(
          primary: AppColors.orange,
          onPrimary: AppColors.ink,
          secondary: AppColors.turquoise,
          surface: AppColors.nightSurface,
          onSurface: AppColors.nightInk,
        ),
        AppColors.nightBg,
      );

  static ThemeData _build(ColorScheme scheme, Color background) => ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        fontFamily: AppText.family,
        textTheme: AppText.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded, // >= 48dp targets
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
        appBarTheme: AppBarTheme(backgroundColor: background, elevation: 0, foregroundColor: scheme.onSurface),
      );
}
