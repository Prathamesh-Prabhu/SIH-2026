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

  // Default Supabase placeholders
  static const String defaultSupabaseUrl = 'https://manofit-dev.supabase.co';
  static const String defaultSupabaseKey = 'dummy-key';
}

enum UserRole {
  personnel,
  hrAdmin,
  welfareOfficer,
  commander;

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
    }
  }
}
