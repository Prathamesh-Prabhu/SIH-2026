import 'package:flutter/material.dart';

import 'assessment_cadence.dart';

/// Cadence-specific question banks for the private check-ins.
///
/// The **daily** and **weekly** banks only use the six canonical wellbeing
/// domains (see [kWellbeingCheckIns] / `org_wellbeing.dart`) so every answer
/// still feeds the ML layer and the Organisation Wellbeing roll-up unchanged —
/// they differ only in horizon ("today" vs "this week") and wording.
///
/// The **monthly** bank keeps those six (month framing) and adds four deeper
/// reflective domains (purpose, home strain, money pressure, future in the
/// service). Those extra keys are persisted inside the assessment's `answers`
/// blob and surface in the HR "Monthly deep-dive" panel; they are not written
/// as `assessments` columns and never reach the cohort ML scorer.
class AssessmentQuestion {
  const AssessmentQuestion({
    required this.key,
    required this.question,
    required this.helper,
    required this.icon,
    required this.higherIsBetter,
    required this.labels,
    this.core = true,
  });

  /// Column / payload key. The six core keys match `public.assessments`.
  final String key;
  final String question;
  final String helper;
  final IconData icon;

  /// true  → 5 is a good outcome · false → 5 is a bad outcome.
  final bool higherIsBetter;

  /// Exactly five labels, index 0 == value 1 … index 4 == value 5.
  final List<String> labels;

  /// One of the six canonical domains (feeds ML + the org roll-up).
  final bool core;
}

// ── Daily pulse — 4 quick, today-framed reads ──────────────────────────────
const List<AssessmentQuestion> kDailyQuestions = [
  AssessmentQuestion(
    key: 'mood_rating',
    question: "How's your mood today?",
    helper: 'Your general emotional state right now.',
    icon: Icons.sentiment_satisfied_outlined,
    higherIsBetter: true,
    labels: ['Very low', 'Low', 'Okay', 'Good', 'Great'],
  ),
  AssessmentQuestion(
    key: 'physical_exhaustion',
    question: 'How physically tired are you right now?',
    helper: "Your body's tiredness, separate from your mood.",
    icon: Icons.battery_2_bar_outlined,
    higherIsBetter: false,
    labels: [
      'Fresh',
      'A little tired',
      'Moderately tired',
      'Very drained',
      'Running on empty',
    ],
  ),
  AssessmentQuestion(
    key: 'sleep_quality',
    question: 'How well did you sleep last night?',
    helper: 'Both the hours and how rested you feel.',
    icon: Icons.bedtime_outlined,
    higherIsBetter: true,
    labels: ['Very poorly', 'Poorly', 'Okay', 'Well', 'Very well'],
  ),
  AssessmentQuestion(
    key: 'workload_perception',
    question: "How heavy is today's duty load?",
    helper: 'Shifts, taskings and anything pulling at your time today.',
    icon: Icons.work_history_outlined,
    higherIsBetter: false,
    labels: ['Light', 'Manageable', 'Busy', 'Heavy', 'Relentless'],
  ),
];

// ── Weekly check-in — the full six domains, week-framed ────────────────────
const List<AssessmentQuestion> kWeeklyQuestions = [
  AssessmentQuestion(
    key: 'workload_perception',
    question: 'How manageable has your duty load been this week?',
    helper: 'Think across your shifts, taskings and rotations this week.',
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
  AssessmentQuestion(
    key: 'sleep_quality',
    question: 'How well have you rested between duties this week?',
    helper: 'Both the amount and the quality of your sleep.',
    icon: Icons.bedtime_outlined,
    higherIsBetter: true,
    labels: ['Very poorly', 'Poorly', 'Broken, but enough', 'Well', 'Very well'],
  ),
  AssessmentQuestion(
    key: 'physical_exhaustion',
    question: 'How physically drained have you felt this week?',
    helper: "Your body's tiredness, separate from your mood.",
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
  AssessmentQuestion(
    key: 'mood_rating',
    question: 'How has your mood been across this week?',
    helper: 'Your general emotional state over the past several days.',
    icon: Icons.sentiment_satisfied_outlined,
    higherIsBetter: true,
    labels: ['Very low', 'Low', 'Neutral', 'Good', 'Very good'],
  ),
  AssessmentQuestion(
    key: 'manager_relationship',
    question: 'How supported have you felt by your immediate superior this week?',
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
  AssessmentQuestion(
    key: 'peer_social_support',
    question: 'How connected have you felt to your unit this week?',
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

// ── Monthly review — six core (month-framed) + four reflective domains ─────
const List<AssessmentQuestion> kMonthlyQuestions = [
  AssessmentQuestion(
    key: 'workload_perception',
    question: 'Looking back over the month, how sustainable has your workload been?',
    helper: 'Not just busy days — whether the pace is one you can keep up.',
    icon: Icons.work_history_outlined,
    higherIsBetter: false,
    labels: [
      'Very sustainable',
      'Sustainable',
      'Stretched',
      'Hard to sustain',
      'Unsustainable',
    ],
  ),
  AssessmentQuestion(
    key: 'sleep_quality',
    question: 'Over the month, how has your sleep held up?',
    helper: 'The overall pattern, not one or two bad nights.',
    icon: Icons.bedtime_outlined,
    higherIsBetter: true,
    labels: ['Very poor', 'Poor', 'Uneven', 'Good', 'Very good'],
  ),
  AssessmentQuestion(
    key: 'physical_exhaustion',
    question: 'How has your body held up this month?',
    helper: 'Cumulative physical wear, aches, and recovery.',
    icon: Icons.battery_2_bar_outlined,
    higherIsBetter: false,
    labels: ['Strong', 'Mostly fine', 'Wearing down', 'Very worn', 'Depleted'],
  ),
  AssessmentQuestion(
    key: 'mood_rating',
    question: 'How has your overall mood been this month?',
    helper: 'Your emotional baseline across the weeks.',
    icon: Icons.sentiment_satisfied_outlined,
    higherIsBetter: true,
    labels: ['Very low', 'Low', 'Steady', 'Good', 'Very good'],
  ),
  AssessmentQuestion(
    key: 'manager_relationship',
    question: 'This month, how backed have you felt by your leadership?',
    helper: 'Fair treatment and support when things got hard.',
    icon: Icons.supervisor_account_outlined,
    higherIsBetter: true,
    labels: [
      'Not at all',
      'Rarely',
      'Sometimes',
      'Backed',
      'Strongly backed',
    ],
  ),
  AssessmentQuestion(
    key: 'peer_social_support',
    question: 'This month, how strong have your bonds in the unit felt?',
    helper: 'People you trust and can lean on around you.',
    icon: Icons.groups_outlined,
    higherIsBetter: true,
    labels: ['Isolated', 'Distant', 'Some', 'Strong', 'Very strong'],
  ),
  AssessmentQuestion(
    key: 'purpose_meaning',
    question: 'How meaningful has your work felt this month?',
    helper: 'A sense that what you do matters.',
    icon: Icons.flag_outlined,
    higherIsBetter: true,
    core: false,
    labels: [
      'No meaning',
      'Rarely meaningful',
      'Sometimes',
      'Often',
      'Strong sense of purpose',
    ],
  ),
  AssessmentQuestion(
    key: 'home_family_strain',
    question: 'How much strain has time away from home or family caused this month?',
    helper: 'Distance, missed events, worry about people back home.',
    icon: Icons.home_outlined,
    higherIsBetter: false,
    core: false,
    labels: ['None', 'A little', 'Moderate', 'Heavy', 'Severe'],
  ),
  AssessmentQuestion(
    key: 'financial_pressure',
    question: 'How much financial pressure have you felt this month?',
    helper: 'Money worries that sit at the back of your mind.',
    icon: Icons.savings_outlined,
    higherIsBetter: false,
    core: false,
    labels: ['None', 'Slight', 'Manageable', 'Heavy', 'Overwhelming'],
  ),
  AssessmentQuestion(
    key: 'future_in_service',
    question: 'When you think about your future in the service, how do you feel?',
    helper: 'Your outlook on staying and building a career here.',
    icon: Icons.timeline_outlined,
    higherIsBetter: true,
    core: false,
    labels: [
      'Want out',
      'Doubtful',
      'Unsure',
      'Mostly positive',
      'Committed & positive',
    ],
  ),
];

/// The question bank for a cadence, in presentation order.
List<AssessmentQuestion> questionsForCadence(CheckInCadence cadence) =>
    switch (cadence) {
      CheckInCadence.daily => kDailyQuestions,
      CheckInCadence.weekly => kWeeklyQuestions,
      CheckInCadence.monthly => kMonthlyQuestions,
    };

/// Every distinct question across all cadences, keyed by [AssessmentQuestion.key]
/// — used to resolve labels/wording when persisting an answer blob.
final Map<String, AssessmentQuestion> kAssessmentQuestionByKey = {
  for (final q in [...kMonthlyQuestions, ...kWeeklyQuestions, ...kDailyQuestions])
    q.key: q,
};

/// The monthly-only reflective domains and what counts as an adverse answer,
/// for the HR "Monthly deep-dive" panel.
class DeepDiveDomain {
  const DeepDiveDomain(this.key, this.label, this.icon, this.isAdverse);
  final String key;
  final String label;
  final IconData icon;
  final bool Function(int value) isAdverse;
}

final List<DeepDiveDomain> kDeepDiveDomains = [
  DeepDiveDomain('purpose_meaning', 'Low sense of purpose',
      Icons.flag_outlined, (v) => v <= 2),
  DeepDiveDomain('home_family_strain', 'Strain from time away from home',
      Icons.home_outlined, (v) => v >= 4),
  DeepDiveDomain('financial_pressure', 'Financial pressure',
      Icons.savings_outlined, (v) => v >= 4),
  DeepDiveDomain('future_in_service', 'Doubts about a future in the service',
      Icons.timeline_outlined, (v) => v <= 2),
];
