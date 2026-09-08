import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// The full named type scale from the Stitch design system
/// (`DESIGN.md` → typography). Every value — size, weight, line-height,
/// tracking — is transcribed exactly. `em` tracking is converted to the
/// logical-pixel `letterSpacing` Flutter expects (`size * em`).
///
/// Family is Plus Jakarta Sans throughout, resolved via google_fonts.
class AppText {
  AppText._();

  static TextStyle _jakarta({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    Color? color,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.onSurface,
    );
  }

  // ── Display ──────────────────────────────────────────────────────────
  /// 34 / 700 · lh 42 · -0.02em — top-level brand / splash headline.
  static TextStyle get displayLg => _jakarta(
        size: 34,
        weight: FontWeight.w700,
        height: 42 / 34,
        letterSpacing: -0.68,
        color: AppColors.primary,
      );

  // ── Headlines ────────────────────────────────────────────────────────
  /// 26 / 600 · lh 34 · -0.015em — desktop console page titles.
  static TextStyle get headlineLg => _jakarta(
        size: 26,
        weight: FontWeight.w600,
        height: 34 / 26,
        letterSpacing: -0.39,
        color: AppColors.primary,
      );

  /// 22 / 600 · lh 30 · -0.01em — mobile screen titles / greetings.
  static TextStyle get headlineLgMobile => _jakarta(
        size: 22,
        weight: FontWeight.w600,
        height: 30 / 22,
        letterSpacing: -0.22,
        color: AppColors.primary,
      );

  /// 20 / 600 · lh 28 — card cluster headings.
  static TextStyle get headlineMd => _jakarta(
        size: 20,
        weight: FontWeight.w600,
        height: 28 / 20,
        color: AppColors.primary,
      );

  /// 16 / 600 · lh 22 — section headings, app-bar titles, card titles.
  static TextStyle get headlineSm => _jakarta(
        size: 16,
        weight: FontWeight.w600,
        height: 22 / 16,
        color: AppColors.primary,
      );

  // ── Body ─────────────────────────────────────────────────────────────
  /// 16 / 400 · lh 24 — input values, prominent reading copy.
  static TextStyle get bodyLg => _jakarta(
        size: 16,
        weight: FontWeight.w400,
        height: 24 / 16,
        color: AppColors.onSurface,
      );

  /// 14 / 400 · lh 20 — default body copy.
  static TextStyle get bodyMd => _jakarta(
        size: 14,
        weight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.onSurfaceVariant,
      );

  /// 12 / 400 · lh 18 — supporting copy, captions.
  static TextStyle get bodySm => _jakarta(
        size: 12,
        weight: FontWeight.w400,
        height: 18 / 12,
        color: AppColors.onSurfaceVariant,
      );

  // ── Labels / microcopy ───────────────────────────────────────────────
  /// 15 / 600 · lh 20 · 0.01em — primary button labels.
  static TextStyle get labelLg => _jakarta(
        size: 15,
        weight: FontWeight.w600,
        height: 20 / 15,
        letterSpacing: 0.15,
        color: AppColors.primary,
      );

  /// 12 / 600 · lh 16 · 0.02em — chip labels, field labels, nav labels.
  static TextStyle get labelMd => _jakarta(
        size: 12,
        weight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.24,
        color: AppColors.onSurfaceVariant,
      );

  /// 11 / 500 · lh 14 — smallest state markers / counters.
  static TextStyle get labelSm => _jakarta(
        size: 11,
        weight: FontWeight.w500,
        height: 14 / 11,
        color: AppColors.onSurfaceVariant,
      );

  /// Maps the scale onto Material's [TextTheme] slots so default-styled
  /// widgets pick up the right values.
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLg,
        displayMedium: headlineLg,
        displaySmall: headlineMd,
        headlineLarge: headlineLg,
        headlineMedium: headlineLgMobile,
        headlineSmall: headlineSm,
        titleLarge: headlineSm,
        titleMedium: labelLg,
        titleSmall: labelMd,
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        bodySmall: bodySm,
        labelLarge: labelLg,
        labelMedium: labelMd,
        labelSmall: labelSm,
      );
}
