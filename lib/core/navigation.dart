import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import 'auth/role_access.dart';

/// Navigation helpers that keep the Android back stack meaningful.
///
/// The rule across ManoFit:
/// * `push` for moving *into* a screen (Home → Check-in, HR Overview →
///   Ingestion) so system back and the AppBar arrow both return where you
///   came from.
/// * `go` only for *replacing* a flow — auth transitions and sign-out — where
///   returning to the previous screen would be wrong.
///
/// Using `go` for forward navigation is what made every screen a dead end: it
/// clears the stack, leaving nothing to pop, so back fell through to the
/// launcher and the app appeared to minimise.
extension AppNavigation on BuildContext {
  /// Steps back one screen.
  ///
  /// When there is nothing to pop — the screen was opened by a deep link, or
  /// reached through a router redirect — falls back to [fallback], defaulting
  /// to the signed-in role's own console so an HR Admin is never dropped onto
  /// the personnel home (see [RoleAccess.homeRouteFor]).
  void backOr([String? fallback]) {
    if (canPop()) {
      pop();
    } else {
      go(fallback ?? AuthService().currentRole.homeRoute);
    }
  }
}
