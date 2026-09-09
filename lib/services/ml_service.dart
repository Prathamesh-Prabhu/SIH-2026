import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ml_models.dart';

/// Thrown by [MlService.scoreBatch] in strict mode when the live model service
/// cannot be reached, so callers can show an explicit "start the ML service"
/// state instead of silently degrading to heuristics.
class MlServiceUnavailable implements Exception {
  MlServiceUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client for the ManoFit Analytics & ML microservice (FastAPI, port 8000).
///
/// The service is decoupled from the app by design, so every call degrades
/// gracefully: when the microservice is unreachable the client falls back to
/// the on-device heuristic so the prototype stays demonstrable offline. The
/// [isOnline] flag tells the UI which of the two produced a given result.
class MlService extends ChangeNotifier {
  static final MlService _instance = MlService._internal();
  factory MlService() => _instance;
  MlService._internal();

  /// Matches `ML_SERVICE_INTERNAL_TOKEN` in `ml_service/app/config.py`.
  static const String defaultToken = 'manofit_ml_internal_sec_token_dev_2026';
  static const String keyBaseUrl = 'manofit_ml_base_url';
  static const String keyToken = 'manofit_ml_token';

  static const Duration _shortTimeout = Duration(seconds: 4);
  static const Duration _longTimeout = Duration(seconds: 30);

  String? _baseUrl;
  String _token = defaultToken;
  bool _isOnline = false;
  bool _isChecking = false;
  String _statusMessage = 'Not connected';
  ModelCard? _modelCard;

  String get baseUrl => _baseUrl ?? _candidateHosts.first;
  String get token => _token;
  bool get isOnline => _isOnline;
  bool get isChecking => _isChecking;
  String get statusMessage => _statusMessage;
  ModelCard? get modelCard => _modelCard;

  /// Hosts to probe, in order. `10.0.2.2` is the loopback alias inside the
  /// Android emulator; a USB-attached handset reaches the laptop through
  /// `adb reverse tcp:8000 tcp:8000`, which makes `localhost` resolve.
  List<String> get _candidateHosts {
    final env = dotenv.maybeGet('ML_URL')?.trim();
    final envClean = (env != null && env.isNotEmpty) ? env.replaceAll(RegExp(r'/+$'), '') : null;
    return [
      if (envClean != null) envClean,
      if (kIsWeb) 'http://localhost:8000',
      if (defaultTargetPlatform == TargetPlatform.android) ...['http://10.0.2.2:8000', 'http://localhost:8000'],
      'http://localhost:8000',
      'http://127.0.0.1:8000',
    ];
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<void> init({String? remoteEndpoint}) async {
    final env = dotenv.maybeGet('ML_URL')?.trim();
    final envClean = (env != null && env.isNotEmpty) ? env.replaceAll(RegExp(r'/+$'), '') : null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(keyBaseUrl)?.trim();
      _token = prefs.getString(keyToken) ?? defaultToken;

      // Priority:
      // 1. remoteEndpoint from Supabase (if available)
      // 2. saved override from SharedPreferences (if explicitly set)
      // 3. ML_URL from .env
      if (remoteEndpoint != null && remoteEndpoint.trim().isNotEmpty) {
        _baseUrl = remoteEndpoint.trim().replaceAll(RegExp(r'/+$'), '');
      } else if (savedUrl != null && savedUrl.isNotEmpty) {
        _baseUrl = savedUrl.replaceAll(RegExp(r'/+$'), '');
      } else if (envClean != null) {
        _baseUrl = envClean;
      }
    } catch (e) {
      dev.log('ManoFit ML: could not read saved settings: $e');
    }
    await checkHealth();
  }

  /// Adopts a remote endpoint discovered from Supabase at runtime.
  Future<void> syncFromSupabase(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isNotEmpty && clean != _baseUrl) {
      dev.log('ManoFit ML: adopting Supabase endpoint: $clean');
      _baseUrl = clean;
      await checkHealth();
    }
  }


  /// Probes candidate hosts until one answers `/health`, then caches it.
  Future<bool> checkHealth() async {
    _isChecking = true;
    notifyListeners();

    final candidates = <String>[
      if (_baseUrl != null && _baseUrl!.isNotEmpty) _baseUrl!,
      ..._candidateHosts,
    ];

    for (final host in candidates) {
      try {
        final res = await http
            .get(Uri.parse('$host/health'))
            .timeout(_shortTimeout);
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final models = body['models'] as Map<String, dynamic>? ?? {};
          final ready = models.values.every((v) => v == 'READY');
          _baseUrl = host;
          _isOnline = true;
          _statusMessage = ready
              ? 'ML service online • all models READY'
              : 'ML service online • models pending training';
          _isChecking = false;
          notifyListeners();
          unawaited(fetchModelCard());
          return true;
        }
      } catch (_) {
        // Try the next candidate.
      }
    }

    _isOnline = false;
    _statusMessage =
        'ML service offline — using on-device fallback heuristics';
    _isChecking = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateEndpoint(String url, String tokenValue) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _token = tokenValue.trim().isEmpty ? defaultToken : tokenValue.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyBaseUrl, _baseUrl!);
      await prefs.setString(keyToken, _token);
    } catch (e) {
      dev.log('ManoFit ML: could not persist settings: $e');
    }
    return checkHealth();
  }

  // -------------------------------------------------------------------
  // Governance
  // -------------------------------------------------------------------

  Future<ModelCard?> fetchModelCard() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/v1/governance/model-card'),
              headers: _headers)
          .timeout(_shortTimeout);
      if (res.statusCode == 200) {
        _modelCard =
            ModelCard.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        notifyListeners();
        return _modelCard;
      }
    } catch (e) {
      dev.log('ManoFit ML: model card unavailable: $e');
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Tier 2 — high-recall crisis classification
  // -------------------------------------------------------------------

  Future<CrisisResult> classifyCrisis(String text,
      {String? pseudonymToken}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/nlp/crisis'),
            headers: _headers,
            body: jsonEncode({
              'text': text,
              if (pseudonymToken != null) 'pseudonym_token': pseudonymToken,
            }),
          )
          .timeout(_shortTimeout);
      if (res.statusCode == 200) {
        _markOnline();
        return CrisisResult.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      dev.log('ManoFit ML: crisis endpoint unreachable, falling back: $e');
      _markOffline();
    }
    return _fallbackCrisis(text);
  }

  // -------------------------------------------------------------------
  // Tier 1 — routine sentiment & fatigue
  // -------------------------------------------------------------------

  Future<SentimentResult> analyzeSentiment(String text) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/nlp/sentiment'),
            headers: _headers,
            body: jsonEncode({'text': text}),
          )
          .timeout(_shortTimeout);
      if (res.statusCode == 200) {
        _markOnline();
        return SentimentResult.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      dev.log('ManoFit ML: sentiment endpoint unreachable, falling back: $e');
      _markOffline();
    }
    return _fallbackSentiment(text);
  }

  // -------------------------------------------------------------------
  // Behavioural risk scoring
  // -------------------------------------------------------------------

  /// Batch-scores a pseudonymized cohort for the HR / Welfare analytics board.
  ///
  /// When [strict] is true the live microservice is the only accepted source:
  /// any failure throws [MlServiceUnavailable] instead of substituting the
  /// on-device heuristic, so the HR board never renders numbers the real model
  /// did not produce.
  Future<BatchRiskResult> scoreBatch(
      List<Map<String, dynamic>> items,
      {bool strict = false}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/score/batch'),
            headers: _headers,
            body: jsonEncode({'items': items}),
          )
          .timeout(_longTimeout);
      if (res.statusCode == 200) {
        _markOnline();
        return BatchRiskResult.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
      dev.log('ManoFit ML: batch scoring HTTP ${res.statusCode}: ${res.body}');
      if (strict) {
        throw MlServiceUnavailable(
            'Model service returned HTTP ${res.statusCode}.');
      }
    } on MlServiceUnavailable {
      rethrow;
    } catch (e) {
      dev.log('ManoFit ML: batch endpoint unreachable: $e');
      _markOffline();
      if (strict) {
        throw MlServiceUnavailable(
            'Model service is unreachable at $baseUrl.');
      }
    }
    return _fallbackBatch(items);
  }

  Future<RiskAssessment?> scoreOne(Map<String, dynamic> item) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/score/predict'),
            headers: _headers,
            body: jsonEncode(item),
          )
          .timeout(_longTimeout);
      if (res.statusCode == 200) {
        _markOnline();
        return RiskAssessment.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      dev.log('ManoFit ML: predict endpoint unreachable: $e');
      _markOffline();
    }
    final batch = _fallbackBatch([item]);
    return batch.results.isEmpty ? null : batch.results.first;
  }

  void _markOnline() {
    if (!_isOnline) {
      _isOnline = true;
      _statusMessage = 'ML service online • all models READY';
      notifyListeners();
    }
  }

  void _markOffline() {
    if (_isOnline) {
      _isOnline = false;
      _statusMessage =
          'ML service offline — using on-device fallback heuristics';
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------
  // Offline fallbacks — keep the prototype demonstrable without the service
  // -------------------------------------------------------------------

  static const List<String> _crisisCues = [
    'suicide',
    'kill myself',
    'end my life',
    'end it all',
    'better off without me',
    'no reason to live',
    'hopeless',
    'cannot take this anymore',
    "can't take this anymore",
    'give up',
    'hurt myself',
    "can't go on",
    'burden',
  ];

  CrisisResult _fallbackCrisis(String text) {
    final lower = text.toLowerCase();
    final hits = _crisisCues.where(lower.contains).toList();
    final detected = hits.isNotEmpty;
    return CrisisResult(
      crisisDetected: detected,
      crisisProbability: detected ? 0.85 : 0.05,
      riskIndicators: hits
          .map((c) => 'Acute distress cue detected in conversation: "$c"')
          .toList(),
      escalationTriggered: detected,
      helpline: '14416',
      priority: detected ? 'IMMEDIATE_ESCALATION' : 'ROUTINE',
      recommendedAction: detected
          ? 'Notify Tele-MANAS (14416) in parallel; alert unit duty Welfare '
              'Officer for immediate supportive human check-in.'
          : 'Continue routine supportive conversation.',
      stabilizingResponseHint: detected
          ? 'I hear how heavy this feels right now, and I am right here with '
              'you. You do not have to carry this alone. Tele-MANAS (14416) is '
              'available this second with confidential, compassionate support.'
          : _routineReply(lower),
    );
  }

  SentimentResult _fallbackSentiment(String text) {
    final lower = text.toLowerCase();
    const fatigueCues = [
      'tired',
      'exhausted',
      'drained',
      'no sleep',
      'sleepless',
      'fatigue',
      'burnt out',
    ];
    const stressCues = ['stress', 'pressure', 'anxious', 'overwhelmed', 'shift'];

    final fatigue = fatigueCues.where(lower.contains).toList();
    final stressed = stressCues.any(lower.contains) || fatigue.isNotEmpty;

    return SentimentResult(
      textSnippet: text.length > 60 ? '${text.substring(0, 60)}...' : text,
      sentimentLabel: fatigue.isNotEmpty
          ? 'Fatigued'
          : (stressed ? 'Stressed' : 'Positive or Neutral'),
      valenceScore: stressed ? -0.45 : 0.30,
      stressProbability: stressed ? 0.72 : 0.18,
      fatigueIndicators: fatigue,
    );
  }

  String _routineReply(String lower) {
    if (lower.contains('stress') ||
        lower.contains('tired') ||
        lower.contains('shift')) {
      return 'Operational fatigue is very real, especially after long '
          'rotations. Take a slow, steady breath. Would you like to do a quick '
          '2-minute box breathing cycle together, or simply talk through your day?';
    }
    if (lower.contains('sleep') || lower.contains('night')) {
      return 'Rest is the foundation of endurance. Disrupted sleep can '
          'increase cognitive strain. Let us try easing the rhythm with calming '
          'breathing in the Mindfulness section.';
    }
    return 'Thank you for sharing that with me. I am here to listen anytime in '
        'complete confidence. What is on your mind today?';
  }

  /// Deterministic heuristic mirroring the service's banding rules, so the
  /// analytics board still renders a coherent cohort when offline.
  BatchRiskResult _fallbackBatch(List<Map<String, dynamic>> items) {
    final results = <RiskAssessment>[];
    var elevated = 0, moderate = 0, low = 0;

    for (final item in items) {
      final token = item['pseudonym_token'] as String? ?? 'TOKEN-UNKNOWN';
      final records =
          (item['recent_hr_records'] as List<dynamic>? ?? []).cast<Map>();
      final assessments =
          (item['recent_assessments'] as List<dynamic>? ?? []).cast<Map>();

      double maxConsecutive = 0;
      double avgShift = 0;
      double leaveBalance = 30;
      for (final r in records) {
        maxConsecutive = max(
          maxConsecutive,
          ((r['consecutive_active_days'] as num?) ?? 0).toDouble(),
        );
        avgShift += ((r['shift_hours'] as num?) ?? 0).toDouble();
        leaveBalance = ((r['leave_balance_days'] as num?) ?? 30).toDouble();
      }
      if (records.isNotEmpty) avgShift /= records.length;

      double sleep = 3, exhaustion = 3;
      for (final a in assessments) {
        sleep += ((a['sleep_quality'] as num?) ?? 3).toDouble();
        exhaustion += ((a['physical_exhaustion'] as num?) ?? 3).toDouble();
      }
      if (assessments.isNotEmpty) {
        sleep = (sleep - 3) / assessments.length;
        exhaustion = (exhaustion - 3) / assessments.length;
      }

      var score = 0.0;
      if (maxConsecutive > 18) score += 0.35;
      if (avgShift > 12) score += 0.20;
      if (leaveBalance > 40) score += 0.10;
      if (sleep < 2.4) score += 0.25;
      if (exhaustion > 3.8) score += 0.20;
      if (item['recent_crisis_cue_detected'] == true) score += 0.5;

      final band = score >= 0.65
          ? RiskBand.elevated
          : (score >= 0.35 ? RiskBand.moderate : RiskBand.low);
      if (band == RiskBand.elevated) {
        elevated++;
      } else if (band == RiskBand.moderate) {
        moderate++;
      } else {
        low++;
      }

      final factors = <FactorAttribution>[
        if (maxConsecutive > 18)
          FactorAttribution(
            factorName: 'consecutive_duty_days_max_30d',
            displayTitle: 'Extended continuous duty',
            importanceWeight: 0.35,
            direction: 'risk_increasing',
            contextDetail:
                '${maxConsecutive.toStringAsFixed(0)} continuous duty days without rest',
          ),
        if (sleep < 2.4)
          FactorAttribution(
            factorName: 'avg_sleep_score_30d',
            displayTitle: 'Degraded sleep quality',
            importanceWeight: 0.25,
            direction: 'risk_increasing',
            contextDetail:
                'Mean sleep score ${sleep.toStringAsFixed(1)} / 5 over 30 days',
          ),
        if (exhaustion > 3.8)
          FactorAttribution(
            factorName: 'avg_exhaustion_score_30d',
            displayTitle: 'Sustained physical exhaustion',
            importanceWeight: 0.20,
            direction: 'risk_increasing',
            contextDetail:
                'Mean exhaustion score ${exhaustion.toStringAsFixed(1)} / 5',
          ),
        if (leaveBalance > 40)
          FactorAttribution(
            factorName: 'leave_utilization_ratio_30d',
            displayTitle: 'Accrued leave left unused',
            importanceWeight: 0.10,
            direction: 'risk_increasing',
            contextDetail:
                '${leaveBalance.toStringAsFixed(0)} days accrued, low utilization',
          ),
        if (score < 0.35)
          const FactorAttribution(
            factorName: 'peer_social_support',
            displayTitle: 'Strong peer support signal',
            importanceWeight: 0.18,
            direction: 'protective',
            contextDetail: 'Consistent rest cycle and unit cohesion indicators',
          ),
      ];

      results.add(RiskAssessment(
        pseudonymToken: token,
        riskBand: band,
        confidence: 0.62,
        topFactors: factors,
        recommendedSupportPathway: switch (band) {
          RiskBand.elevated =>
            'Priority confidential welfare check-in within 48 hours; offer '
                'Tele-MANAS (14416) and counselling session booking.',
          RiskBand.moderate =>
            'Schedule a supportive conversation and encourage guided self-help '
                'and rest-cycle correction.',
          RiskBand.low =>
            'No action required. Continue routine wellness check-ins.',
        },
        modelVersion: 'fallback-heuristic',
        evaluatedAt: DateTime.now().toIso8601String(),
        synthetic: true,
      ));
    }

    return BatchRiskResult(
      results: results,
      totalEvaluated: results.length,
      elevatedCount: elevated,
      moderateCount: moderate,
      lowCount: low,
    );
  }
}
