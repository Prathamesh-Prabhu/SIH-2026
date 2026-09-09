import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mindfulness_content.dart';
import '../../services/db_service.dart';
import 'mindfulness_kit.dart';

/// Guided paced-breathing session with an animated orb. On finish (or an
/// early stop after at least one full cycle) the session is written to
/// `mindfulness_logs`.
class BreathingSessionScreen extends StatefulWidget {
  const BreathingSessionScreen({super.key, required this.pattern});

  final BreathingPattern pattern;

  @override
  State<BreathingSessionScreen> createState() => _BreathingSessionScreenState();
}

class _BreathingSessionScreenState extends State<BreathingSessionScreen> {
  late List<BreathPhase> _phases;
  int _minutes = 5;

  Timer? _timer;
  bool _running = false;
  bool _saved = false;

  int _phaseIndex = 0;
  int _phaseRemaining = 0;
  int _elapsed = 0; // whole seconds since start
  int _cycles = 0;

  @override
  void initState() {
    super.initState();
    _phases = List.of(widget.pattern.phases);
    _minutes = widget.pattern.defaultMinutes;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _totalSeconds => _minutes * 60;
  BreathPhase get _phase => _phases[_phaseIndex];

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_elapsed == 0) {
      _phaseIndex = 0;
      _phaseRemaining = _phases[0].seconds;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    setState(() {
      _elapsed++;
      _phaseRemaining--;
      if (_phaseRemaining <= 0) {
        _phaseIndex = (_phaseIndex + 1) % _phases.length;
        _phaseRemaining = _phases[_phaseIndex].seconds;
        if (_phaseIndex == 0) _cycles++;
      }
    });
    if (_elapsed >= _totalSeconds) _finish(completed: true);
  }

  Future<void> _finish({required bool completed}) async {
    _timer?.cancel();
    setState(() => _running = false);
    if (_saved || _elapsed < 5) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _saved = true;
    await context.read<DbService>().recordBreathingSession(
          title: widget.pattern.name,
          pattern: _phases.map((p) => p.seconds).join('-'),
          category: widget.pattern.tag,
          plannedSeconds: _totalSeconds,
          actualSeconds: _elapsed,
          cyclesCompleted: _cycles,
          completed: completed,
        );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session saved'),
        content: Text(
          'You breathed for ${_fmt(_elapsed)} across $_cycles '
          '${_cycles == 1 ? 'cycle' : 'cycles'}. It is now in your '
          'mindfulness history.',
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

  String _fmt(int s) => '${s ~/ 60}m ${s % 60}s';

  @override
  Widget build(BuildContext context) {
    final orb = _running
        ? (_phase.label.startsWith('Breathe in') ? 220.0 : 130.0)
        : 170.0;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _finish(completed: false),
        ),
        title: Text(widget.pattern.name,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            if (!_running && _elapsed == 0) _setup() else _liveHeader(),
            Expanded(
              child: Center(
                child: AnimatedContainer(
                  duration: Duration(seconds: _running ? _phase.seconds : 1),
                  curve: Curves.easeInOut,
                  width: orb,
                  height: orb,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [
                      AppColors.secondaryFixed,
                      AppColors.secondary,
                    ]),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _running ? _phase.label : 'Ready',
                          style: const TextStyle(
                              fontSize: 13,
                              letterSpacing: 1.2,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                        if (_running) ...[
                          const SizedBox(height: 4),
                          Text('$_phaseRemaining',
                              style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_elapsed > 0)
                    Text(
                      '${_fmt(_elapsed)} of $_minutes min  ·  $_cycles cycles',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12),
                    ),
                  const SizedBox(height: 12),
                  MindButton(
                    label: _running
                        ? 'Pause'
                        : (_elapsed == 0 ? 'Start' : 'Resume'),
                    icon: _running
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    filled: true,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          widget.pattern.blurb,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.4),
        ),
      );

  Widget _setup() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            widget.pattern.blurb,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
                height: 1.4),
          ),
          const SizedBox(height: 16),
          _durationRow(),
          if (widget.pattern.customisable) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < _phases.length; i++) _phaseStepper(i),
          ],
        ],
      ),
    );
  }

  Widget _durationRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Duration',
            style: TextStyle(color: Colors.white, fontSize: 13)),
        const SizedBox(width: 16),
        for (final m in const [2, 5, 10])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$m min'),
              selected: _minutes == m,
              onSelected: (_) => setState(() => _minutes = m),
            ),
          ),
      ],
    );
  }

  Widget _phaseStepper(int i) {
    final p = _phases[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(p.label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
            onPressed: p.seconds <= 1
                ? null
                : () => setState(
                    () => _phases[i] = BreathPhase(p.label, p.seconds - 1)),
          ),
          Text('${p.seconds}s',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: p.seconds >= 12
                ? null
                : () => setState(
                    () => _phases[i] = BreathPhase(p.label, p.seconds + 1)),
          ),
        ],
      ),
    );
  }
}
