class AppConstants {
  static const String appName = 'ManoFit';
  static const String appTagline = 'Stronger People, Safer Tomorrows';
  static const String teleManasNumber = '14416';
  static const String teleManasLabel = 'Tele-MANAS • 14416 (24/7 Priority Support)';

  // Storage Keys
  static const String keySupabaseUrl = 'manofit_supabase_url';
  static const String keySupabaseAnonKey = 'manofit_supabase_anon_key';
  static const String keyUserSession = 'manofit_user_session';
  static const String keyConsentSettings = 'manofit_consent_settings';
  static const String keyOnboardingComplete = 'manofit_onboarding_complete';

  // Default Supabase placeholders — real values come from `.env` (loaded in
  // main.dart) or the in-app connection settings dialog.
  static const String defaultSupabaseUrl = '';
  static const String defaultSupabaseKey = '';

  /// Service IDs are mapped onto synthetic emails of the form
  /// `<service-id-lowercased>@<domain>` for Supabase email/password auth.
  static const String authEmailDomainFallback = 'manofit.app';

  /// Builds the login email for a Service / PF number.
  static String emailForServiceId(String serviceId, {String? domain}) {
    final slug = serviceId
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '$slug@${domain ?? authEmailDomainFallback}';
  }
}

enum UserRole {
  personnel,
  hrAdmin,
  welfareOfficer,
  commander,
  oversightBoard;

  String get displayName {
    switch (this) {
      case UserRole.personnel:
        return 'Personnel';
      case UserRole.hrAdmin:
        return 'HR Administrator';
      case UserRole.welfareOfficer:
        return 'Welfare Officer';
      case UserRole.commander:
        return 'Unit Commander';
      case UserRole.oversightBoard:
        return 'Oversight Board';
    }
  }

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'hr_admin':
      case 'hradmin':
        return UserRole.hrAdmin;
      case 'welfare_officer':
      case 'welfareofficer':
        return UserRole.welfareOfficer;
      case 'commander':
        return UserRole.commander;
      case 'oversight_board':
      case 'oversightboard':
        return UserRole.oversightBoard;
      case 'personnel':
      default:
        return UserRole.personnel;
    }
  }

  String toDbValue() {
    switch (this) {
      case UserRole.personnel:
        return 'personnel';
      case UserRole.hrAdmin:
        return 'hr_admin';
      case UserRole.welfareOfficer:
        return 'welfare_officer';
      case UserRole.commander:
        return 'commander';
      case UserRole.oversightBoard:
        return 'oversight_board';
    }
  }
}
