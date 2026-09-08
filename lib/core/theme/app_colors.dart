import 'package:flutter/material.dart';

/// Complete colour palette from the Stitch "Serene Institutional
/// Resilience" design system (`DESIGN.md` frontmatter). Every token is
/// transcribed verbatim — do not invent shades; compose from these.
///
/// Naming follows the Material 3 role names used in the design tokens so
/// the mapping to [ColorScheme] is 1:1.
class AppColors {
  AppColors._();

  // ── Surfaces ─────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFF8FAF9);
  static const Color surfaceDim = Color(0xFFD8DADA);
  static const Color surfaceBright = Color(0xFFF8FAF9);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F3);
  static const Color surfaceContainer = Color(0xFFECEEED);
  static const Color surfaceContainerHigh = Color(0xFFE6E9E8);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E2);
  static const Color surfaceVariant = Color(0xFFE1E3E2);
  static const Color surfaceTint = Color(0xFF45645E);

  static const Color background = Color(0xFFF8FAF9);
  static const Color onBackground = Color(0xFF191C1C);
  static const Color onSurface = Color(0xFF191C1C);
  static const Color onSurfaceVariant = Color(0xFF414846);
  static const Color inverseSurface = Color(0xFF2E3131);
  static const Color inverseOnSurface = Color(0xFFEFF1F0);

  static const Color outline = Color(0xFF717976);
  static const Color outlineVariant = Color(0xFFC1C8C5);

  // ── Primary — Deep Pine ──────────────────────────────────────────────
  /// Dominant typography / brand text.
  static const Color primary = Color(0xFF02241F);

  /// Primary *interactive* surface (buttons, selected states). This is the
  /// `#1A3A34` the design prose calls "Deep Pine / Forest Slate".
  static const Color primaryContainer = Color(0xFF1A3A34);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF83A49C);
  static const Color inversePrimary = Color(0xFFABCEC5);

  static const Color primaryFixed = Color(0xFFC7EAE1);
  static const Color primaryFixedDim = Color(0xFFABCEC5);
  static const Color onPrimaryFixed = Color(0xFF00201B);
  static const Color onPrimaryFixedVariant = Color(0xFF2D4D46);

  // ── Secondary — Muted Eucalyptus ─────────────────────────────────────
  static const Color secondary = Color(0xFF37675B);
  static const Color secondaryContainer = Color(0xFFB7EADB);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF3B6B60);

  static const Color secondaryFixed = Color(0xFFBAEDDE);
  static const Color secondaryFixedDim = Color(0xFF9ED1C3);
  static const Color onSecondaryFixed = Color(0xFF00201A);
  static const Color onSecondaryFixedVariant = Color(0xFF1D4F44);

  // ── Tertiary — Soft Sage ─────────────────────────────────────────────
  static const Color tertiary = Color(0xFF18221F);
  static const Color tertiaryContainer = Color(0xFF2D3734);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF95A09C);

  static const Color tertiaryFixed = Color(0xFFDAE5E0);
  static const Color tertiaryFixedDim = Color(0xFFBEC9C4);
  static const Color onTertiaryFixed = Color(0xFF141D1B);
  static const Color onTertiaryFixedVariant = Color(0xFF3F4945);

  // ── Error ────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ── Status / mood markers (desaturated — never alarming) ─────────────
  /// High distress.
  static const Color statusDistress = Color(0xFFE88C7D);

  /// Caution.
  static const Color statusCaution = Color(0xFFF2BA74);

  /// Positive.
  static const Color statusPositive = Color(0xFF7FB59B);

  // ── Semantic aliases used across screens ─────────────────────────────
  /// Hairline separators / subtle structure (`#E3E8E5`).
  static const Color hairline = Color(0xFFE3E8E5);

  /// Tinted trust / privacy banner fill (`#F1F5F3`).
  static const Color trustPanel = Color(0xFFF1F5F3);

  /// Selected tonal shift for elevated tiles (`#EFF5F2`).
  static const Color selectedTint = Color(0xFFEFF5F2);
}
