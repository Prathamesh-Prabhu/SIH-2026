import 'package:flutter/material.dart';

/// The six private check-ins from PRD §7 ("Assessments — the 6 private
/// check-ins (workload, mood, manager relationship, etc.)") and the
/// architecture doc's `assessments` table.
///
/// **Scale direction is a hard contract with the ML layer.** The analytics
/// pipeline treats `workload_perception` and `physical_exhaustion` as
/// higher = worse, and the other four as higher = better (see
/// `DbService._generateDemoCohort` and `MlService`'s exhaustion/support
/// factors). The option labels below are written to match that orientation —
/// changing their order silently inverts the model's inputs.
class CheckInItem {
  /// Column name in `public.assessments` and key in the ML payload.
  final String key;
  final String question;
  final String helper;
  final IconData icon;

  /// true  → 5 is a good outcome (mood, sleep, manager, peers)
  /// false → 5 is a bad outcome (workload, exhaustion)
  final bool higherIsBetter;

  /// Exactly five labels, index 0 == value 1 … index 4 == value 5.
  final List<String> labels;

  const CheckInItem({
    required this.key,
    required this.question,
    required this.helper,
    required this.icon,
    required this.higherIsBetter,
    required this.labels,
  });
}

const List<CheckInItem> kWellbeingCheckIns = [
  CheckInItem(
    key: 'workload_perception',
    question: 'How manageable has your duty load felt recently?',
    helper: 'Think about your shifts, taskings and rotations over the past week.',
    icon: Icons.work_history_outlined,
    higherIsBetter: false,
    labels: [
      'Very manageable',
      'Mostly manageable',
      'Demanding, but coping',
      'Heavy: starting to strain',

      'Overwhelming',
    ],
  ),
  CheckInItem(
    key: 'sleep_quality',
    question: 'How well have you been resting between duties?',
    helper: 'Both the amount and the quality of sleep you have been getting.',
    icon: Icons.bedtime_outlined,
    higherIsBetter: true,
    labels: [
      'Very poorly',
      'Poorly',
      'Broken, but enough',
      'Well',
      'Very well',
    ],
  ),
  CheckInItem(
    key: 'physical_exhaustion',
    question: 'How physically drained do you feel?',
    helper: 'Your body’s tiredness, separate from your mood.',
    icon: Icons.battery_2_bar_outlined,
    higherIsBetter: false,
    labels: [
      'Not at all',
      'Slightly tired',
      'Moderately tired',
      'Very drained',
      'Completely depleted',
    ],
  ),
  CheckInItem(
    key: 'mood_rating',
    question: 'How has your overall mood been?',
    helper: 'Your general emotional state across the past few days.',
    icon: Icons.sentiment_satisfied_outlined,
    higherIsBetter: true,
    labels: [
      'Very low',
      'Low',
      'Neutral',
      'Good',
      'Very good',
    ],
  ),
  CheckInItem(
    key: 'manager_relationship',
    question: 'How supported do you feel by your immediate superior?',
    helper: 'Being heard, treated fairly, and backed when it matters.',
    icon: Icons.supervisor_account_outlined,
    higherIsBetter: true,
    labels: [
      'Not at all supported',
      'Rarely supported',
      'Sometimes supported',
      'Supported',
      'Strongly supported',
    ],
  ),
  CheckInItem(
    key: 'peer_social_support',
    question: 'How connected do you feel to the people in your unit?',
    helper: 'Having people around you that you could actually talk to.',
    icon: Icons.groups_outlined,
    higherIsBetter: true,
    labels: [
      'Isolated',
      'Distant',
      'Some connection',
      'Connected',
      'Strongly connected',
    ],
  ),
];

/// Orients every answer so higher always means "doing better", then sums.
/// Range 6–30. Used internally / by the ML layer — never shown to the user
/// (PRD §7: the app shows no score or risk signal back to personnel).
int orientedWellbeingTotal(Map<String, int> answers) {
  var total = 0;
  for (final item in kWellbeingCheckIns) {
    final v = answers[item.key];
    if (v == null) continue;
    total += item.higherIsBetter ? v : (6 - v);
  }
  return total;
}
