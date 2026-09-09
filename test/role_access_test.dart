import 'package:flutter_test/flutter_test.dart';
import 'package:manofit/core/auth/role_access.dart';
import 'package:manofit/core/constants/app_constants.dart';

/// Locks the RBAC matrix. These are privacy guarantees from the PRD, not
/// styling choices — a regression here silently exposes welfare data to a role
/// that must never see it, and would not show up as a visible bug.
void main() {
  group('role home routing', () {
    test('each role lands on its own console', () {
      expect(UserRole.personnel.homeRoute, '/home');
      expect(UserRole.hrAdmin.homeRoute, '/hr-overview');
      expect(UserRole.welfareOfficer.homeRoute, '/hr-analytics');
      expect(UserRole.commander.homeRoute, '/resilience');
      expect(UserRole.oversightBoard.homeRoute, '/oversight');
    });

    test('every role can reach its own home', () {
      for (final role in UserRole.values) {
        expect(role.canAccess(role.homeRoute), isTrue,
            reason: '${role.name} must be able to open its own console');
      }
    });
  });

  group('analytics output is scoped to the Welfare Officer', () {
    test('only the Welfare Officer opens individual risk output', () {
      // PRD §8.1 — individual-level flags, post human review.
      expect(UserRole.welfareOfficer.canAccess('/hr-analytics'), isTrue);

      // PRD §6.4 — HR Admin supplies data and never sees analytics output.
      expect(UserRole.hrAdmin.canAccess('/hr-analytics'), isFalse);

      // PRD §3.2 — commanders see aggregates only, never individuals.
      expect(UserRole.commander.canAccess('/hr-analytics'), isFalse);

      // PRD §3.2 — personnel never see the organizational risk model at all.
      expect(UserRole.personnel.canAccess('/hr-analytics'), isFalse);
    });

    test('commander is confined to the aggregate console', () {
      expect(UserRole.commander.canAccess('/resilience'), isTrue);
      expect(UserRole.commander.canAccess('/hr-overview'), isFalse);
      expect(UserRole.commander.canAccess('/home'), isFalse);
    });
  });

  group('HR Admin is scoped to data supply only', () {
    test('reaches ingestion routes', () {
      expect(UserRole.hrAdmin.canAccess('/hr-overview'), isTrue);
      expect(UserRole.hrAdmin.canAccess('/hr-ingestion'), isTrue);
      expect(UserRole.hrAdmin.canAccess('/hr-mobile-review'), isTrue);
    });

    test('cannot wander into personnel wellness screens', () {
      for (final route in ['/home', '/mood', '/wellbeing', '/companion', '/book']) {
        expect(UserRole.hrAdmin.canAccess(route), isFalse,
            reason: 'HR Admin must not reach $route');
      }
    });
  });

  group('personnel', () {
    test('reach their own screens and no console', () {
      for (final route in ['/home', '/mood', '/wellbeing', '/self-help', '/companion', '/book']) {
        expect(UserRole.personnel.canAccess(route), isTrue);
      }
      for (final route in ['/hr-overview', '/hr-ingestion', '/resilience', '/oversight']) {
        expect(UserRole.personnel.canAccess(route), isFalse);
      }
    });
  });

  group('shared routes', () {
    test('profile and onboarding are reachable by every role', () {
      for (final role in UserRole.values) {
        expect(role.canAccess('/profile'), isTrue);
        expect(role.canAccess('/onboarding'), isTrue);
      }
    });
  });

  group('role parsing', () {
    test('oversight_board round-trips instead of silently becoming personnel', () {
      // The Postgres `user_role` enum has five values; a missing Dart case
      // would downgrade an Oversight Board account to `personnel`.
      expect(UserRole.fromString('oversight_board'), UserRole.oversightBoard);
      expect(UserRole.oversightBoard.toDbValue(), 'oversight_board');

      for (final role in UserRole.values) {
        expect(UserRole.fromString(role.toDbValue()), role,
            reason: '${role.name} must survive a DB round-trip');
      }
    });

    test('an unknown role falls back to the least-privileged one', () {
      expect(UserRole.fromString('root'), UserRole.personnel);
      expect(UserRole.fromString(null), UserRole.personnel);
    });
  });
}
