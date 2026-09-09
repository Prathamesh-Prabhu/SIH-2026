import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mindfulness_content.dart';
import '../../services/db_service.dart';
import 'mindfulness_kit.dart';

/// Meditation library — Meditate / Sleep stories / Music tabs, each a set of
/// grouped session cards. Completing a session writes to `mindfulness_logs`.
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  MeditationTab _tab = MeditationTab.meditate;

  @override
  Widget build(BuildContext context) {
    final groups =
        kMeditationGroups.where((g) => g.tab == _tab).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/mindfulness'),
        ),
        title: const Text('Meditation',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final t in MeditationTab.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t.label),
                        selected: _tab == t,
                        onSelected: (_) => setState(() => _tab = t),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  for (final g in groups) ...[
                    MindSectionTitle(g.title),
                    const SizedBox(height: 10),
                    for (final s in g.sessions) ...[
                      _SessionCard(
                        session: s,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MeditationPlayerScreen(session: s),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final MeditationSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MindCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.secondary, AppColors.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.self_improvement_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(session.subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('${session.minutes} min · ${session.category}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary)),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill_rounded,
              color: AppColors.primaryContainer, size: 28),
        ],
      ),
    );
  }
}

/// Guided-timer player. There are no bundled audio tracks yet, so the session
/// runs as a calm countdown; the completion is what gets logged.
class MeditationPlayerScreen extends StatefulWidget {
  const MeditationPlayerScreen({super.key, required this.session});

  final MeditationSession session;

  @override
  State<MeditationPlayerScreen> createState() => _MeditationPlayerScreenState();
}

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen> {
  Timer? _timer;
  bool _running = false;
  bool _saved = false;
  int _elapsed = 0;

  int get _total => widget.session.minutes * 60;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed++);
      if (_elapsed >= _total) _finish(completed: true);
    });
  }

  Future<void> _finish({required bool completed}) async {
    _timer?.cancel();
    setState(() => _running = false);
    if (_saved || _elapsed < 5) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _saved = true;
    await context.read<DbService>().recordMeditationSession(
          title: widget.session.title,
          category: widget.session.category,
          plannedSeconds: _total,
          actualSeconds: _elapsed,
          completed: completed,
        );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session saved'),
        content: Text(
          'You meditated for ${_elapsed ~/ 60}m ${_elapsed % 60}s. '
          'It is now in your mindfulness history.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? 0.0 : (_elapsed / _total).clamp(0.0, 1.0);
    final remaining = _total - _elapsed;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _finish(completed: false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(widget.session.title,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(widget.session.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8))),
            const SizedBox(height: 40),
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.secondaryFixed),
                    ),
                  ),
                  Text(
                    '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
            const Spacer(),
            MindButton(
              label: _running ? 'Pause' : (_elapsed == 0 ? 'Begin' : 'Resume'),
              icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              onTap: _toggle,
            ),
            if (_elapsed > 0 && !_running) ...[
              const SizedBox(height: 10),
              MindButton(
                label: 'Finish & save',
                filled: false,
                onTap: () => _finish(completed: false),
              ),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
