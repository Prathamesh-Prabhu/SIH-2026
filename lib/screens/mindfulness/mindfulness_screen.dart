import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mindfulness_content.dart';
import '../../services/db_service.dart';
import 'mindfulness_kit.dart';

/// Mindfulness hub — the Samsung-Health-style landing for the section:
/// activities (mood check-in, breathing, meditation), the AI coach entry
/// point, and a 7-day "mood & lifestyle" review. Every activity persists to
/// Supabase through [DbService].
class MindfulnessScreen extends StatefulWidget {
  const MindfulnessScreen({super.key});

  @override
  State<MindfulnessScreen> createState() => _MindfulnessScreenState();
}

class _MindfulnessScreenState extends State<MindfulnessScreen> {
  @override
  void initState() {
    super.initState();
    // Pull any server-side history so the review card is populated on a cold
    // start. Safe no-op in mock/demo mode.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DbService>().refreshMindfulness(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DbService>();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final recentMoods = db.mindfulnessMoods.where((m) {
      final ts = DateTime.tryParse(m['created_at'] as String? ?? '');
      return ts != null && ts.isAfter(weekAgo);
    }).toList();

    final recentSessions = db.mindfulnessLogs.where((l) {
      final ts = DateTime.tryParse(l['created_at'] as String? ?? '');
      return ts != null && ts.isAfter(weekAgo);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/home'),
        ),
        title: const Text('Mindfulness',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => context.push('/mindfulness/history'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              'Mindful ways to boost your well-being',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Practise habits that help you reduce stress, rest better and '
              'steady your emotions between duties.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 20),

            const MindSectionTitle('Activities'),
            const SizedBox(height: 10),
            MindCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ActivityRow(
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    tint: const Color(0xFFE8894B),
                    title: 'Mood check-in',
                    subtitle: 'How do you feel right now?',
                    trailing: recentMoods.isEmpty
                        ? null
                        : '${recentMoods.length} this week',
                    onTap: () => context.push('/mindfulness/mood'),
                  ),
                  const Divider(height: 1, indent: 64),
                  _ActivityRow(
                    icon: Icons.air_rounded,
                    tint: const Color(0xFF7C6FD6),
                    title: 'Breathing exercises',
                    subtitle: 'Take a slow, deliberate breath',
                    trailing: _countLabel(recentSessions, 'breathing'),
                    onTap: () => context.push('/mindfulness/breathing'),
                  ),
                  const Divider(height: 1, indent: 64),
                  _ActivityRow(
                    icon: Icons.self_improvement_rounded,
                    tint: AppColors.secondary,
                    title: 'Meditation',
                    subtitle: 'Find your focus',
                    trailing: _countLabel(recentSessions, 'meditation'),
                    onTap: () => context.push('/mindfulness/meditation'),
                  ),
                  const Divider(height: 1, indent: 64),
                  _ActivityRow(
                    icon: Icons.gesture_rounded,
                    tint: const Color(0xFFC86D51),
                    title: 'Zen Doodling',
                    subtitle: 'Draw freely to settle the mind',
                    trailing: _countLabel(recentSessions, 'doodle'),
                    onTap: () => context.push('/mindfulness/doodle'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _AiCoachCard(onTap: () => context.push('/tara')),
            const SizedBox(height: 16),

            const MindSectionTitle('Mood and lifestyle'),
            const SizedBox(height: 10),
            _MoodLifestyleCard(
              moods: recentMoods,
              sessions: recentSessions,
              onOpenHistory: () => context.push('/mindfulness/history'),
            ),
            const SizedBox(height: 16),

            MindCard(
              onTap: () => context.push('/mindfulness/history'),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.insights_rounded,
                        color: AppColors.primaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your recap',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                        SizedBox(height: 2),
                        Text('See your most common moods and sessions over time',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.secondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _countLabel(List<Map<String, dynamic>> sessions, String type) {
    final n = sessions.where((s) => s['activity_type'] == type).length;
    return n == 0 ? null : '$n this week';
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary)),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

class _AiCoachCard extends StatelessWidget {
  const _AiCoachCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryContainer, AppColors.secondary],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.graphic_eq_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Talk to Tara',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    SizedBox(height: 3),
                    Text(
                      'Your calm voice companion: just talk out loud about '
                      'your day, your duty, or whatever\'s on your mind.',

                      style: TextStyle(
                          fontSize: 11.5, color: Colors.white, height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodLifestyleCard extends StatelessWidget {
  const _MoodLifestyleCard({
    required this.moods,
    required this.sessions,
    required this.onOpenHistory,
  });

  final List<Map<String, dynamic>> moods;
  final List<Map<String, dynamic>> sessions;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final total = moods.length;
    final counts = <int, int>{for (var l = 1; l <= 5; l++) l: 0};
    for (final m in moods) {
      final lvl = (m['mood_level'] as num?)?.toInt() ?? 3;
      counts[lvl] = (counts[lvl] ?? 0) + 1;
    }

    final minutes = sessions.fold<int>(
        0, (a, s) => a + (((s['actual_seconds'] as num?)?.toInt() ?? 0) ~/ 60));

    return MindCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 7 days',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (total == 0)
            const Text(
              'No mood check-ins yet this week. Tap “Mood check-in” above to '
              'log how you feel.',
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4),
            )
          else
            Row(
              children: [
                for (final level in kMoodLevels)
                  Expanded(
                    child: Column(
                      children: [
                        Icon(level.icon, color: level.color, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          '${total == 0 ? 0 : ((counts[level.level] ?? 0) / total * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Check-ins',
                  value: '$total',
                  icon: Icons.favorite_border_rounded,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Mindful minutes',
                  value: '$minutes',
                  icon: Icons.timer_outlined,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Sessions',
                  value: '${sessions.length}',
                  icon: Icons.spa_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: MindButton(
              label: 'View full history',
              icon: Icons.arrow_forward_rounded,
              filled: false,
              onTap: onOpenHistory,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10, color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}
