import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mindfulness_content.dart';
import 'breathing_session_screen.dart';
import 'mindfulness_kit.dart';

/// "Choose a breathing exercise to practise." — the pattern picker.
class BreathingExercisesScreen extends StatelessWidget {
  const BreathingExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/mindfulness'),
        ),
        title: const Text('Breathing exercises',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              'Choose a breathing exercise to practise',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
              children: [
                for (var i = 0; i < kBreathingPatterns.length; i++)
                  _PatternCard(
                    pattern: kBreathingPatterns[i],
                    index: i,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BreathingSessionScreen(
                            pattern: kBreathingPatterns[i]),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            MindCard(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.info_outline_rounded,
                        color: AppColors.secondary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'A longer exhale calms you; an equal rhythm sharpens '
                      'focus. Pick what the moment needs.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard(
      {required this.pattern, required this.index, required this.onTap});

  final BreathingPattern pattern;
  final int index;
  final VoidCallback onTap;

  static const _tints = [
    Color(0xFF8E7CC3),
    Color(0xFF6C6BB0),
    Color(0xFF5C7CB0),
    Color(0xFF37675B),
  ];

  @override
  Widget build(BuildContext context) {
    final tint = _tints[index % _tints.length];
    return Material(
      color: tint.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pattern.name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 4),
              Text(pattern.ratio,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tint)),
              const SizedBox(height: 2),
              Text(pattern.tag,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.play_circle_fill_rounded,
                      size: 18, color: AppColors.primaryContainer),
                  const SizedBox(width: 4),
                  Text('${pattern.defaultMinutes} min',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
