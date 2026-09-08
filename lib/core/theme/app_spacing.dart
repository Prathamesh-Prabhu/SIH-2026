/// Spacing scale — mirrors the Stitch "Serene Institutional Resilience"
/// design system (`DESIGN.md` → spacing). Strict 4px rhythm.
///
/// Use these instead of ad-hoc numbers so every screen breathes on the
/// same grid the design was drawn on.
class AppSpacing {
  AppSpacing._();

  /// 0.25rem — hairline gaps, chip internal padding.
  static const double xxs = 4;

  /// 0.5rem — icon/label gaps, tight stacks.
  static const double xs = 8;

  /// 0.75rem — inter-item spacing inside a card.
  static const double sm = 12;

  /// 1rem — default inter-card spacing, card padding.
  static const double md = 16;

  /// 1.25rem — mobile screen side margin, section padding.
  static const double lg = 20;

  /// 1.5rem — section spacing.
  static const double xl = 24;

  /// 2rem — spacing between distinct thematic groups.
  static const double xxl = 32;

  /// 2.5rem — hero / large vertical rhythm.
  static const double xxxl = 40;

  /// Mobile page gutter (1rem).
  static const double gutterMobile = 16;

  /// Desktop page gutter (1.5rem).
  static const double gutterDesktop = 24;

  /// Mobile safe-area side margin (1.25rem / 20px).
  static const double marginMobile = 20;

  /// Desktop content margin (3rem / 48px).
  static const double marginDesktop = 48;
}
