import 'package:flutter/widgets.dart';

/// Elevation system — low-contrast, pine-tinted ambient diffusion exactly
/// as specified in `DESIGN.md` → "Elevation & Depth". No aggressive black
/// drop shadows anywhere in the product.
class AppShadows {
  AppShadows._();

  /// Pine tint used for every shadow: rgb(26, 58, 52) — `#1A3A34`.
  static const Color _pine = Color(0xFF1A3A34);

  /// `shadow-sm` — resting cards, tiles, list rows.
  /// `0 1px 3px rgba(26,58,52,.04), 0 1px 2px rgba(26,58,52,.02)`
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A1A3A34), offset: Offset(0, 1), blurRadius: 3),
    BoxShadow(color: Color(0x051A3A34), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// `shadow-md` — fixed headers, persistent action footers, bottom sheets.
  /// `0 4px 12px rgba(26,58,52,.06), 0 2px 4px rgba(26,58,52,.03)`
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0F1A3A34), offset: Offset(0, 4), blurRadius: 12),
    BoxShadow(color: Color(0x081A3A34), offset: Offset(0, 2), blurRadius: 4),
  ];

  /// Upward cast for a bottom-anchored nav / action bar.
  static const List<BoxShadow> navTop = [
    BoxShadow(color: Color(0x0D1A3A34), offset: Offset(0, -2), blurRadius: 10),
  ];

  static Color get tint => _pine;
}
