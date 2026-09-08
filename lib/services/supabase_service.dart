import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class SupabaseService extends ChangeNotifier {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _client;
  bool _isInitialized = false;
  bool _isMockMode = true;
  String _currentUrl = AppConstants.defaultSupabaseUrl;
  String _currentAnonKey = AppConstants.defaultSupabaseKey;

  SupabaseClient? get client => _client;
  bool get isInitialized => _isInitialized;
  bool get isMockMode => _isMockMode;
  String get currentUrl => _currentUrl;
  String get currentAnonKey => _currentAnonKey;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUrl = prefs.getString(AppConstants.keySupabaseUrl) ?? AppConstants.defaultSupabaseUrl;
      _currentAnonKey = prefs.getString(AppConstants.keySupabaseAnonKey) ?? AppConstants.defaultSupabaseKey;

      final looksReal = _currentUrl.startsWith('https://') &&
          _currentAnonKey.length > 25 &&
          !_currentAnonKey.contains('dummy') &&
          !_currentUrl.contains('your-project');

      if (looksReal) {
        await Supabase.initialize(
          url: _currentUrl,
          anonKey: _currentAnonKey,
          debug: kDebugMode,
        );
        _client = Supabase.instance.client;
        _isMockMode = false;
        dev.log('ManoFit Supabase connected to: $_currentUrl');
      } else {
        _isMockMode = true;
        dev.log('ManoFit operating in resilient Mock/Demo mode (configure live Supabase in connection settings).');
      }
    } catch (e) {
      dev.log('Supabase initialization error, falling back to mock mode: $e');
      _isMockMode = true;
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> updateCredentials(String url, String anonKey) async {
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keySupabaseUrl, cleanUrl);
      await prefs.setString(AppConstants.keySupabaseAnonKey, cleanKey);

      _currentUrl = cleanUrl;
      _currentAnonKey = cleanKey;

      if (cleanUrl.startsWith('https://') && cleanKey.length > 25) {
        await Supabase.initialize(
          url: cleanUrl,
          anonKey: cleanKey,
        );
        _client = Supabase.instance.client;
        _isMockMode = false;
      } else {
        _isMockMode = true;
      }
      notifyListeners();
      return true;
    } catch (e) {
      dev.log('Failed to reinitialize Supabase: $e');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> testConnection(String url, String key) async {
    try {
      final testClient = SupabaseClient(url.trim(), key.trim());
      await testClient.from('profiles').select().limit(1);
      return {'success': true, 'message': 'Successfully connected to Supabase!'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }
}
