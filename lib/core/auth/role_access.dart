import '../constants/app_constants.dart';

/// Structural RBAC for the client router (PRD §6.6, §8 — the console a role
/// lands on and the routes it may reach are a property of the role, not of
/// which button happens to be on screen).
///
/// This mirrors, and never replaces, Postgres Row-Level Security: the server
/// remains the enforcement point. What this adds is that a signed-in HR Admin
/// deep-linking to `/hr-analytics` is bounced instead of rendering a board the
/// PRD says they must never see.
class RoleAccess {
  RoleAccess._();

  /// Reachable by every authenticated role.
  static const Set<String> commonRoutes = {'/profile', '/onboarding'};

  /// Route → roles permitted to open it.
  ///
  /// Deliberate exclusions, straight from the PRD:
  /// * HR Admin is scoped to data supply only — no `/hr-analytics` (§6.4).
  /// * Commander sees aggregate `/resilience` only, never individual cases (§8.2).
  /// * Only the Welfare Officer opens individual-level risk output (§8.1).
  static const Map<String, Set<UserRole>> routeRoles = {
    // Personnel app — the organizational roles have no business here, and the
    // personal screens never render risk-model output anyway (§7).
    '/home': {UserRole.personnel},
    '/mood': {UserRole.personnel},
    '/wellbeing': {UserRole.personnel},
    '/self-help': {UserRole.personnel},
    '/companion': {UserRole.personnel},
    '/book': {UserRole.personnel},

    // HR Admin — ingestion status only.
    '/hr-overview': {UserRole.hrAdmin},
    '/hr-ingestion': {UserRole.hrAdmin},
    '/hr-mobile-review': {UserRole.hrAdmin},

    // Welfare Officer — individual risk bands + factor attributions.
    '/hr-analytics': {UserRole.welfareOfficer},

    // Commander — differentially-private unit aggregates.
    '/resilience': {UserRole.commander},

    // Oversight Board — model card, metrics, governance.
    '/oversight': {UserRole.oversightBoard},
  };

  /// The console a role is sent to after sign-in.
  static String homeRouteFor(UserRole role) {
    switch (role) {
      case UserRole.personnel:
        return '/home';
      case UserRole.hrAdmin:
        return '/hr-overview';
      case UserRole.welfareOfficer:
        return '/hr-analytics';
      case UserRole.commander:
        return '/resilience';
      case UserRole.oversightBoard:
        return '/oversight';
    }
  }

  /// Whether [role] may open [route]. Unknown routes are permitted so that
  /// adding a screen does not silently become unreachable — add it to
  /// [routeRoles] when it is role-scoped.
  static bool canAccess(UserRole role, String route) {
    if (commonRoutes.contains(route)) return true;
    final allowed = routeRoles[route];
    if (allowed == null) return true;
    return allowed.contains(role);
  }
}

extension UserRoleRouting on UserRole {
  String get homeRoute => RoleAccess.homeRouteFor(this);
  bool canAccess(String route) => RoleAccess.canAccess(this, route);

  /// True for the four organizational consoles (Flutter Web targets per
  /// architecture §2), false for the personnel mobile app.
  bool get isConsoleRole => this != UserRole.personnel;
}
