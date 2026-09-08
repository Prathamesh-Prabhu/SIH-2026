import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

class DbService extends ChangeNotifier {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  // In-memory cache for fast UI updates & offline fallback
  final List<Map<String, dynamic>> _moodLogs = [];
  final List<Map<String, dynamic>> _assessments = [];
  final List<Map<String, dynamic>> _counselingSessions = [];
  final List<Map<String, dynamic>> _companionChats = [];
  final List<Map<String, dynamic>> _hrIngestionBatches = [];

  List<Map<String, dynamic>> get moodLogs => List.unmodifiable(_moodLogs);
  List<Map<String, dynamic>> get assessments => List.unmodifiable(_assessments);
  List<Map<String, dynamic>> get counselingSessions => List.unmodifiable(_counselingSessions);
  List<Map<String, dynamic>> get companionChats => List.unmodifiable(_companionChats);
  List<Map<String, dynamic>> get hrIngestionBatches => List.unmodifiable(_hrIngestionBatches);

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
      acceptedRecords.add({
        'pseudonym_token': pseudonymToken,
        'leave_balance_days': leaveBalance,
        'duty_hours_weekly': dutyHours,
        'deployment_zone': 'Northern Sector',
        'shift_type': 'Standard Rotation',
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

    // High-recall crisis classifier per PRD §4
    final lower = text.toLowerCase();
    final crisisKeywords = [
      'suicide', 'kill myself', 'end my life', 'end it all', 'die', 
      'hopeless', 'no reason to live', 'cannot take this anymore', 
      'give up', 'hurt myself', 'can\'t go on'
    ];

    bool isCrisis = false;
    String? detectedKeyword;
    for (final kw in crisisKeywords) {
      if (lower.contains(kw)) {
        isCrisis = true;
        detectedKeyword = kw;
        break;
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));

    String botReply;
    if (isCrisis) {
      botReply = 'I hear how deeply challenging things feel right now, and I want you to know you are not alone. Please stay with me. Tele-MANAS (14416) is available right this second with confidential, compassionate professional support.';
      
      // Auto-escalate alert
      final client = _supabase.client;
      if (client != null && !_supabase.isMockMode) {
        try {
          await client.from('crisis_alerts').insert({
            'user_id': _auth.currentUser?.id ?? 'demo-user',
            'trigger_source': 'ai_companion_nlu',
            'tele_manas_notified': true,
            'welfare_officer_alerted': true,
            'status': 'active_stabilization',
          });
        } catch (_) {}
      }
    } else {
      if (lower.contains('stress') || lower.contains('tired') || lower.contains('shift')) {
        botReply = 'Operational fatigue is very real, especially after long rotations. Take a slow, steady breath. Would you like to do a quick 2-minute box breathing cycle together, or simply talk through your day?';
      } else if (lower.contains('sleep') || lower.contains('night')) {
        botReply = 'Rest is the foundation of endurance. Disrupted sleep can increase cognitive strain. Let\'s try easing the rhythm with calming breathing in our Self-Help section.';
      } else {
        botReply = 'Thank you for sharing that with me. I am here to listen anytime in complete confidence. What is on your mind today?';
      }
    }

    final botMsg = {
      'id': 'msg-bot-${DateTime.now().millisecondsSinceEpoch}',
      'sender': 'assistant',
      'message': botReply,
      'is_crisis': isCrisis,
      'crisis_keyword': detectedKeyword,
      'created_at': DateTime.now().toIso8601String(),
    };
    _companionChats.add(botMsg);
    notifyListeners();

    return {
      'reply': botReply,
      'isCrisis': isCrisis,
    };
  }
}
