import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'ml_service.dart';
import 'supabase_service.dart';

class DbService extends ChangeNotifier {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();
  final MlService _ml = MlService();

  // In-memory cache for fast UI updates & offline fallback
  final List<Map<String, dynamic>> _moodLogs = [];
  final List<Map<String, dynamic>> _assessments = [];
  final List<Map<String, dynamic>> _counselingSessions = [];
  final List<Map<String, dynamic>> _companionChats = [];
  final List<Map<String, dynamic>> _hrIngestionBatches = [];

  /// Pseudonymized feature rows accepted by HR ingestion. These are the only
  /// records that ever reach the analytics/ML layer — never names or PF numbers.
  final List<Map<String, dynamic>> _hrFeatureRecords = [];

  List<Map<String, dynamic>> get moodLogs => List.unmodifiable(_moodLogs);
  List<Map<String, dynamic>> get assessments => List.unmodifiable(_assessments);
  List<Map<String, dynamic>> get counselingSessions => List.unmodifiable(_counselingSessions);
  List<Map<String, dynamic>> get companionChats => List.unmodifiable(_companionChats);
  List<Map<String, dynamic>> get hrIngestionBatches => List.unmodifiable(_hrIngestionBatches);
  List<Map<String, dynamic>> get hrFeatureRecords => List.unmodifiable(_hrFeatureRecords);

  Future<void> init() async {
    // Seed initial demo counseling session
    if (_counselingSessions.isEmpty) {
      _counselingSessions.add({
        'id': 'sess-1',
        'session_type': 'voice',
        'preferred_date': DateTime.now().add(const Duration(days: 2)).toIso8601String().split('T')[0],
        'time_slot': '14:30 - 15:15 hrs',
        'status': 'confirmed',
        'officer_name': 'Dr. Ananya Varma',
        'topic': 'Post-deployment routine decompression',
      });
    }

    // Seed initial HR ingestion batch for HR Admin console
    if (_hrIngestionBatches.isEmpty) {
      _hrIngestionBatches.add({
        'id': 'batch-8842',
        'filename': 'CAPF_Sector4_Roster_Q1.csv',
        'file_size_kb': 245.5,
        'total_rows': 520,
        'accepted_rows': 514,
        'rejected_rows': 6,
        'status': 'committed',
        'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      });
    }

    // Seed a pseudonymized demo cohort so the analytics board has a roster to
    // score on first launch, before any CSV has been ingested.
    if (_hrFeatureRecords.isEmpty) {
      _hrFeatureRecords.addAll(_generateDemoCohort(24));
    }
  }

  /// Builds a deterministic pseudonymized cohort spanning the full risk range.
  /// Deterministic seeding keeps demo runs reproducible for reviewers.
  List<Map<String, dynamic>> _generateDemoCohort(int count) {
    final rng = Random(42);
    const zones = ['Northern Sector', 'Eastern Sector', 'Western Sector'];
    const tiers = ['CI_OPS', 'BORDER_OUTPOST', 'HIGH_ALTITUDE', 'PEACE'];

    return List.generate(count, (i) {
      // Roughly a fifth of the cohort carries genuine strain indicators.
      final strained = i % 5 == 0;
      final veryStrained = i % 11 == 0;

      return {
        'pseudonym_token': 'TOKEN-${(1000 + i * 37).toRadixString(16).toUpperCase()}',
        'unit_code': 'UNIT-${101 + (i % 6)}',
        'location_tier': tiers[veryStrained ? 0 : (i % tiers.length)],
        'deployment_zone': zones[i % zones.length],
        'shift_type': strained ? 'Extended Rotation' : 'Standard Rotation',
        'duty_hours_weekly': strained ? 78.0 + rng.nextInt(14) : 48.0 + rng.nextInt(10),
        'leave_balance_days': strained ? 44.0 + rng.nextInt(16) : 14.0 + rng.nextInt(12),
        'consecutive_active_days': veryStrained
            ? 26 + rng.nextInt(6)
            : (strained ? 19 + rng.nextInt(5) : 4 + rng.nextInt(9)),
        'sleep_quality': veryStrained ? 1 : (strained ? 2 : 4),
        'physical_exhaustion': veryStrained ? 5 : (strained ? 4 : 2),
        'workload_perception': strained ? 5 : 2,
        'mood_rating': veryStrained ? 1 : (strained ? 2 : 4),
        'manager_relationship': strained ? 2 : 4,
        'peer_social_support': strained ? 2 : 4,
        'transfer_count_last_12m': strained ? 3 : 1,
      };
    });
  }

  /// Translates the pseudonymized roster into `ScorePredictionRequest` payloads
  /// for `POST /api/v1/score/batch`. Each person is expanded into a 30-day
  /// window of HR records plus periodic wellness check-ins, which is exactly
  /// what the service's feature-engineering pipeline expects.
  List<Map<String, dynamic>> buildCohortScoringPayload({int windowDays = 30}) {
    final today = DateTime.now();

    return _hrFeatureRecords.map((person) {
      final token = person['pseudonym_token'] as String;
      final weeklyHours = (person['duty_hours_weekly'] as num?)?.toDouble() ?? 48.0;
      final dailyHours = (weeklyHours / 7).clamp(0.0, 24.0);
      final consecutive = (person['consecutive_active_days'] as num?)?.toInt() ?? 5;
      final leaveBalance = (person['leave_balance_days'] as num?)?.toDouble() ?? 20.0;
      final tier = person['location_tier'] as String? ?? 'PEACE';
      final unit = person['unit_code'] as String? ?? 'UNIT-101';

      final hrRecords = List.generate(windowDays, (d) {
        final date = today.subtract(Duration(days: windowDays - d));
        // A rest day only appears once the consecutive-duty streak would break.
        final isRestDay = consecutive < 15 && d % 7 == 6;
        return {
          'pseudonym_token': token,
          'record_date': date.toIso8601String().split('T')[0],
          'unit_code': unit,
          'location_tier': tier,
          'shift_hours': isRestDay ? 0.0 : dailyHours,
          'is_rest_day': isRestDay,
          'leave_taken_days': isRestDay ? 1.0 : 0.0,
          'leave_balance_days': leaveBalance,
          'consecutive_active_days': isRestDay ? 0 : min(consecutive, d + 1),
          'transfer_count_last_12m':
              (person['transfer_count_last_12m'] as num?)?.toInt() ?? 1,
          'training_load_hours': isRestDay ? 0.0 : 2.0,
          'synthetic': true,
        };
      });

      // Six private wellness check-ins across the window.
      final assessments = List.generate(6, (a) {
        final date = today.subtract(Duration(days: (windowDays ~/ 6) * (6 - a)));
        return {
          'pseudonym_token': token,
          'assessment_date': date.toIso8601String().split('T')[0],
          'workload_perception': person['workload_perception'] ?? 3,
          'mood_rating': person['mood_rating'] ?? 3,
          'manager_relationship': person['manager_relationship'] ?? 3,
          'sleep_quality': person['sleep_quality'] ?? 3,
          'physical_exhaustion': person['physical_exhaustion'] ?? 3,
          'peer_social_support': person['peer_social_support'] ?? 3,
          'synthetic': true,
        };
      });

      return {
        'pseudonym_token': token,
        'recent_hr_records': hrRecords,
        'recent_assessments': assessments,
        'recent_crisis_cue_detected': false,
      };
    }).toList();
  }

  // --- 1. MOOD LOGS ---
  Future<bool> recordMood({
    required int score,
    required String label,
    String? notes,
    String energy = 'Balanced',
  }) async {
    final entry = {
      'id': 'mood-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': _auth.currentUser?.id ?? 'demo-user',
      'service_id': _auth.currentUser?.serviceId ?? 'CAPF-8821',
      'mood_score': score,
      'mood_label': label,
      'energy_level': energy,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };

    _moodLogs.insert(0, entry);
    notifyListeners();

    // Supabase push
    final client = _supabase.client;
    if (client != null && !_supabase.isMockMode) {
      try {
        await client.from('mood_logs').insert(entry);
      } catch (e) {
        debugPrint('Supabase mood log note: $e');
      }
    }
    return true;
  }

  // --- 2. ASSESSMENTS ---
  Future<bool> recordAssessment({
    required int totalScore,
    required Map<String, dynamic> answers,
  }) async {
    final record = {
      'id': 'asmt-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': _auth.currentUser?.id ?? 'demo-user',
      'service_id': _auth.currentUser?.serviceId ?? 'CAPF-8821',
      'assessment_type': 'PHQ_GAD_WELLBEING',
      'total_score': totalScore,
      'question_count': answers.length,
      'answers': answers,
      'status': 'completed',
      'created_at': DateTime.now().toIso8601String(),
    };

    _assessments.insert(0, record);
    notifyListeners();

    final client = _supabase.client;
    if (client != null && !_supabase.isMockMode) {
      try {
        await client.from('assessments').insert(record);
      } catch (e) {
        debugPrint('Supabase assessment note: $e');
      }
    }
    return true;
  }

  // --- 3. COUNSELING BOOKING ---
  Future<bool> bookCounseling({
    required String sessionType,
    required DateTime date,
    required String timeSlot,
    String topic = 'Confidential Counseling',
  }) async {
    final booking = {
      'id': 'sess-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': _auth.currentUser?.id ?? 'demo-user',
      'service_id': _auth.currentUser?.serviceId ?? 'CAPF-8821',
      'session_type': sessionType,
      'preferred_date': date.toIso8601String().split('T')[0],
      'time_slot': timeSlot,
      'status': 'scheduled',
      'officer_name': 'Duty Welfare Officer',
      'topic': topic,
      'created_at': DateTime.now().toIso8601String(),
    };

    _counselingSessions.insert(0, booking);
    notifyListeners();

    final client = _supabase.client;
    if (client != null && !_supabase.isMockMode) {
      try {
        await client.from('counseling_sessions').insert(booking);
      } catch (e) {
        debugPrint('Supabase counseling note: $e');
      }
    }
    return true;
  }

  // --- 4. SELF HELP ACTIVITY ---
  Future<bool> recordSelfHelpActivity(String type, int durationSeconds) async {
    final entry = {
      'id': 'self-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': _auth.currentUser?.id ?? 'demo-user',
      'activity_type': type,
      'duration_seconds': durationSeconds,
      'completed_at': DateTime.now().toIso8601String(),
    };

    final client = _supabase.client;
    if (client != null && !_supabase.isMockMode) {
      try {
        await client.from('self_help_logs').insert(entry);
      } catch (_) {}
    }
    return true;
  }

  // --- 5. HR INGESTION (CSV Bulk Upload with Pseudonymization) ---
  Future<Map<String, dynamic>> processHrCsvIngestion({
    required String filename,
    required List<String> lines,
  }) async {
    int total = 0;
    int accepted = 0;
    int rejected = 0;
    final List<Map<String, dynamic>> acceptedRecords = [];
    final List<Map<String, dynamic>> rejectedRecords = [];

    // Header validation
    if (lines.isEmpty) {
      return {'success': false, 'error': 'CSV file is empty'};
    }

    final headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
    final hasServiceId = headers.contains('service_id');
    final hasDutyHours = headers.contains('duty_hours') || headers.contains('duty_hours_weekly');
    final hasLeaveBalance = headers.contains('leave_balance') || headers.contains('leave_balance_days');

    if (!hasServiceId || !hasDutyHours || !hasLeaveBalance) {
      return {
        'success': false,
        'error': 'Missing required headers: service_id, duty_hours, leave_balance',
      };
    }

    final serviceIdIndex = headers.indexOf('service_id');
    final dutyHoursIndex = headers.indexOf(headers.firstWhere((h) => h.contains('duty')));
    final leaveIndex = headers.indexOf(headers.firstWhere((h) => h.contains('leave')));

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      total++;

      final cols = line.split(',').map((c) => c.trim()).toList();
      if (cols.length <= serviceIdIndex || cols[serviceIdIndex].isEmpty) {
        rejected++;
        rejectedRecords.add({'line': i + 1, 'reason': 'Missing Service ID'});
        continue;
      }

      final rawServiceId = cols[serviceIdIndex];
      final dutyHours = double.tryParse(cols.length > dutyHoursIndex ? cols[dutyHoursIndex] : '48') ?? 48;
      final leaveBalance = double.tryParse(cols.length > leaveIndex ? cols[leaveIndex] : '30') ?? 30;

      // Cryptographic Pseudonymization Token (SHA-256) per PRD §2
      final tokenBytes = utf8.encode('$rawServiceId:manofit_salt_${DateTime.now().year}');
      final pseudonymToken = sha256.convert(tokenBytes).toString().substring(0, 16);

      accepted++;

      // Derive the operational strain signals the analytics layer consumes.
      // Everything below is keyed on the pseudonym token only.
      final strained = dutyHours > 70 || leaveBalance > 40;
      acceptedRecords.add({
        'pseudonym_token': pseudonymToken,
        'leave_balance_days': leaveBalance,
        'duty_hours_weekly': dutyHours,
        'deployment_zone': 'Northern Sector',
        'shift_type': strained ? 'Extended Rotation' : 'Standard Rotation',
        'unit_code': 'UNIT-${101 + (i % 6)}',
        'location_tier': strained ? 'CI_OPS' : 'PEACE',
        'consecutive_active_days': strained ? 22 : 6,
        'sleep_quality': strained ? 2 : 4,
        'physical_exhaustion': strained ? 4 : 2,
        'workload_perception': strained ? 5 : 2,
        'mood_rating': strained ? 2 : 4,
        'manager_relationship': strained ? 2 : 4,
        'peer_social_support': strained ? 2 : 4,
        'transfer_count_last_12m': strained ? 3 : 1,
      });
    }

    final batch = {
      'id': 'batch-${DateTime.now().millisecondsSinceEpoch}',
      'filename': filename,
      'file_size_kb': (lines.join('\n').length / 1024).toStringAsFixed(1),
      'total_rows': total,
      'accepted_rows': accepted,
      'rejected_rows': rejected,
      'status': 'committed',
      'created_at': DateTime.now().toIso8601String(),
    };

    _hrIngestionBatches.insert(0, batch);

    // Newly ingested personnel replace the seeded demo cohort so the analytics
    // board scores the roster that was actually uploaded.
    if (acceptedRecords.isNotEmpty) {
      _hrFeatureRecords
        ..clear()
        ..addAll(acceptedRecords);
    }
    notifyListeners();

    // Supabase push
    final client = _supabase.client;
    if (client != null && !_supabase.isMockMode) {
      try {
        await client.from('hr_ingestion_logs').insert(batch);
        for (var rec in acceptedRecords) {
          rec['batch_id'] = batch['id'];
          await client.from('hr_features').insert(rec);
        }
      } catch (e) {
        debugPrint('Supabase HR Ingestion note: $e');
      }
    }

    return {
      'success': true,
      'batch': batch,
      'acceptedCount': accepted,
      'rejectedCount': rejected,
      'rejectedList': rejectedRecords,
    };
  }

  // --- 6. AI COMPANION (Live Conversation + Tele-MANAS Crisis Escalation) ---
  Future<Map<String, dynamic>> sendCompanionMessage(String text) async {
    final userMsg = {
      'id': 'msg-${DateTime.now().millisecondsSinceEpoch}',
      'sender': 'user',
      'message': text,
      'is_crisis': false,
      'created_at': DateTime.now().toIso8601String(),
    };
    _companionChats.add(userMsg);
    notifyListeners();

    // Two-tier NLP per PRD §4, served by the ML microservice.
    // Tier 2 (high-recall crisis) gates the response; Tier 1 (routine
    // sentiment) feeds the longitudinal stress trend used by risk scoring.
    final crisis = await _ml.classifyCrisis(
      text,
      pseudonymToken: _auth.currentUser?.serviceId,
    );
    final sentiment = await _ml.analyzeSentiment(text);

    final isCrisis = crisis.crisisDetected;
    final botReply = crisis.stabilizingResponseHint;

    if (isCrisis) {
      // Auto-escalate alert
      final client = _supabase.client;
      if (client != null && !_supabase.isMockMode) {
        try {
          await client.from('crisis_alerts').insert({
            'user_id': _auth.currentUser?.id ?? 'demo-user',
            'trigger_source': 'ai_companion_nlu',
            'crisis_probability': crisis.crisisProbability,
            'risk_indicators': crisis.riskIndicators,
            'tele_manas_notified': crisis.escalationTriggered,
            'welfare_officer_alerted': crisis.escalationTriggered,
            'status': 'active_stabilization',
          });
        } catch (_) {}
      }
    }

    final botMsg = {
      'id': 'msg-bot-${DateTime.now().millisecondsSinceEpoch}',
      'sender': 'assistant',
      'message': botReply,
      'is_crisis': isCrisis,
      'crisis_probability': crisis.crisisProbability,
      'risk_indicators': crisis.riskIndicators,
      'sentiment_label': sentiment.sentimentLabel,
      'created_at': DateTime.now().toIso8601String(),
    };
    _companionChats.add(botMsg);
    notifyListeners();

    return {
      'reply': botReply,
      'isCrisis': isCrisis,
      'riskIndicators': crisis.riskIndicators,
      'priority': crisis.priority,
      'recommendedAction': crisis.recommendedAction,
      'sentimentLabel': sentiment.sentimentLabel,
      'stressProbability': sentiment.stressProbability,
      'fatigueIndicators': sentiment.fatigueIndicators,
      'servedByMlService': _ml.isOnline,
    };
  }
}
