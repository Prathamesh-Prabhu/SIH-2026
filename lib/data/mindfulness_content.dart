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
        'A longer exhale tells the vagus nerve you are safe, useful for winding down and falling asleep.',

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
enum MeditationTab { meditate, sleep, music }

extension MeditationTabLabel on MeditationTab {
  String get label => switch (this) {
        MeditationTab.meditate => 'Meditate',
        MeditationTab.sleep => 'Sleep',
        MeditationTab.music => 'Music',
      };
}

/// Soothing ambience loops, hosted on Google's free Sound Library
/// (https://developers.google.com/assistant/tools/sound-library). Streamed and
/// looped for the length of a session. Drop-in replacements can be bundled
/// under `assets/audio/` and referenced with [MeditationSession.assetPath].
class _Snd {
  static const rainRoof =
      'https://actions.google.com/sounds/v1/weather/rain_on_roof.ogg';
  static const rainLight =
      'https://actions.google.com/sounds/v1/weather/light_rain.ogg';
  static const waves =
      'https://actions.google.com/sounds/v1/water/waves_crashing_on_rock_beach.ogg';
  static const oceanLap =
      'https://actions.google.com/sounds/v1/water/water_lapping_wind.ogg';
  static const stream =
      'https://actions.google.com/sounds/v1/water/small_stream_flowing.ogg';
  static const river =
      'https://actions.google.com/sounds/v1/water/water_running_by.ogg';
  static const fountain =
      'https://actions.google.com/sounds/v1/water/fountain_water_bubbling.ogg';
  static const forestDay =
      'https://actions.google.com/sounds/v1/ambiences/summer_forest.ogg';
  static const forestSpring =
      'https://actions.google.com/sounds/v1/ambiences/spring_day_forest.ogg';
  static const birdsMorning =
      'https://actions.google.com/sounds/v1/ambiences/jungle_atmosphere_morning.ogg';
  static const nightCrickets =
      'https://actions.google.com/sounds/v1/ambiences/july_night.ogg';
  static const campfire =
      'https://actions.google.com/sounds/v1/ambiences/fire.ogg';
  static const bonfire =
      'https://actions.google.com/sounds/v1/ambiences/daytime_forrest_bonfire.ogg';
  static const warmEvening =
      'https://actions.google.com/sounds/v1/ambiences/warm_evening_outdoors.ogg';
}

class MeditationSession {
  const MeditationSession({
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.category,
    required this.icon,
    required this.accent,
    this.audioUrl,
    this.assetPath,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final int minutes;
  final String category;
  final IconData icon;
  final Color accent;

  /// Looping ambience streamed for the session. Null → a silent guided timer.
  final String? audioUrl;

  /// Optional bundled track under `assets/audio/` (e.g. `audio/daily_calm.mp3`),
  /// preferred over [audioUrl] when set.
  final String? assetPath;

  final bool locked;
}

class MeditationGroup {
  const MeditationGroup(this.title, this.tab, this.sessions);
  final String title;
  final MeditationTab tab;
  final List<MeditationSession> sessions;
}

const List<MeditationGroup> kMeditationGroups = [
  // ── Meditate ────────────────────────────────────────────────────────────
  MeditationGroup('Daily reset', MeditationTab.meditate, [
    MeditationSession(
      title: 'Daily Calm',
      subtitle: 'A 10-minute reset for any time of day',
      minutes: 10,
      category: 'Meditate',
      icon: Icons.wb_twilight_rounded,
      accent: Color(0xFF2E7D5B),
      audioUrl: _Snd.forestSpring,
    ),
    MeditationSession(
      title: 'Morning Clarity',
      subtitle: 'Start the day settled and clear',
      minutes: 8,
      category: 'Meditate',
      icon: Icons.wb_sunny_outlined,
      accent: Color(0xFFC9922E),
      audioUrl: _Snd.birdsMorning,
    ),
  ]),
  MeditationGroup('Ease anxiety', MeditationTab.meditate, [
    MeditationSession(
      title: 'Breathe into Calm',
      subtitle: 'Settle a racing mind quickly',
      minutes: 6,
      category: 'Anxiety',
      icon: Icons.air_rounded,
      accent: Color(0xFF3E7CB1),
      audioUrl: _Snd.rainLight,
    ),
    MeditationSession(
      title: 'Grounding in the Present',
      subtitle: 'Come back to here and now',
      minutes: 9,
      category: 'Anxiety',
      icon: Icons.spa_outlined,
      accent: Color(0xFF4C7A4C),
      audioUrl: _Snd.stream,
    ),
    MeditationSession(
      title: 'Let the Wave Pass',
      subtitle: 'Ride out a surge of stress',
      minutes: 7,
      category: 'Anxiety',
      icon: Icons.waves_outlined,
      accent: Color(0xFF2D6E8E),
      audioUrl: _Snd.waves,
    ),
  ]),
  MeditationGroup('Focus', MeditationTab.meditate, [
    MeditationSession(
      title: 'Deep Focus',
      subtitle: 'Hold attention on a single point',
      minutes: 12,
      category: 'Focus',
      icon: Icons.center_focus_strong_rounded,
      accent: Color(0xFF5B5BA6),
      audioUrl: _Snd.rainRoof,
    ),
    MeditationSession(
      title: 'Steady Attention',
      subtitle: 'A quiet anchor for busy days',
      minutes: 10,
      category: 'Focus',
      icon: Icons.filter_center_focus_rounded,
      accent: Color(0xFF6A4C93),
      audioUrl: _Snd.fountain,
    ),
  ]),

  // ── Sleep ───────────────────────────────────────────────────────────────
  MeditationGroup('Wind down', MeditationTab.sleep, [
    MeditationSession(
      title: 'Bedtime Body Scan',
      subtitle: 'Release tension from head to toe',
      minutes: 15,
      category: 'Sleep',
      icon: Icons.nightlight_round,
      accent: Color(0xFF3B4E8C),
      audioUrl: _Snd.warmEvening,
    ),
    MeditationSession(
      title: 'Long Exhale to Sleep',
      subtitle: 'Slow the breath, slow the mind',
      minutes: 12,
      category: 'Sleep',
      icon: Icons.bedtime_outlined,
      accent: Color(0xFF4A4E9C),
      audioUrl: _Snd.rainLight,
    ),
  ]),
  MeditationGroup('Sleep soundscapes', MeditationTab.sleep, [
    MeditationSession(
      title: 'Rain at Night',
      subtitle: 'Steady rain on the roof',
      minutes: 45,
      category: 'Sleep',
      icon: Icons.water_drop_outlined,
      accent: Color(0xFF3E5C76),
      audioUrl: _Snd.rainRoof,
    ),
    MeditationSession(
      title: 'Night Crickets',
      subtitle: 'A still summer night',
      minutes: 45,
      category: 'Sleep',
      icon: Icons.dark_mode_outlined,
      accent: Color(0xFF39496B),
      audioUrl: _Snd.nightCrickets,
    ),
    MeditationSession(
      title: 'Campfire',
      subtitle: 'Crackle and warmth',
      minutes: 40,
      category: 'Sleep',
      icon: Icons.local_fire_department_outlined,
      accent: Color(0xFF9C5A3C),
      audioUrl: _Snd.campfire,
    ),
    MeditationSession(
      title: 'Ocean at Dusk',
      subtitle: 'Slow water against the shore',
      minutes: 45,
      category: 'Sleep',
      icon: Icons.sailing_outlined,
      accent: Color(0xFF2D6E8E),
      audioUrl: _Snd.oceanLap,
    ),
  ]),

  // ── Music ───────────────────────────────────────────────────────────────
  MeditationGroup('Ambient', MeditationTab.music, [
    MeditationSession(
      title: 'Rain on Canvas',
      subtitle: 'Soft rainfall for rest',
      minutes: 30,
      category: 'Music',
      icon: Icons.grain_rounded,
      accent: Color(0xFF3E5C76),
      audioUrl: _Snd.rainLight,
    ),
    MeditationSession(
      title: 'Forest Air',
      subtitle: 'Birdsong and moving leaves',
      minutes: 30,
      category: 'Music',
      icon: Icons.park_outlined,
      accent: Color(0xFF2E7D5B),
      audioUrl: _Snd.forestDay,
    ),
    MeditationSession(
      title: 'Riverbank',
      subtitle: 'Water moving over stone',
      minutes: 30,
      category: 'Music',
      icon: Icons.water_rounded,
      accent: Color(0xFF2D6E8E),
      audioUrl: _Snd.river,
    ),
    MeditationSession(
      title: 'Embers',
      subtitle: 'A slow-burning fire',
      minutes: 30,
      category: 'Music',
      icon: Icons.fireplace_outlined,
      accent: Color(0xFF9C5A3C),
      audioUrl: _Snd.bonfire,
    ),
  ]),
];
