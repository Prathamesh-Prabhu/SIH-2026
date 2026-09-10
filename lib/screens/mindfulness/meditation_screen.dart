import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mindfulness_content.dart';
import '../../services/db_service.dart';
import 'mindfulness_kit.dart';

/// Meditation library — Meditate / Sleep / Music tabs, each a set of grouped
/// session cards. A session plays a looping soothing ambience for its length;
/// completing it writes to `mindfulness_logs`.
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  MeditationTab _tab = MeditationTab.meditate;

  @override
  Widget build(BuildContext context) {
    final groups = kMeditationGroups.where((g) => g.tab == _tab).toList();

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: _TabBar(
                current: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
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
                    const SizedBox(height: 14),
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

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onChanged});

  final MeditationTab current;
  final ValueChanged<MeditationTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final t in MeditationTab.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: current == t
                        ? AppColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: current == t
                          ? Colors.white
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: session.accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(session.icon, color: session.accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(session.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 5),
                Text('${session.minutes} min · ${session.category}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: session.accent)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.play_circle_fill_rounded, color: session.accent, size: 30),
        ],
      ),
    );
  }
}

/// Session player — a calm countdown over a looping ambience. The completion
/// is what gets logged (`recordMeditationSession`).
class MeditationPlayerScreen extends StatefulWidget {
  const MeditationPlayerScreen({super.key, required this.session});

  final MeditationSession session;

  @override
  State<MeditationPlayerScreen> createState() => _MeditationPlayerScreenState();
}

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen> {
  final _player = AudioPlayer();
  Timer? _timer;
  bool _running = false;
  bool _saved = false;
  bool _audioStarted = false;
  bool _audioError = false;
  int _elapsed = 0;

  int get _total => widget.session.minutes * 60;

  Source? get _audioSource {
    final s = widget.session;
    if (s.assetPath != null && s.assetPath!.isNotEmpty) {
      return AssetSource(s.assetPath!);
    }
    if (s.audioUrl != null && s.audioUrl!.isNotEmpty) {
      return UrlSource(s.audioUrl!);
    }
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startOrResumeAudio() async {
    final src = _audioSource;
    if (src == null) return;
    try {
      if (!_audioStarted) {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.setVolume(0.85);
        await _player.play(src);
        _audioStarted = true;
      } else {
        await _player.resume();
      }
    } catch (_) {
      if (mounted) setState(() => _audioError = true);
    }
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      _player.pause();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _startOrResumeAudio();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed++);
      if (_elapsed >= _total) _finish(completed: true);
    });
  }

  Future<void> _finish({required bool completed}) async {
    _timer?.cancel();
    final db = context.read<DbService>();
    await _player.stop();
    if (!mounted) return;
    setState(() => _running = false);
    if (_saved || _elapsed < 5) {
      Navigator.of(context).pop();
      return;
    }
    _saved = true;
    await db.recordMeditationSession(
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
          'You listened for ${_elapsed ~/ 60}m ${_elapsed % 60}s. '
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
    final accent = widget.session.accent;
    final progress = _total == 0 ? 0.0 : (_elapsed / _total).clamp(0.0, 1.0);
    final remaining = _total - _elapsed;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(accent.withOpacity(0.85), const Color(0xFF0A1A22)),
              const Color(0xFF06121A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => _finish(completed: false),
                ),
              ),
              const Spacer(),
              Text(widget.session.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(widget.session.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.75))),
              ),
              const SizedBox(height: 44),
              SizedBox(
                width: 236,
                height: 236,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 236,
                      height: 236,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _running
                              ? 'remaining'
                              : (_elapsed == 0 ? 'ready' : 'paused'),
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 18,
                child: Text(
                  _audioError
                      ? 'Sound unavailable — timer still runs'
                      : (_audioSource == null ? 'Silent session' : ''),
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
              const Spacer(),
              _CircleButton(
                icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: accent,
                onTap: _toggle,
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => _finish(completed: false),
                child: Text(
                  _elapsed > 0 ? 'End & save' : 'Close',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton(
      {required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Icon(icon, size: 34, color: color),
        ),
      ),
    );
  }
}
