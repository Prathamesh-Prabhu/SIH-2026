import 'package:flutter/material.dart';

/// Static catalogue for the Mindfulness section — breathing patterns,
/// meditation library and the Samsung-Health-style 5-point mood scale.
///
/// Nothing here is user data; every *session* the user completes is written
/// through [DbService.recordBreathingSession] / [DbService.recordMeditationSession]
/// / [DbService.recordMindfulnessMood] and persisted to Supabase
/// (`mindfulness_logs`, `mindfulness_moods`).

// ── Mood scale ─────────────────────────────────────────────────────────────
/// The five levels drawn in the Samsung "How do you feel right now?" flow.
/// `level` 5 == Awesome … 1 == Terrible. Stored in `mindfulness_moods.mood_level`.
class MoodLevel {
  const MoodLevel(this.level, this.label, this.icon, this.color);

  final int level;
  final String label;
  final IconData icon;
  final Color color;
}

const List<MoodLevel> kMoodLevels = [
  MoodLevel(5, 'Awesome', Icons.sentiment_very_satisfied, Color(0xFF4F9CD6)),
  MoodLevel(4, 'Good', Icons.sentiment_satisfied_alt, Color(0xFF4CAF6E)),
  MoodLevel(3, 'Fine', Icons.sentiment_satisfied, Color(0xFFE7B93C)),
  MoodLevel(2, 'Bad', Icons.sentiment_dissatisfied, Color(0xFFE8894B)),
  MoodLevel(1, 'Terrible', Icons.sentiment_very_dissatisfied, Color(0xFFDB5C4A)),
];

MoodLevel moodLevelFor(int level) =>
    kMoodLevels.firstWhere((m) => m.level == level, orElse: () => kMoodLevels[2]);

/// Contributing-factor chips offered after the face selection.
const List<String> kMoodFactors = [
  'Work',
  'Sleep',
  'Family',
  'Health',
  'Deployment',
  'Finance',
  'Relationships',
  'Weather',
  'Rest day',
];

// ── Breathing ─────────────────────────────────────────────────────────────
class BreathPhase {
  const BreathPhase(this.label, this.seconds);
  final String label;
  final int seconds;
}

class BreathingPattern {
  const BreathingPattern({
    required this.id,
    required this.name,
    required this.ratio,
    required this.tag,
    required this.blurb,
    required this.phases,
    this.defaultMinutes = 5,
    this.customisable = false,
  });

  final String id;
  final String name;
  final String ratio; // '4-4-4-4'
  final String tag; // 'Relaxation'
  final String blurb;
  final List<BreathPhase> phases;
  final int defaultMinutes;
  final bool customisable;

  int get cycleSeconds => phases.fold(0, (a, p) => a + p.seconds);
}

const List<BreathingPattern> kBreathingPatterns = [
  BreathingPattern(
    id: 'box',
    name: 'Box',
    ratio: '4-4-4-4',
    tag: 'Relaxation',
    blurb:
        'Equal inhale, hold, exhale and empty-hold. Steadies the nervous system before or after duty.',
    phases: [
      BreathPhase('Breathe in', 4),
      BreathPhase('Hold', 4),
      BreathPhase('Breathe out', 4),
      BreathPhase('Hold', 4),
    ],
  ),
  BreathingPattern(
    id: 'long_exhale',
    name: 'Long exhale',
    ratio: '4-7-8',
    tag: 'Sleep',
    blurb:
        'A longer exhale tells the vagus nerve you are safe — useful for winding down and falling asleep.',
    phases: [
      BreathPhase('Breathe in', 4),
      BreathPhase('Hold', 7),
      BreathPhase('Breathe out', 8),
    ],
  ),
  BreathingPattern(
    id: 'equal',
    name: 'Equal',
    ratio: '5-0-5',
    tag: 'Focus',
    blurb:
        'Matched inhale and exhale with no hold. Brings a scattered mind back to a single point.',
    phases: [
      BreathPhase('Breathe in', 5),
      BreathPhase('Breathe out', 5),
    ],
  ),
  BreathingPattern(
    id: 'custom',
    name: 'Custom',
    ratio: 'Set your own',
    tag: 'Your pattern',
    blurb: 'Set your own inhale, hold and exhale lengths, then practise.',
    phases: [
      BreathPhase('Breathe in', 4),
      BreathPhase('Hold', 2),
      BreathPhase('Breathe out', 6),
    ],
    customisable: true,
  ),
];

// ── Meditation library ────────────────────────────────────────────────────
enum MeditationTab { meditate, sleepStories, music }

extension MeditationTabLabel on MeditationTab {
  String get label => switch (this) {
        MeditationTab.meditate => 'Meditate',
        MeditationTab.sleepStories => 'Sleep stories',
        MeditationTab.music => 'Music',
      };
}

class MeditationSession {
  const MeditationSession({
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.category,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final int minutes;
  final String category;
  final bool locked;
}

class MeditationGroup {
  const MeditationGroup(this.title, this.tab, this.sessions);
  final String title;
  final MeditationTab tab;
  final List<MeditationSession> sessions;
}

const List<MeditationGroup> kMeditationGroups = [
  MeditationGroup('Recommended for you', MeditationTab.meditate, [
    MeditationSession(
      title: 'Daily Calm',
      subtitle: 'A fresh 10-minute reset every day',
      minutes: 10,
      category: 'Recommended',
    ),
    MeditationSession(
      title: '7 Days of Calm',
      subtitle: 'Build the habit, one day at a time',
      minutes: 8,
      category: 'Recommended',
    ),
  ]),
  MeditationGroup('Sleep', MeditationTab.meditate, [
    MeditationSession(
      title: '7 Days of Sleep',
      subtitle: 'Ease into deep rest between rotations',
      minutes: 20,
      category: 'Sleep',
    ),
    MeditationSession(
      title: 'Bedtime Body Scan',
      subtitle: 'Release tension from head to toe',
      minutes: 15,
      category: 'Sleep',
    ),
  ]),
  MeditationGroup('Anxiety', MeditationTab.meditate, [
    MeditationSession(
      title: 'Breathe into Calm',
      subtitle: 'Settle a racing mind quickly',
      minutes: 6,
      category: 'Anxiety',
    ),
    MeditationSession(
      title: 'Grounding in the Present',
      subtitle: 'Come back to here and now',
      minutes: 9,
      category: 'Anxiety',
    ),
  ]),
  MeditationGroup('Sleep stories', MeditationTab.sleepStories, [
    MeditationSession(
      title: 'The Night Train',
      subtitle: 'A slow journey through quiet country',
      minutes: 25,
      category: 'Sleep story',
    ),
    MeditationSession(
      title: 'Still Waters',
      subtitle: 'Drift off beside a calm mountain lake',
      minutes: 22,
      category: 'Sleep story',
    ),
  ]),
  MeditationGroup('Music', MeditationTab.music, [
    MeditationSession(
      title: 'Deep Focus',
      subtitle: 'Ambient textures for concentration',
      minutes: 30,
      category: 'Music',
    ),
    MeditationSession(
      title: 'Rain on Canvas',
      subtitle: 'Soft rainfall for rest',
      minutes: 45,
      category: 'Music',
    ),
  ]),
];
