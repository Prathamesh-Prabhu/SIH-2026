import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Paced-breathing tool — 3 selectable patterns with an animated orb.
/// Ported from mindspace's `BreathingCalmer.tsx`.
class BreathingCalmer extends StatefulWidget {
  const BreathingCalmer({super.key, this.onCycleCompleted});

  /// Fired once per completed full cycle (for activity logging).
  final void Function(int completedCycles)? onCycleCompleted;

  @override
  State<BreathingCalmer> createState() => _BreathingCalmerState();
}

class _BreathPhase {
  final String name;
  final int duration;
  const _BreathPhase(this.name, this.duration);
}

class _Pattern {
  final String key;
  final String name;
  final String tag;
  final String description;
  final List<_BreathPhase> phases;
  const _Pattern(this.key, this.name, this.tag, this.description, this.phases);
}

const _patterns = <_Pattern>[
  _Pattern(
    'box',
    '4-4-4-4 Box Breathing',
    'Navy SEAL Stress Reset',
    'Equal inhalation, hold, exhalation, and empty hold to rapidly stabilize the autonomic nervous system.',
    [
      _BreathPhase('Inhale', 4),
      _BreathPhase('Hold', 4),
      _BreathPhase('Exhale', 4),
      _BreathPhase('Hold Empty', 4),
    ],
  ),
  _Pattern(
    '478',
    '4-7-8 Deep Sleep & Anxiety Calmer',
    'Parasympathetic Activator',
    'Dr. Andrew Weil technique that acts as a natural tranquilizer for the nervous system.',
    [
      _BreathPhase('Inhale gently', 4),
      _BreathPhase('Hold breath', 7),
      _BreathPhase('Exhale completely', 8),
    ],
  ),
  _Pattern(
    'calm',
    '4-6 Extended Exhale',
    'Quick Heart Rate Reducer',
    'Longer exhalations signal safety to the vagus nerve, quickly slowing a racing pulse.',
    [
      _BreathPhase('Inhale', 4),
      _BreathPhase('Exhale slowly', 6),
    ],
  ),
];

class _BreathingCalmerState extends State<BreathingCalmer> {
  int _patternIndex = 0;
  bool _isActive = false;
  int _phaseIndex = 0;
  int _timeLeft = 4;
  int _completedCycles = 0;
  Timer? _timer;

  _Pattern get _pattern => _patterns[_patternIndex];
  _BreathPhase get _phase => _pattern.phases[_phaseIndex];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick(Timer _) {
    if (!mounted) return;
    setState(() {
      if (_timeLeft > 1) {
        _timeLeft--;
        return;
      }
      final next = (_phaseIndex + 1) % _pattern.phases.length;
      if (next == 0) {
        _completedCycles++;
        widget.onCycleCompleted?.call(_completedCycles);
      }
      _phaseIndex = next;
      _timeLeft = _pattern.phases[next].duration;
    });
  }

  void _toggle() {
    setState(() {
      if (_isActive) {
        _isActive = false;
        _timer?.cancel();
      } else {
        _isActive = true;
        _phaseIndex = 0;
        _timeLeft = _pattern.phases[0].duration;
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      }
    });
  }

  void _selectPattern(int i) {
    setState(() {
      _patternIndex = i;
      _isActive = false;
      _timer?.cancel();
      _phaseIndex = 0;
      _timeLeft = _patterns[i].phases[0].duration;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExpanding = _phase.name.toLowerCase().contains('inhale');
    final isHolding = _phase.name.toLowerCase().contains('hold');

    double orb = 150;
    Color orbColor = AppColors.surfaceContainerHigh;
    Color borderColor = AppColors.outlineVariant;
    Color textColor = AppColors.primary;
    if (_isActive && isExpanding) {
      orb = 200;
      orbColor = AppColors.primaryContainer;
      borderColor = AppColors.primary;
      textColor = Colors.white;
    } else if (_isActive && isHolding) {
      orb = 180;
      orbColor = const Color(0xFF59446B);
      borderColor = const Color(0xFF443353);
      textColor = Colors.white;
    } else if (_isActive) {
      orb = 120;
      orbColor = const Color(0xFF344B3B);
      borderColor = const Color(0xFF25372B);
      textColor = Colors.white;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pattern selector
        for (var i = 0; i < _patterns.length; i++) ...[
          _PatternTile(
            pattern: _patterns[i],
            selected: i == _patternIndex,
            onTap: () => _selectPattern(i),
          ),
          if (i != _patterns.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 20),

        // Breathing stage
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EFE8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeInOut,
                    width: orb,
                    height: orb,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: orbColor,
                      border: Border.all(color: borderColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isActive ? _phase.name : 'Paced Breath',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w500,
                                  color: textColor.withOpacity(0.85),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isActive ? '$_timeLeft' : 'Ready',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              if (_isActive)
                                Text(
                                  'seconds remaining',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textColor.withOpacity(0.75),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _pattern.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5),
              ),
              if (_completedCycles > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0EA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_completedCycles full ${_completedCycles == 1 ? 'cycle' : 'cycles'} completed',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _toggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isActive ? AppColors.primary : AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(_isActive ? Icons.pause : Icons.play_arrow, size: 18),
                label: Text(
                  _isActive ? 'Pause Breathing' : 'Start Paced Breathing',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PatternTile extends StatelessWidget {
  const _PatternTile(
      {required this.pattern, required this.selected, required this.onTap});
  final _Pattern pattern;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFAF7F2) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pattern.tag.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              pattern.name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
