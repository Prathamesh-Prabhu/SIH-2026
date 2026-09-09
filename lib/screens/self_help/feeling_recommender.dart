/// Local, offline stand-in for mindspace's `analyzeFeelingWithLLM`.
/// Keyword heuristics map a described feeling onto the best interactive tool
/// plus an empathetic note and a short tailored activity. The real LLM / Tara
/// voice agent will replace this later.
library;

enum RecommendedTool { grounding, breathing, dissolve, sounds, doodle }

class TailoredActivity {
  final String title;
  final String duration;
  final String description;
  final List<String> steps;
  const TailoredActivity(
      this.title, this.duration, this.description, this.steps);
}

class FeelingSuggestion {
  final String empathyNote;
  final RecommendedTool? tool;
  final int? doodleId;
  final TailoredActivity? activity;
  const FeelingSuggestion({
    required this.empathyNote,
    this.tool,
    this.doodleId,
    this.activity,
  });
}

class QuickFeeling {
  final String label;
  final String query;
  const QuickFeeling(this.label, this.query);
}

const kQuickFeelings = <QuickFeeling>[
  QuickFeeling('Panic & Fast Heartbeat',
      'I am having a panic attack, my heart is beating fast and I feel breathless.'),
  QuickFeeling('Severe Anxiety & Dread',
      'I feel intense anxiety and dread about my duties and deadlines.'),
  QuickFeeling('Low & Drained',
      'I feel sad, empty, unmotivated, and exhausted.'),
  QuickFeeling('Burnt Out & Overwhelmed',
      'I am overwhelmed by constant operational pressure and mental fatigue.'),
  QuickFeeling('Racing Thoughts & Insomnia',
      "My mind won't stop spinning and I cannot switch off to sleep."),
  QuickFeeling('Anger & Frustration',
      'I feel irritated, tense, and angry with everything around me.'),
];

const _toolLabels = {
  RecommendedTool.grounding: '5-4-3-2-1 Grounding',
  RecommendedTool.breathing: 'Paced Breathing',
  RecommendedTool.dissolve: 'Thought Dissolver',
  RecommendedTool.sounds: 'Ambient Soundscapes',
  RecommendedTool.doodle: 'Zen Doodling',
};

String toolLabel(RecommendedTool t) => _toolLabels[t]!;

bool _has(String text, List<String> words) =>
    words.any((w) => text.contains(w));

FeelingSuggestion analyzeFeeling(String raw) {
  final t = raw.toLowerCase();

  // Acute panic → grounding first.
  if (_has(t, [
    'panic',
    'heart is beating',
    'racing heart',
    'fast heartbeat',
    'breathless',
    "can't breathe",
    'cannot breathe',
    'hyperventilat',
    'dizzy',
    'shaking',
  ])) {
    return const FeelingSuggestion(
      empathyNote:
          'That surge is frightening, but it is your alarm system misfiring, not danger. Anchoring your senses in the room right now will bring your body back down.',
      tool: RecommendedTool.grounding,
      activity: TailoredActivity(
        'Palms & Feet Reset',
        '2 min',
        'A fast physical anchor for an adrenaline spike.',
        [
          'Press both feet flat and feel the floor take your weight.',
          'Push your palms together firmly for 5 seconds, then release.',
          'Name 3 things you can see and 1 sound you can hear, out loud.',
          'Slow the exhale (out longer than in) for six breaths.',
        ],
      ),
    );
  }

  // Anxiety / dread → paced breathing.
  if (_has(t, [
    'anxiety',
    'anxious',
    'dread',
    'nervous',
    'worried sick',
    'on edge',
    'tense',
    'deadline',
  ])) {
    return const FeelingSuggestion(
      empathyNote:
          'Anticipatory dread keeps the body braced for a threat that has not arrived. Lengthening the exhale tells your nervous system it is safe to stand down.',
      tool: RecommendedTool.breathing,
      activity: TailoredActivity(
        'Box Cadence Before the Task',
        '3 min',
        'Steady the pulse before facing whatever is looming.',
        [
          'Run the 4-4-4-4 box pattern for six full rounds.',
          'On each hold, drop your shoulders a little further.',
          'Name the single next physical action the task needs.',
          'Do only that one action.',
        ],
      ),
    );
  }

  // Rumination / insomnia → thought dissolver.
  if (_has(t, [
    'racing thought',
    "won't stop",
    'wont stop',
    'overthink',
    'ruminat',
    'spinning',
    'cannot switch off',
    "can't switch off",
    'insomnia',
    "can't sleep",
    'cannot sleep',
    'looping',
  ])) {
    return const FeelingSuggestion(
      empathyNote:
          'A looping thought feels urgent, but replaying it changes nothing. Getting it out of your head and letting it go breaks the loop.',
      tool: RecommendedTool.dissolve,
      doodleId: 3,
      activity: TailoredActivity(
        'Park the Thought',
        '4 min',
        'Externalise the loop so your mind can rest.',
        [
          'Write the exact worrying sentence down, word for word.',
          'Read it once, then release it in the Thought Dissolver.',
          'Tell yourself: "I can pick this up tomorrow if it still matters."',
          'Shift to slow tracing on the mandala doodle for two minutes.',
        ],
      ),
    );
  }

  // Anger / frustration → doodle + sounds.
  if (_has(t, [
    'anger',
    'angry',
    'irritat',
    'frustrat',
    'furious',
    'rage',
    'snapping',
  ])) {
    return const FeelingSuggestion(
      empathyNote:
          'Anger is energy with nowhere to go. Give it a physical outlet that does no harm, and let the charge burn down.',
      tool: RecommendedTool.doodle,
      doodleId: 16,
      activity: TailoredActivity(
        'Discharge & Cool',
        '5 min',
        'Move the heat out through your hands.',
        [
          'Pick the boldest colour and press hard on the canvas.',
          'Draw fast, loose strokes over the cresting-wave reference.',
          'As the page fills, deliberately slow each stroke down.',
          'Finish with four long exhales.',
        ],
      ),
    );
  }

  // Low mood / burnout / exhaustion → gentle doodle + sounds.
  if (_has(t, [
    'sad',
    'empty',
    'hopeless',
    'unmotivated',
    'exhausted',
    'burnt out',
    'burnout',
    'tired',
    'drained',
    'numb',
    'low',
    'overwhelm',
  ])) {
    return const FeelingSuggestion(
      empathyNote:
          'When everything feels heavy, the goal is not to fix the day, just to give your system one small, kind, low-effort moment.',
      tool: RecommendedTool.sounds,
      doodleId: 12,
      activity: TailoredActivity(
        'One Small Warm Thing',
        '5 min',
        'Lower the bar all the way down.',
        [
          'Start a soundscape and put it on low in the background.',
          'Trace the cozy-cabin doodle slowly, no need to finish it.',
          'Get a glass of water or a warm drink.',
          'That was enough. You showed up.',
        ],
      ),
    );
  }

  // Fallback.
  return const FeelingSuggestion(
    empathyNote:
        'Thank you for putting it into words. Try one of the tools below: a few slow minutes with any of them will shift how your body feels.',
    tool: RecommendedTool.breathing,
    doodleId: 1,
  );
}
