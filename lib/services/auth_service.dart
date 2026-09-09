import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

/// Result of a sign-in attempt. [ok] true means [profile] is populated.
class AuthResult {
  final bool ok;
  final String? error;
  final UserProfile? profile;
  const AuthResult.success(this.profile)
      : ok = true,
        error = null;
  const AuthResult.failure(this.error)
      : ok = false,
        profile = null;
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  UserProfile? _currentUser;
  bool _isLoading = false;
  bool _onboardingComplete = false;

  // Legacy mock-OTP fields kept so the (now off-flow) OTP screen still compiles.
  String? _pendingServiceId;
  String _generatedOtp = '482000';

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get onboardingComplete => _onboardingComplete;
  String? get pendingServiceId => _pendingServiceId;
  String get generatedOtp => _generatedOtp;
  UserRole get currentRole => _currentUser?.role ?? UserRole.personnel;

  SupabaseClient? get _client => _supabaseService.client;
  bool get _live => !_supabaseService.isMockMode && _client != null;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingComplete =
          prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;

      if (_live) {
        // Source of truth is the Supabase session; restore the profile row.
        final session = _client!.auth.currentSession;
        if (session != null) {
          _currentUser = await _fetchProfile(session.user.id);
          if (_currentUser != null) {
            await _saveSession(_currentUser!);
          }
        } else {
          _currentUser = null;
        }
      } else {
        // Mock/demo fallback: restore a previously cached demo session, if any.
        final sessionJson = prefs.getString(AppConstants.keyUserSession);
        if (sessionJson != null) {
          _currentUser = UserProfile.fromJson(
              jsonDecode(sessionJson) as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('AuthService.init note: $e');
      _currentUser = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Signs in with a Service / PF number + password. In live mode the Service ID
  /// is mapped onto `<slug>@<domain>` and verified against Supabase Auth; the
  /// matching `profiles` row is then loaded. In mock mode any non-empty password
  /// resolves a demo persona by Service ID pattern.
  Future<AuthResult> signInWithServiceId(
      String serviceId, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final id = serviceId.trim().toUpperCase();

      if (!_live) {
        if (password.trim().isEmpty) {
          return const AuthResult.failure('Enter your access password.');
        }
        final persona = _personaForServiceId(id);
        _currentUser = persona;
        await _saveSession(persona);
        return AuthResult.success(persona);
      }

      final email = AppConstants.emailForServiceId(
        id,
        domain: _supabaseService.authEmailDomain,
      );

      final res = await _client!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final authUser = res.user;
      if (authUser == null) {
        return const AuthResult.failure('Sign-in failed. Please try again.');
      }

      final profile = await _fetchProfile(authUser.id);
      if (profile == null) {
        await _client!.auth.signOut();
        _currentUser = null;
        return const AuthResult.failure(
            'No personnel profile is linked to this Service ID. Contact your HR cell.');
      }

      _currentUser = profile;
      await _saveSession(profile);
      return AuthResult.success(profile);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } catch (e) {
      debugPrint('signInWithServiceId error: $e');
      return const AuthResult.failure(
          'Unable to reach the authentication service. Check your connection.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserProfile?> _fetchProfile(String userId) async {
    try {
      final row = await _client!
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return UserProfile.fromJson(row);
    } catch (e) {
      debugPrint('_fetchProfile error: $e');
      return null;
    }
  }

  String _friendlyAuthError(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Incorrect Service ID or password.';
    }
    if (m.contains('email not confirmed')) {
      return 'This account is not activated yet. Contact your HR cell.';
    }
    if (m.contains('querying schema') || m.contains('database error')) {
      return 'The account backend is misconfigured. Re-run supabase_seed.sql '
          '(Step 1b repairs the auth rows).';
    }
    return raw;
  }

  UserProfile _personaForServiceId(String serviceId) {
    if (serviceId.contains('OVERSIGHT') || serviceId.contains('BOARD')) {
      return UserProfile.oversightAudit;
    } else if (serviceId.contains('HR') || serviceId.contains('ADMIN')) {
      return UserProfile.sharmaHrAdmin;
    } else if (serviceId.contains('WELFARE') || serviceId.contains('DOC')) {
      return UserProfile.ananyaWelfare;
    } else if (serviceId.contains('CMD') || serviceId.contains('RAO')) {
      return UserProfile.raoCommander;
    }
    return UserProfile.dhruvPersonnel.copyWith(fullName: 'Personnel ($serviceId)');
  }

  Future<void> markOnboardingComplete() async {
    _onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingComplete, true);
    notifyListeners();
  }

  void switchPersona(UserProfile persona) async {
    _currentUser = persona;
    await _saveSession(persona);
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_live) {
        await _client!.auth.signOut();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUserSession);
    } catch (_) {}

    _currentUser = null;
    _pendingServiceId = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateConsent(Map<String, dynamic> newSettings) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(consentSettings: newSettings);
    await _saveSession(_currentUser!);

    if (_live) {
      try {
        await _client!.from('profiles').update({
          'consent_settings': newSettings,
        }).eq('id', _currentUser!.id);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveSession(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.keyUserSession, jsonEncode(profile.toJson()));
  }

  // ── Legacy mock-OTP API (kept for the off-flow OTP screen) ────────────────
  Future<bool> initiateServiceIdLogin(String serviceId) async {
    _pendingServiceId = serviceId.trim().toUpperCase();
    _generatedOtp = '482000';
    notifyListeners();
    return true;
  }

  Future<bool> verifyOtp(String otp) async {
    final serviceId = _pendingServiceId ?? 'CAPF-8821';
    _currentUser = _personaForServiceId(serviceId);
    await _saveSession(_currentUser!);
    notifyListeners();
    return true;
  }
}
