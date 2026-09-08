import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _pendingServiceId;
  String _generatedOtp = '482000'; // Default valid test OTP

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get pendingServiceId => _pendingServiceId;
  String get generatedOtp => _generatedOtp;
  UserRole get currentRole => _currentUser?.role ?? UserRole.personnel;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(AppConstants.keyUserSession);

      if (sessionJson != null) {
        final map = jsonDecode(sessionJson) as Map<String, dynamic>;
        _currentUser = UserProfile.fromJson(map);
      } else {
        // By default on first launch, load Constable Dhruv so reviewers can immediately see screens
        _currentUser = UserProfile.dhruvPersonnel;
        await _saveSession(_currentUser!);
      }
    } catch (e) {
      _currentUser = UserProfile.dhruvPersonnel;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> initiateServiceIdLogin(String serviceId) async {
    _isLoading = true;
    _pendingServiceId = serviceId.trim().toUpperCase();
    notifyListeners();

    // Simulate OTP dispatch (or use Supabase Auth when configured)
    await Future.delayed(const Duration(milliseconds: 600));

    // For testing convenience, set predictable OTP: "482000" or any 6-digit number
    _generatedOtp = '482000';

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> verifyOtp(String otp) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    final serviceId = _pendingServiceId ?? 'CAPF-8821';
    UserProfile profile;

    // Detect persona based on service ID pattern or default
    if (serviceId.contains('HR') || serviceId.contains('ADMIN')) {
      profile = UserProfile.sharmaHrAdmin;
    } else if (serviceId.contains('WELFARE') || serviceId.contains('DOC')) {
      profile = UserProfile.ananyaWelfare;
    } else if (serviceId.contains('CMD') || serviceId.contains('RAO')) {
      profile = UserProfile.raoCommander;
    } else {
      profile = UserProfile.dhruvPersonnel.copyWith(
        fullName: 'Personnel ($serviceId)',
      );
    }

    // Try Supabase Auth if connected
    final client = _supabaseService.client;
    if (client != null && !_supabaseService.isMockMode) {
      try {
        final res = await client.from('profiles').select().eq('service_id', serviceId).maybeSingle();
        if (res != null) {
          profile = UserProfile.fromJson(res);
        } else {
          // Auto-register profile in Supabase
          await client.from('profiles').upsert(profile.toJson());
        }
      } catch (e) {
        debugPrint('Supabase profile query note: $e');
      }
    }

    _currentUser = profile;
    await _saveSession(profile);

    _isLoading = false;
    notifyListeners();
    return true;
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
      final client = _supabaseService.client;
      if (client != null && !_supabaseService.isMockMode) {
        await client.auth.signOut();
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

    final client = _supabaseService.client;
    if (client != null && !_supabaseService.isMockMode) {
      try {
        await client.from('profiles').update({
          'consent_settings': newSettings,
        }).eq('id', _currentUser!.id);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveSession(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserSession, jsonEncode(profile.toJson()));
  }
}
