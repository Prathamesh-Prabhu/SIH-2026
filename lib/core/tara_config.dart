import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the Tara voice UI (the `tara_service` Node relay) is served.
///
/// Resolution: in-app override (persisted) → `TARA_URL` from `.env` →
/// `http://localhost:3000`.
///
/// `getUserMedia` needs a **secure context** — HTTPS or `localhost`/`127.0.0.1`.
/// For a deployed phone on its own internet this means the relay must be
/// reachable over HTTPS (e.g. a Cloudflare / ngrok tunnel); set that URL in the
/// app's Tara connection dialog, no rebuild required. A USB handset can instead
/// keep `localhost` with `adb reverse tcp:3000 tcp:3000`.
class TaraConfig {
  const TaraConfig._();

  static const String prefsKey = 'manofit_tara_url';
  static String? _override;
  static String? _remoteUrl;

  /// Loads the persisted override once at startup.
  static Future<void> load({String? remoteEndpoint}) async {
    if (remoteEndpoint != null && remoteEndpoint.trim().isNotEmpty) {
      _remoteUrl = _normalise(remoteEndpoint);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefsKey)?.trim();
      if (saved != null && saved.isNotEmpty) _override = _normalise(saved);
    } catch (_) {
      // Non-fatal — fall back to .env / default.
    }
  }

  /// Adopts a dynamic endpoint discovered from Supabase.
  static void syncFromSupabase(String url) {
    final clean = _normalise(url);
    if (clean.isNotEmpty) {
      _remoteUrl = clean;
    }
  }

  /// Persists a new relay URL and applies it immediately.
  static Future<void> setUrl(String url) async {
    _override = _normalise(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_override == null || _override!.isEmpty) {
        await prefs.remove(prefsKey);
      } else {
        await prefs.setString(prefsKey, _override!);
      }
    } catch (_) {}
  }

  static String get url {
    if (_remoteUrl != null && _remoteUrl!.isNotEmpty) return _remoteUrl!;
    if (_override != null && _override!.isNotEmpty) return _override!;
    final raw = dotenv.maybeGet('TARA_URL')?.trim();
    return (raw == null || raw.isEmpty) ? 'http://localhost:3000' : _normalise(raw);
  }

  static bool get hasOverride => _override != null && _override!.isNotEmpty;
  static bool get isUsingSupabase => _remoteUrl != null && _remoteUrl!.isNotEmpty;
  static String? get remoteUrl => _remoteUrl;


  static String _normalise(String u) => u.trim().replaceAll(RegExp(r'/+$'), '');

  /// `true` when the resolved URL is a browser "secure context", i.e. the
  /// WebView will be allowed to open the mic.
  static bool get isSecureContext {
    final u = Uri.tryParse(url);
    if (u == null) return false;
    if (u.scheme == 'https') return true;
    return u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1';
  }
}
