import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  String _authEmailDomain = AppConstants.authEmailDomainFallback;

  SupabaseClient? get client => _client;
  bool get isInitialized => _isInitialized;
  bool get isMockMode => _isMockMode;
  String get currentUrl => _currentUrl;
  String get currentAnonKey => _currentAnonKey;

  /// Domain that Service IDs are mapped onto for email/password auth.
  String get authEmailDomain => _authEmailDomain;

  /// Normalises a project URL — strips a trailing `/rest/v1/` (a common
  /// copy-paste from the Supabase API settings page) and any trailing slash.
  static String _normaliseUrl(String raw) {
    var url = raw.trim();
    url = url.replaceFirst(RegExp(r'/rest/v1/?$'), '');
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Precedence: in-app override (SharedPreferences) → .env → constant.
      final envUrl = dotenv.maybeGet('SUPABASE_URL') ?? '';
      final envKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
      _authEmailDomain = (dotenv.maybeGet('AUTH_EMAIL_DOMAIN') ??
              AppConstants.authEmailDomainFallback)
          .trim();

      _currentUrl = _normaliseUrl(
        prefs.getString(AppConstants.keySupabaseUrl) ??
            (envUrl.isNotEmpty ? envUrl : AppConstants.defaultSupabaseUrl),
      );
      _currentAnonKey = (prefs.getString(AppConstants.keySupabaseAnonKey) ??
              (envKey.isNotEmpty ? envKey : AppConstants.defaultSupabaseKey))
          .trim();

      final looksReal = _currentUrl.startsWith('https://') &&
          _currentUrl.contains('.supabase.co') &&
          _currentAnonKey.split('.').length == 3 &&
          _currentAnonKey.length > 60;

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
        dev.log('ManoFit operating in resilient Mock/Demo mode '
            '(no valid Supabase credentials in .env or connection settings).');
      }
    } catch (e) {
      dev.log('Supabase initialization error, falling back to mock mode: $e');
      _isMockMode = true;
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> updateCredentials(String url, String anonKey) async {
    final cleanUrl = _normaliseUrl(url);
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
