import 'package:flutter/material.dart';

/// The profile badge system. Two layers:
///  * [StreakRank] — one rank that levels up purely with the wellbeing streak.
///    This is the motivational spine: "higher streak → higher badge".
///  * [MilestoneBadge] — a collectable grid earned by doing the work
///    (breathing, meditation, doodling, mood check-ins, reaching out to Tara).
///
/// Nothing here is stored server-side — it is derived live from the streak and
/// the user's own activity in [DbService].

// ── Streak ranks ──────────────────────────────────────────────────────────
class StreakRank {
  const StreakRank({
    required this.name,
    required this.minStreak,
    required this.icon,
    required this.color,
    required this.motto,
  });

  final String name;
  final int minStreak;
  final IconData icon;
  final Color color;
  final String motto;
}

const List<StreakRank> kStreakRanks = [
  StreakRank(
    name: 'Recruit',
    minStreak: 0,
    icon: Icons.shield_outlined,
    color: Color(0xFF8A9A93),
    motto: 'Every journey starts with day one.',
  ),
  StreakRank(
    name: 'Cadet',
    minStreak: 3,
    icon: Icons.military_tech_outlined,
    color: Color(0xFF6C8F7F),
    motto: 'Showing up is a skill, and you have it.',
  ),
  StreakRank(
    name: 'Trooper',
    minStreak: 7,
    icon: Icons.military_tech,
    color: Color(0xFF4F9CD6),
    motto: 'A full week of looking after yourself.',
  ),
  StreakRank(
    name: 'Sentinel',
    minStreak: 14,
    icon: Icons.workspace_premium_outlined,
    color: Color(0xFF37675B),
    motto: 'Two weeks steady. This is becoming a habit.',
  ),
  StreakRank(
    name: 'Vanguard',
    minStreak: 30,
    icon: Icons.workspace_premium,
    color: Color(0xFFE7B93C),
    motto: 'A month of discipline. This is who you are now.',
  ),
  StreakRank(
    name: 'Guardian',
    minStreak: 60,
    icon: Icons.stars_rounded,
    color: Color(0xFFE8894B),
    motto: 'Two months in. You could carry someone else through this.',
  ),
  StreakRank(
    name: 'Ironclad',
    minStreak: 100,
    icon: Icons.shield_moon_rounded,
    color: Color(0xFFD24B3B),
    motto: 'A hundred days. Unshakeable.',
  ),
];

StreakRank rankForStreak(int streak) {
  var current = kStreakRanks.first;
  for (final r in kStreakRanks) {
    if (streak >= r.minStreak) current = r;
  }
  return current;
}

StreakRank? nextRank(int streak) {
  for (final r in kStreakRanks) {
    if (r.minStreak > streak) return r;
  }
  return null;
}

// ── Milestone badges ──────────────────────────────────────────────────────
class BadgeStats {
  const BadgeStats({
    required this.streak,
    required this.breathingSessions,
    required this.meditationSessions,
    required this.doodles,
    required this.moodCheckIns,
    required this.mindfulMinutes,
    required this.taraSessions,
  });

  final int streak;
  final int breathingSessions;
  final int meditationSessions;
  final int doodles;
  final int moodCheckIns;
  final int mindfulMinutes;
  final int taraSessions;
}

class MilestoneBadge {
  const MilestoneBadge({
    required this.id,
    required this.name,
    required this.blurb,
    required this.icon,
    required this.color,
    required this.goal,
    required this.value,
  });

  final String id;
  final String name;
  final String blurb;
  final IconData icon;
  final Color color;
  final int goal;
  final int Function(BadgeStats) value;
}

const List<MilestoneBadge> kMilestoneBadges = [
  MilestoneBadge(
    id: 'week_warrior',
    name: 'Week Warrior',
    blurb: 'Hold a 7-day wellbeing streak.',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFE8894B),
    goal: 7,
    value: _streak,
  ),
  MilestoneBadge(
    id: 'month_strong',
    name: 'Month Strong',
    blurb: 'Hold a 30-day wellbeing streak.',
    icon: Icons.whatshot_rounded,
    color: Color(0xFFD24B3B),
    goal: 30,
    value: _streak,
  ),
  MilestoneBadge(
    id: 'steady_breather',
    name: 'Steady Breather',
    blurb: 'Complete 5 breathing sessions.',
    icon: Icons.air_rounded,
    color: Color(0xFF7C6FD6),
    goal: 5,
    value: _breathing,
  ),
  MilestoneBadge(
    id: 'still_mind',
    name: 'Still Mind',
    blurb: 'Complete 10 meditation sessions.',
    icon: Icons.self_improvement_rounded,
    color: Color(0xFF37675B),
    goal: 10,
    value: _meditation,
  ),
  MilestoneBadge(
    id: 'open_book',
    name: 'Open Book',
    blurb: 'Log 15 mood check-ins.',
    icon: Icons.favorite_rounded,
    color: Color(0xFF4CAF6E),
    goal: 15,
    value: _moods,
  ),
  MilestoneBadge(
    id: 'zen_hand',
    name: 'Zen Hand',
    blurb: 'Finish 3 Zen doodles.',
    icon: Icons.gesture_rounded,
    color: Color(0xFFC86D51),
    goal: 3,
    value: _doodles,
  ),
  MilestoneBadge(
    id: 'hour_of_calm',
    name: 'Hour of Calm',
    blurb: 'Bank 60 mindful minutes.',
    icon: Icons.timer_rounded,
    color: Color(0xFF4F9CD6),
    goal: 60,
    value: _minutes,
  ),
  MilestoneBadge(
    id: 'reached_out',
    name: 'Reached Out',
    blurb: 'Talk to Tara: asking for support is strength.',
    icon: Icons.graphic_eq_rounded,
    color: Color(0xFF9ED1C3),
    goal: 1,
    value: _tara,
  ),
];

int _streak(BadgeStats s) => s.streak;
int _breathing(BadgeStats s) => s.breathingSessions;
int _meditation(BadgeStats s) => s.meditationSessions;
int _moods(BadgeStats s) => s.moodCheckIns;
int _doodles(BadgeStats s) => s.doodles;
int _minutes(BadgeStats s) => s.mindfulMinutes;
int _tara(BadgeStats s) => s.taraSessions;

int earnedBadgeCount(BadgeStats s) =>
    kMilestoneBadges.where((b) => b.value(s) >= b.goal).length;
