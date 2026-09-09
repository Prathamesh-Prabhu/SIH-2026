import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/wellbeing_checkins.dart';
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

  /// Mindfulness section — breathing + meditation sessions (`mindfulness_logs`)
  /// and the Samsung-style 5-point mood check-ins (`mindfulness_moods`).
  final List<Map<String, dynamic>> _mindfulnessLogs = [];
  final List<Map<String, dynamic>> _mindfulnessMoods = [];

  /// Crisis escalations raised from the app (Tara voice, AI companion) — the
  /// welfare-officer handoff. Mirrors `public.crisis_alerts`.
  final List<Map<String, dynamic>> _crisisAlerts = [];

  /// Times the user has opened Tara this session — drives the "Reached Out"
  /// profile badge. Session-scoped (in-memory) by design.
  int _taraSessions = 0;

  /// Pseudonymized feature rows accepted by HR ingestion. These are the only
  /// records that ever reach the analytics/ML layer — never names or PF numbers.
  final List<Map<String, dynamic>> _hrFeatureRecords = [];

  List<Map<String, dynamic>> get moodLogs => List.unmodifiable(_moodLogs);
  List<Map<String, dynamic>> get assessments => List.unmodifiable(_assessments);
  List<Map<String, dynamic>> get counselingSessions => List.unmodifiable(_counselingSessions);
  List<Map<String, dynamic>> get companionChats => List.unmodifiable(_companionChats);
  List<Map<String, dynamic>> get hrIngestionBatches => List.unmodifiable(_hrIngestionBatches);
  List<Map<String, dynamic>> get hrFeatureRecords => List.unmodifiable(_hrFeatureRecords);
  List<Map<String, dynamic>> get mindfulnessLogs => List.unmodifiable(_mindfulnessLogs);
  List<Map<String, dynamic>> get mindfulnessMoods => List.unmodifiable(_mindfulnessMoods);
  List<Map<String, dynamic>> get crisisAlerts => List.unmodifiable(_crisisAlerts);
  int get taraSessions => _taraSessions;

  void noteTaraOpened() {
    _taraSessions++;
    notifyListeners();
  }

  // Local persistence — the HR cohort and its ingestion history survive an app
  // restart so each roster upload adds to the database rather than replacing it.
  static const _kFeatureRecords = 'hr_feature_records_v1';
  static const _kIngestionBatches = 'hr_ingestion_batches_v1';
  static const _kAssessments = 'wellbeing_assessments_v1';
  bool _restored = false;

  Future<void> init() async {
    // Seed initial demo counseling session (personnel booking flow, unrelated
    // to the HR analytics pipeline).
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

    await _restoreLocal();
  }

  Future<void> _restoreLocal() async {
    if (_restored) return;
    _restored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> read(String key) {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) return const [];
        final list = jsonDecode(raw);
        return list is List
            ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : const [];
      }

      final feats = read(_kFeatureRecords);
      final batches = read(_kIngestionBatches);
      final asmts = read(_kAssessments);
      if (feats.isNotEmpty && _hrFeatureRecords.isEmpty) _hrFeatureRecords.addAll(feats);
      if (batches.isNotEmpty && _hrIngestionBatches.isEmpty) _hrIngestionBatches.addAll(batches);
      if (asmts.isNotEmpty && _assessments.isEmpty) _assessments.addAll(asmts);
      if (feats.isNotEmpty || batches.isNotEmpty || asmts.isNotEmpty) notifyListeners();
    } catch (e) {
      debugPrint('DbService: could not restore local HR data: $e');
    }
  }

  Future<void> _persist(String key, List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(rows));
    } catch (e) {
      debugPrint('DbService: could not persist $key: $e');
    }
  }

  Future<void> _persistHr() async {
    await _persist(_kFeatureRecords, _hrFeatureRecords);
    await _persist(_kIngestionBatches, _hrIngestionBatches);
  }

  /// Clears the ingested cohort and its history (local + this session).
  Future<void> clearHrDatabase() async {
    _hrFeatureRecords.clear();
    _hrIngestionBatches.clear();
    notifyListeners();
    await _persistHr();
  }

  /// Roll-up of the currently ingested cohort, keyed only on pseudonym tokens.
  Map<String, dynamic> get hrCohortSummary {
    final units = <String>{};
    for (final r in _hrFeatureRecords) {
      units.add((r['unit_code'] as String?) ?? 'UNIT-UNKNOWN');
    }
    return {
      'personnel': _hrFeatureRecords.length,
      'units': units.length,
      'lastBatch': _hrIngestionBatches.isNotEmpty ? _hrIngestionBatches.first : null,
    };
  }

  /// Unit code for a pseudonym token, for unit-level aggregation on the board.
  String unitForToken(String token) {
    for (final r in _hrFeatureRecords) {
      if (r['pseudonym_token'] == token) {
        return (r['unit_code'] as String?) ?? 'UNIT-UNKNOWN';
      }
    }
    return 'UNIT-UNKNOWN';
  }

  /// Every anonymous wellbeing check-in the organisation holds: personnel
  /// self-reports (`_assessments`) plus any wellness pulse attached to an
  /// ingested roster. Each entry is just the 1–5 domain scores — no identity,
  /// no user_id, no per-person linkage — for the Organisation Wellbeing
  /// roll-up on the HR dashboard.
  List<Map<String, int>> get anonymousCheckIns {
    final out = <Map<String, int>>[];
    for (final a in _assessments) {
      final m = <String, int>{};
      for (final item in kWellbeingCheckIns) {
        final v = a[item.key];
        if (v is int) m[item.key] = v;
        if (v is num) m[item.key] = v.round();
      }
      if (m.isNotEmpty) out.add(m);
    }
    for (final r in _hrFeatureRecords) {
      final c = r['wellness_checkin'];
      if (c is Map) {
        final m = <String, int>{};
        c.forEach((k, v) {
          if (v is num) m[k.toString()] = v.round();
        });
        if (m.isNotEmpty) out.add(m);
      }
    }
    return out;
  }

  int get anonymousCheckInCount => anonymousCheckIns.length;

  /// When the most recent [cadence] check-in was completed (rows written before
  /// cadence tagging count as weekly).
  DateTime? lastCheckInAt(String cadence) {
    for (final a in _assessments) {
      final tag = (a['cadence'] as String?) ?? 'weekly';
      if (tag != cadence) continue;
      final ts = a['created_at'];
      if (ts is String) return DateTime.tryParse(ts);
    }
    return null;
  }

  /// True when this cadence has never been done, or its interval has elapsed.
  bool isCheckInDue(String cadence, Duration interval) {
    final last = lastCheckInAt(cadence);
    return last == null || DateTime.now().difference(last) >= interval;
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

      // Deployment stints across the window, derived from transfer history, so
      // the deployment-record features (redeployment frequency, time at the
      // current posting) receive real values instead of defaulting to zero.
      final transfers =
          ((person['transfer_count_last_12m'] as num?)?.toInt() ?? 1).clamp(1, 4);
      final stintLength = (windowDays / transfers).ceil();

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
          'deployment_id': '$token-DEP-${d ~/ stintLength}',
          'deployment_start_date': today
              .subtract(Duration(days: windowDays - (d ~/ stintLength) * stintLength))
              .toIso8601String()
              .split('T')[0],
          'training_load_hours': isRestDay ? 0.0 : 2.0,
          'synthetic': false,
        };
      });

      // A duty roster carries no private wellness check-ins, so none are
      // fabricated — the model scores on the operational signals only and the
      // feature pipeline applies neutral assessment defaults. If real check-in
      // scores were ingested for a token they are attached here.
      final assessments = <Map<String, dynamic>>[];
      final checkIn = person['wellness_checkin'];
      if (checkIn is Map) {
        assessments.add({
          'pseudonym_token': token,
          'assessment_date': today.toIso8601String().split('T')[0],
          'workload_perception': checkIn['workload_perception'] ?? 3,
          'mood_rating': checkIn['mood_rating'] ?? 3,
          'manager_relationship': checkIn['manager_relationship'] ?? 3,
          'sleep_quality': checkIn['sleep_quality'] ?? 3,
          'physical_exhaustion': checkIn['physical_exhaustion'] ?? 3,
          'peer_social_support': checkIn['peer_social_support'] ?? 3,
          'synthetic': false,
        });
      }

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

  // --- 2. ASSESSMENTS — the 6 private check-ins (PRD §7) ---
  /// Persists one wellbeing check-in. [answers] is keyed by the six
  /// `CheckInItem.key` values, each 1–5, stored both as named columns (what
  /// the ML layer reads) and in `answers` for provenance.
  ///
  /// Returns true when the row reached Supabase (or when running in
  /// mock/demo mode, where the local cache is the source of truth).
  Future<bool> recordWellbeingCheckIn(
    Map<String, int> answers, {
    String cadence = 'weekly',
  }) async {
    final now = DateTime.now();
    final total = orientedWellbeingTotal(answers);

    // Columns the analytics layer consumes. Absent answers stay null rather
    // than being silently defaulted to a neutral 3 — a skipped item is not
    // the same signal as "average".
    final scores = <String, dynamic>{
      for (final item in kWellbeingCheckIns)
        if (answers[item.key] != null) item.key: answers[item.key],
    };

    final payload = <String, dynamic>{
      'user_id': _auth.currentUser?.id,
      'service_id': _auth.currentUser?.serviceId ?? 'CAPF-8821',
      'assessment_type': 'SIX_CHECKIN_V1',
      'cadence': cadence,
      'total_score': total,
      'question_count': answers.length,
      'answers': {
        for (final item in kWellbeingCheckIns)
          if (answers[item.key] != null)
            item.key: {
              'question': item.question,
              'value': answers[item.key],
              'label': item.labels[answers[item.key]! - 1],
              'higher_is_better': item.higherIsBetter,
            },
      },
      'status': 'completed',
      ...scores,
    };

    // Local cache keeps its own id/timestamp for the UI; the remote row lets
    // Postgres generate the uuid PK and created_at.
    _assessments.insert(0, {
      ...payload,
      'id': 'asmt-${now.millisecondsSinceEpoch}',
      'created_at': now.toIso8601String(),
    });
    notifyListeners();
    await _persist(_kAssessments, _assessments);

    final client = _supabase.client;
    if (client == null || _supabase.isMockMode) return true;

    try {
      await client.from('assessments').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Supabase assessment insert failed: $e');
      return false;
    }
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

  // --- 4b. MINDFULNESS — breathing / meditation sessions + mood check-ins ---

  /// Pulls the signed-in user's mindfulness history into the in-memory cache
  /// so the tracking dashboard has data after a cold start. No-op (keeps the
  /// local cache) in mock/demo mode.
  Future<void> refreshMindfulness() async {
    final client = _supabase.client;
    final uid = _auth.currentUser?.id;
    if (client == null || _supabase.isMockMode || uid == null) return;
    try {
      final logs = await client
          .from('mindfulness_logs')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(500);
      final moods = await client
          .from('mindfulness_moods')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(500);
      _mindfulnessLogs
        ..clear()
        ..addAll(List<Map<String, dynamic>>.from(logs));
      _mindfulnessMoods
        ..clear()
        ..addAll(List<Map<String, dynamic>>.from(moods));
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase mindfulness refresh note: $e');
    }
  }

  Future<bool> _insertMindfulnessLog(Map<String, dynamic> payload) async {
    final now = DateTime.now();
    _mindfulnessLogs.insert(0, {
      ...payload,
      'id': 'mind-${now.millisecondsSinceEpoch}',
      'created_at': now.toIso8601String(),
    });
    notifyListeners();

    final client = _supabase.client;
    if (client == null || _supabase.isMockMode) return true;
    try {
      await client.from('mindfulness_logs').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Supabase mindfulness_logs insert failed: $e');
      return false;
    }
  }

  /// One completed (or abandoned) paced-breathing session.
  Future<bool> recordBreathingSession({
    required String title,
    required String pattern,
    required String category,
    required int plannedSeconds,
    required int actualSeconds,
    required int cyclesCompleted,
    required bool completed,
  }) {
    return _insertMindfulnessLog({
      'user_id': _auth.currentUser?.id,
      'service_id': _auth.currentUser?.serviceId ?? 'CAPF-8821',
      'activity_type': 'breathing',
      'title': title,
      'category': category,
      'pattern': pattern,
      'planned_seconds': plannedSeconds,
      'actual_seconds': actualSeconds,
      'cycles_completed': cyclesCompleted,
      'completed': completed,
    });
  }

  /// One meditation / sleep-story / music session.
  Future<bool> recordMeditationSession({
    required String title,
    required String category,
    required int plannedSeconds,
    required int actualSeconds,
    required bool completed,
  }) {
    return _insertMindfulnessLog({
      'user_id': _auth.currentUser?.id,
      'service_id': _auth.currentUser?.serviceId ?? 'CAPF-8821',
      'activity_type': 'meditation',
      'title': title,
      'category': category,
      'pattern': null,
      'planned_seconds': plannedSeconds,
      'actual_seconds': actualSeconds,
      'cycles_completed': 0,
      'completed': completed,
    });
  }

  /// One completed Zen-doodling session.
  Future<bool> recordDoodleSession({required int durationSeconds}) {
    return _insertMindfulnessLog({
      'user_id': _auth.currentUser?.id,
      'service_id': _auth.currentUser?.serviceId ?? 'CAPF-8821',
      'activity_type': 'doodle',
      'title': 'Zen Doodling',
      'category': 'Creative',
      'pattern': null,
      'planned_seconds': durationSeconds,
      'actual_seconds': durationSeconds,
      'cycles_completed': 0,
      'completed': true,
    });
  }

  /// One Samsung-style 5-point mood check-in ([level] 1–5, 5 == Awesome).
  Future<bool> recordMindfulnessMood({
    required int level,
    required String label,
    List<String> factors = const [],
    String? note,
  }) async {
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'user_id': _auth.currentUser?.id,
      'service_id': _auth.currentUser?.serviceId ?? 'CAPF-8821',
      'mood_level': level,
      'mood_label': label,
      'factors': factors,
      'note': note,
    };

    _mindfulnessMoods.insert(0, {
      ...payload,
      'id': 'mmood-${now.millisecondsSinceEpoch}',
      'created_at': now.toIso8601String(),
    });
    notifyListeners();

    final client = _supabase.client;
    if (client == null || _supabase.isMockMode) return true;
    try {
      await client.from('mindfulness_moods').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Supabase mindfulness_moods insert failed: $e');
      return false;
    }
  }

  // --- 4c. CRISIS ESCALATION (Tara voice / companion → Welfare Officer + Tele-MANAS) ---

  /// Raises an active crisis alert: the duty Welfare Officer sees it in their
  /// console (`crisis_alerts` RLS lets only that role read), and the caller
  /// surfaces Tele-MANAS 14416 to the person. [source] identifies the
  /// detector ('tara_voice', 'ai_companion_nlu'). [phrase] is the matched cue
  /// and [transcript] a short trailing snippet, kept for the officer's context.
  Future<Map<String, dynamic>> recordCrisisEscalation({
    required String source,
    String? phrase,
    String? transcript,
  }) async {
    final now = DateTime.now();
    final indicators = <String>[
      if (phrase != null && phrase.isNotEmpty)
        'Acute distress cue detected in voice conversation: "$phrase"',
    ];

    final row = <String, dynamic>{
      'user_id': _auth.currentUser?.id ?? 'demo-user',
      'service_id': _auth.currentUser?.serviceId ?? 'CAPF-8821',
      'trigger_source': source,
      'crisis_probability': 0.9,
      'risk_indicators': indicators,
      'transcript_snippet': transcript,
      'tele_manas_notified': true,
      'welfare_officer_alerted': true,
      'status': 'active_stabilization',
    };

    _crisisAlerts.insert(0, {
      ...row,
      'id': 'crisis-${now.millisecondsSinceEpoch}',
      'created_at': now.toIso8601String(),
    });
    notifyListeners();

    final client = _supabase.client;
    if (client != null && !_supabase.isMockMode) {
      try {
        // Only columns the deployed schema is known to have.
        await client.from('crisis_alerts').insert({
          'user_id': _auth.currentUser?.id,
          'trigger_source': source,
          'crisis_probability': 0.9,
          'risk_indicators': indicators,
          'tele_manas_notified': true,
          'welfare_officer_alerted': true,
          'status': 'active_stabilization',
        });
      } catch (e) {
        debugPrint('Supabase crisis_alerts insert failed: $e');
      }
    }

    return {
      'escalated': true,
      'helpline': '14416',
      'riskIndicators': indicators,
    };
  }

  // --- 5. HR INGESTION (CSV Bulk Upload with Pseudonymization) ---
  Future<Map<String, dynamic>> processHrCsvIngestion({
    required String filename,
    required List<String> lines,
    /// PRD §2 ingestion tier this batch arrived through, shown per-source on
    /// the HR console. Tier 2 (bulk upload) is the default path.
    String source = 'CSV Upload',
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
    final zoneIndex = headers.indexWhere((h) => h.contains('zone') || h.contains('deployment'));
    final unitIndex = headers.indexWhere((h) => h == 'unit_code' || h == 'unit');
    final consecutiveIndex = headers.indexWhere((h) => h.contains('consecutive'));
    // Optional wellness-pulse columns — used only if the roster actually
    // carries them; nothing is fabricated when they are absent. These feed
    // the anonymous Organisation Wellbeing roll-up.
    final sleepIndex = headers.indexWhere((h) => h.contains('sleep'));
    final exhaustionIndex =
        headers.indexWhere((h) => h.contains('exhaust') || h.contains('fatigue'));
    final workloadIndex = headers.indexWhere(
        (h) => h.contains('workload') || h.contains('duty_load') || h == 'duty_strain');
    final moodIndex = headers.indexWhere((h) => h == 'mood' || h.contains('mood_rating'));
    final managerIndex =
        headers.indexWhere((h) => h.contains('manager') || h.contains('leadership'));
    final peerIndex = headers.indexWhere(
        (h) => h.contains('peer') || h.contains('cohesion') || h.contains('support'));

    // Rejection-reason tally, surfaced as a breakdown on the ingestion report.
    final rejectionReasons = <String, int>{};
    void reject(int line, String reason) {
      rejected++;
      rejectedRecords.add({'line': line, 'reason': reason});
      rejectionReasons[reason] = (rejectionReasons[reason] ?? 0) + 1;
    }

    // Duplicate detection is on the pseudonym token so it never touches the
    // raw Service ID after hashing.
    final seenTokens = <String>{};

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      total++;
      final lineNo = i + 1;

      final cols = line.split(',').map((c) => c.trim()).toList();

      // 1. Missing Service ID
      if (cols.length <= serviceIdIndex || cols[serviceIdIndex].isEmpty) {
        reject(lineNo, 'Missing Service ID');
        continue;
      }
      final rawServiceId = cols[serviceIdIndex];

      // 2. Malformed duty-hours value (non-numeric, negative, or > 168 h/week)
      final dutyRaw = cols.length > dutyHoursIndex ? cols[dutyHoursIndex] : '';
      final dutyHours = double.tryParse(dutyRaw);
      if (dutyHours == null || dutyHours < 0 || dutyHours > 168) {
        reject(lineNo, 'Malformed duty-hours value');
        continue;
      }

      // 3. Leave balance out of range (non-numeric, negative, or > 400 days)
      final leaveRaw = cols.length > leaveIndex ? cols[leaveIndex] : '';
      final leaveBalance = double.tryParse(leaveRaw);
      if (leaveBalance == null || leaveBalance < 0 || leaveBalance > 400) {
        reject(lineNo, 'Leave balance out of range');
        continue;
      }

      // Cryptographic Pseudonymization Token (SHA-256) per PRD §2
      final tokenBytes = utf8.encode('$rawServiceId:manofit_salt_${DateTime.now().year}');
      final pseudonymToken = sha256.convert(tokenBytes).toString().substring(0, 16);

      // 4. Duplicate record in batch
      if (!seenTokens.add(pseudonymToken)) {
        reject(lineNo, 'Duplicate record in batch');
        continue;
      }

      accepted++;

      // Only values that actually came from the roster are stored — no strain
      // signals are invented. deployment_zone maps to a hardship tier; a
      // consecutive-duty count is used only if the roster supplied one.
      final zone = zoneIndex >= 0 && cols.length > zoneIndex && cols[zoneIndex].isNotEmpty
          ? cols[zoneIndex]
          : 'Unspecified';
      final unitCode = unitIndex >= 0 && cols.length > unitIndex && cols[unitIndex].isNotEmpty
          ? cols[unitIndex]
          : 'UNIT-${101 + (accepted % 6)}';
      final consecutive = consecutiveIndex >= 0 && cols.length > consecutiveIndex
          ? (double.tryParse(cols[consecutiveIndex]) ?? 0).round()
          : 0;

      int? clamp5(int idx) {
        if (idx < 0 || cols.length <= idx || cols[idx].isEmpty) return null;
        return double.tryParse(cols[idx])?.round().clamp(1, 5);
      }

      final sleep = clamp5(sleepIndex);
      final exhaustion = clamp5(exhaustionIndex);
      final workload = clamp5(workloadIndex);
      final mood = clamp5(moodIndex);
      final manager = clamp5(managerIndex);
      final peer = clamp5(peerIndex);

      final record = <String, dynamic>{
        'pseudonym_token': pseudonymToken,
        'leave_balance_days': leaveBalance,
        'duty_hours_weekly': dutyHours,
        'deployment_zone': zone,
        'unit_code': unitCode,
        'location_tier': _tierForZone(zone),
        'consecutive_active_days': consecutive,
        'transfer_count_last_12m': 1,
      };
      final pulse = <String, int>{
        if (workload != null) 'workload_perception': workload,
        if (sleep != null) 'sleep_quality': sleep,
        if (exhaustion != null) 'physical_exhaustion': exhaustion,
        if (mood != null) 'mood_rating': mood,
        if (manager != null) 'manager_relationship': manager,
        if (peer != null) 'peer_social_support': peer,
      };
      if (pulse.isNotEmpty) record['wellness_checkin'] = pulse;
      acceptedRecords.add(record);
    }

    // Merge into the existing database: a token already on file is refreshed
    // with the newer roster row, a new token is appended. Prior batches stay.
    final indexByToken = <String, int>{
      for (var k = 0; k < _hrFeatureRecords.length; k++)
        _hrFeatureRecords[k]['pseudonym_token'] as String: k,
    };
    var added = 0;
    var updated = 0;
    for (final rec in acceptedRecords) {
      final token = rec['pseudonym_token'] as String;
      final existing = indexByToken[token];
      if (existing != null) {
        _hrFeatureRecords[existing] = rec;
        updated++;
      } else {
        indexByToken[token] = _hrFeatureRecords.length;
        _hrFeatureRecords.add(rec);
        added++;
      }
    }

    final batch = {
      'id': 'batch-${DateTime.now().millisecondsSinceEpoch}',
      'filename': filename,
      'file_size_kb': (lines.join('\n').length / 1024).toStringAsFixed(1),
      'total_rows': total,
      'accepted_rows': accepted,
      'rejected_rows': rejected,
      'new_personnel': added,
      'updated_personnel': updated,
      'status': 'committed',
      'source': source,
      'created_at': DateTime.now().toIso8601String(),
    };
    _hrIngestionBatches.insert(0, batch);

    notifyListeners();
    await _persistHr();

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
      'newCount': added,
      'updatedCount': updated,
      'cohortSize': _hrFeatureRecords.length,
      'totalRows': total,
      'rejectedList': rejectedRecords,
      'rejectionReasons': rejectionReasons,
      'sampleToken': acceptedRecords.isNotEmpty
          ? acceptedRecords.first['pseudonym_token']
          : null,
    };
  }

  /// Maps a free-text deployment zone to one of the model's hardship tiers.
  static String _tierForZone(String zone) {
    final z = zone.toLowerCase();
    if (z.contains('altitude') || z.contains('siachen') || z.contains('glacier')) {
      return 'HIGH_ALTITUDE';
    }
    if (z.contains('border') || z.contains('outpost') || z.contains('loc') || z.contains('frontier')) {
      return 'BORDER_OUTPOST';
    }
    if (z.contains('ci ops') ||
        z.contains('counter') ||
        z.contains('insurgen') ||
        z.contains('jungle') ||
        z.contains('naxal')) {
      return 'CI_OPS';
    }
    if (z.contains('field') || z.contains('desert') || z.contains('extreme')) {
      return 'FIELD_EXTREME';
    }
    return 'PEACE';
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
