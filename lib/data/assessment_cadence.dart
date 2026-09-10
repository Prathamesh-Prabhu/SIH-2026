import 'package:flutter/material.dart';

/// The three recurring assessments personnel can attend. Each cadence has its
/// own question bank (`assessment_questions.dart`) — a quick today-read for
/// daily, the full six-domain check-in weekly, and a deeper reflective review
/// monthly. Every completion is tagged with its cadence and feeds the anonymous
/// Organisation Wellbeing roll-up on the HR dashboard the moment it is
/// submitted.
enum CheckInCadence { daily, weekly, monthly }

extension CheckInCadenceX on CheckInCadence {
  String get id => name;

  String get title => switch (this) {
        CheckInCadence.daily => 'Daily pulse',
        CheckInCadence.weekly => 'Weekly check-in',
        CheckInCadence.monthly => 'Monthly review',
      };

  String get blurb => switch (this) {
        CheckInCadence.daily => 'A quick read on today',
        CheckInCadence.weekly => 'The full six-domain check-in',
        CheckInCadence.monthly => 'A deeper look back over the month',
      };

  /// One-line framing shown at the top of the questionnaire.
  String get horizon => switch (this) {
        CheckInCadence.daily => 'Answer for how today feels — takes under a minute.',
        CheckInCadence.weekly =>
          'Think across the whole week, not just today.',
        CheckInCadence.monthly =>
          'A monthly look back — workload, rest, support, and the bigger picture.',
      };

  IconData get icon => switch (this) {
        CheckInCadence.daily => Icons.wb_sunny_outlined,
        CheckInCadence.weekly => Icons.event_repeat_outlined,
        CheckInCadence.monthly => Icons.calendar_month_outlined,
      };

  /// Accent colour used across the hub card and questionnaire for this cadence.
  Color get accent => switch (this) {
        CheckInCadence.daily => const Color(0xFF2E7D5B),
        CheckInCadence.weekly => const Color(0xFF1F6F8B),
        CheckInCadence.monthly => const Color(0xFF6A4C93),
      };

  Duration get interval => switch (this) {
        CheckInCadence.daily => const Duration(days: 1),
        CheckInCadence.weekly => const Duration(days: 7),
        CheckInCadence.monthly => const Duration(days: 30),
      };
}

CheckInCadence cadenceFromId(String? id) => switch (id) {
      'daily' => CheckInCadence.daily,
      'monthly' => CheckInCadence.monthly,
      _ => CheckInCadence.weekly,
    };

/// Short "due in 3d" / "due now" phrasing from a last-completed timestamp.
String cadenceDueLabel(CheckInCadence cadence, DateTime? last) {
  if (last == null) return 'Not started';
  final next = last.add(cadence.interval);
  final remaining = next.difference(DateTime.now());
  if (remaining.isNegative) return 'Due now';
  if (remaining.inHours < 24) return 'Due in ${remaining.inHours + 1}h';
  return 'Due in ${remaining.inDays + 1}d';
}
