import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mindfulness_content.dart';
import '../../services/db_service.dart';
import 'mindfulness_kit.dart';

/// The Samsung-style mood check-in: pick a face, add contributing factors and
/// an optional note, then it is saved to `mindfulness_moods`.
class MoodCheckInFlowScreen extends StatefulWidget {
  const MoodCheckInFlowScreen({super.key});

  @override
  State<MoodCheckInFlowScreen> createState() => _MoodCheckInFlowScreenState();
}

class _MoodCheckInFlowScreenState extends State<MoodCheckInFlowScreen> {
  int _step = 0; // 0 = face, 1 = factors/note, 2 = done
  int? _level;
  final Set<String> _factors = {};
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  MoodLevel get _selected => moodLevelFor(_level ?? 3);

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<DbService>().recordMindfulnessMood(
          level: _selected.level,
          label: _selected.label,
          factors: _factors.toList(),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _step = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              context.backOr('/mindfulness');
            }
          },
        ),
        title: const Text('Mood check-in',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: switch (_step) {
          0 => _faceStep(),
          1 => _detailStep(),
          _ => _doneStep(),
        },
      ),
    );
  }

  // ── Step 0 — face ───────────────────────────────────────────────────────
  Widget _faceStep() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Text(
                'How do you feel right now?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'This is private. It helps you see how daily life affects '
                'your mood over time.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              for (final m in kMoodLevels) ...[
                _FaceOption(
                  mood: m,
                  selected: _level == m.level,
                  onTap: () => setState(() => _level = m.level),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        _bottomBar(
          MindButton(
            label: 'Next',
            expand: true,
            icon: Icons.arrow_forward_rounded,
            onTap: _level == null ? null : () => setState(() => _step = 1),
          ),
        ),
      ],
    );
  }

  // ── Step 1 — factors + note ────────────────────────────────────────────
  Widget _detailStep() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Row(
                children: [
                  Icon(_selected.icon, color: _selected.color, size: 34),
                  const SizedBox(width: 10),
                  Text(_selected.label,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 20),
              const Text("What's affecting your mood?",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in kMoodFactors)
                    FilterChip(
                      label: Text(f),
                      selected: _factors.contains(f),
                      showCheckmark: false,
                      selectedColor:
                          AppColors.secondaryContainer.withValues(alpha: 0.6),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _factors.add(f);
                        } else {
                          _factors.remove(f);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Add a note (optional)',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Anything you want to remember about today…',
                ),
              ),
            ],
          ),
        ),
        _bottomBar(
          MindButton(
            label: _saving ? 'Saving…' : 'Save check-in',
            expand: true,
            icon: Icons.check_rounded,
            onTap: _saving ? null : _save,
          ),
        ),
      ],
    );
  }

  // ── Step 2 — done ──────────────────────────────────────────────────────
  Widget _doneStep() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_selected.icon, color: _selected.color, size: 64),
                  const SizedBox(height: 16),
                  const Text('Thanks for checking in',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const SizedBox(height: 8),
                  const Text(
                    'Keep checking in to see how factors in your daily life '
                    'affect your mood.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  _WeekStrip(mood: _selected),
                ],
              ),
            ),
          ),
        ),
        _bottomBar(
          MindButton(
            label: 'Done',
            expand: true,
            onTap: () => context.backOr('/mindfulness'),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar(Widget child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: child,
    );
  }
}

/// The Samsung-style S M T W T F S strip on the confirmation screen — today
/// carries the face just logged, the other days are muted dots.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.mood});

  final MoodLevel mood;

  @override
  Widget build(BuildContext context) {
    const letters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final todayIdx = DateTime.now().weekday % 7; // Sun=0 … Sat=6

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < 7; i++)
              SizedBox(
                width: 34,
                child: Text(
                  letters[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: i == todayIdx
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < 7; i++)
              SizedBox(
                width: 34,
                child: Center(
                  child: i == todayIdx
                      ? Icon(mood.icon, color: mood.color, size: 26)
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FaceOption extends StatelessWidget {
  const _FaceOption(
      {required this.mood, required this.selected, required this.onTap});

  final MoodLevel mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.secondaryContainer.withValues(alpha: 0.4)
          : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.hairline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(mood.icon, color: mood.color, size: 30),
              const SizedBox(width: 14),
              Text(mood.label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const Spacer(),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
