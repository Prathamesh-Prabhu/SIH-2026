import 'package:flutter/widgets.dart';

/// Corner-radius scale — mirrors the Stitch design system's rendered
/// Tailwind config (`rounded-*`) and the shape guidance in `DESIGN.md`.
///
/// - cards / content blocks .......... [lg]  (rounded-2xl, 16)
/// - primary buttons / inputs ........ [md]  (rounded-xl, 12)  or [pill]
/// - badges / tags / counters ........ [pill]
/// - hero / large scenic cards ....... [xl]  (rounded-3xl, 24)
class AppRadii {
  AppRadii._();

  static const double xs = 4; // rounded-sm
  static const double sm = 8; // rounded-lg
  static const double md = 12; // rounded-xl
  static const double lg = 16; // rounded-2xl
  static const double xl = 24; // rounded-3xl
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}
