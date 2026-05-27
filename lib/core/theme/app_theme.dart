import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Global dark [ThemeData] for AmbulaTec.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const border8 = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: AppColors.borderOverlay),
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      cardColor: AppColors.bgCard,

      // ── Color scheme ──────────────────────────────────────────────────────
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.accentGold,
        onPrimary: AppColors.bgPrimary,
        secondary: AppColors.accentGreen,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.bgSurface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textPrimary,
      ),

      // ── Text theme ────────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        bodyMedium: AppTextStyles.body,
        labelSmall: AppTextStyles.caption,
      ),

      // ── Input decoration ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        border: border8,
        enabledBorder: border8,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.accentGold),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),

      // ── Elevated button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGold,
          foregroundColor: AppColors.bgPrimary,
          shape: const StadiumBorder(),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),

      // ── Outlined button ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.accentGreen),
          foregroundColor: AppColors.textPrimary,
          shape: const StadiumBorder(),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgCard,
        side: const BorderSide(color: AppColors.borderOverlay),
        labelStyle: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
        ),
        selectedColor: AppColors.accentGreen,
      ),
    );
  }
}
