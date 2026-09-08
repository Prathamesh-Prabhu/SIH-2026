import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF02241F);
  static const Color primaryContainer = Color(0xFF1A3A34);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF83A49C);

  static const Color secondary = Color(0xFF37675B);
  static const Color secondaryContainer = Color(0xFFB7EADB);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF3B6B60);
  static const Color secondaryFixed = Color(0xFFBAEDDE);
  static const Color secondaryFixedDim = Color(0xFF9ED1C3);
  static const Color onSecondaryFixedVariant = Color(0xFF1D4F44);

  static const Color surface = Color(0xFFF8FAF9);
  static const Color surfaceDim = Color(0xFFD8DADA);
  static const Color surfaceBright = Color(0xFFF8FAF9);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F3);
  static const Color surfaceContainer = Color(0xFFECEEED);
  static const Color surfaceContainerHigh = Color(0xFFE6E9E8);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E2);

  static const Color onSurface = Color(0xFF191C1C);
  static const Color onSurfaceVariant = Color(0xFF414846);

  static const Color outline = Color(0xFF717976);
  static const Color outlineVariant = Color(0xFFC1C8C5);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.02,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.015,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.onSurface,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.02,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
