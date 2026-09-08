import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../services/db_service.dart';
import '../widgets/quick_screen_switcher.dart';

class SelfHelpScreen extends StatefulWidget {
  const SelfHelpScreen({super.key});

  @override
  State<SelfHelpScreen> createState() => _SelfHelpScreenState();
}

class _SelfHelpScreenState extends State<SelfHelpScreen> with SingleTickerProviderStateMixin {
  final _db = DbService();

  // Box Breathing State (4-4-4-4)
  bool _breathingActive = false;
  int _secondsLeft = 4;
  String _breathPhase = 'Inhale';
  Timer? _breathTimer;
  int _cycleCount = 0;

  // Doodle state
  final List<Offset?> _points = [];
  Color _selectedColor = AppColors.primary;

  @override
  void dispose() {
    _breathTimer?.cancel();
    super.dispose();
  }

  void _startBreathing() {
    setState(() {
      _breathingActive = true;
      _secondsLeft = 4;
      _breathPhase = 'Inhale (4s)';
      _cycleCount = 0;
    });

    _breathTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _secondsLeft = 4;
          if (_breathPhase.startsWith('Inhale')) {
            _breathPhase = 'Hold (4s)';
          } else if (_breathPhase.startsWith('Hold') && _cycleCount % 2 == 0) {
            _breathPhase = 'Exhale (4s)';
            _cycleCount++;
          } else if (_breathPhase.startsWith('Exhale')) {
            _breathPhase = 'Hold empty (4s)';
          } else {
            _breathPhase = 'Inhale (4s)';
            _cycleCount++;
            if (_cycleCount >= 4) {
              // Completed 2 full box cycles (32s)
              _breathingActive = false;
              timer.cancel();
              _db.recordSelfHelpActivity('breathing', 32);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Box breathing complete! Vagal regulation engaged.'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            }
          }
        }
      });
    });
  }

  void _stopBreathing() {
    _breathTimer?.cancel();
    setState(() {
      _breathingActive = false;
      _secondsLeft = 4;
      _breathPhase = 'Inhale';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: const QuickScreenSwitcher(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Self-Help Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.spa, size: 14, color: AppColors.onSecondaryContainer),
                SizedBox(width: 4),
                Text('Sanctuary', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Regulate & Reset',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Self-guided tactical restoration tools to defuse operational stress.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 18),

              // Tactical Box Breathing Interactive Tool
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.air, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Box Cadence (4-4-4-4)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                                Text('Heart rate deceleration', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Tactical Vagal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Breathing Visual Orb
                    AnimatedContainer(
                      duration: const Duration(seconds: 1),
                      width: _breathingActive ? (_breathPhase.startsWith('Inhale') ? 140 : (_breathPhase.startsWith('Exhale') ? 90 : 120)) : 110,
                      height: _breathingActive ? (_breathPhase.startsWith('Inhale') ? 140 : (_breathPhase.startsWith('Exhale') ? 90 : 120)) : 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _breathingActive ? AppColors.secondaryContainer : AppColors.surfaceContainerHigh,
                        border: Border.all(
                          color: _breathingActive ? AppColors.secondary : AppColors.outlineVariant,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _breathingActive ? '$_secondsLeft' : '4s',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            Text(
                              _breathPhase,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Button Start / Stop
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _breathingActive ? _stopBreathing : _startBreathing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _breathingActive ? AppColors.errorContainer : AppColors.primaryContainer,
                          foregroundColor: _breathingActive ? AppColors.error : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          _breathingActive ? 'Stop Exercise' : 'Start 4-4-4-4 Cadence',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Interactive Doodle Grounding Canvas
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.brush_outlined, color: AppColors.secondary, size: 20),
                            SizedBox(width: 8),
                            Text('Grounding Canvas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                          ],
                        ),
                        Row(
                          children: [
                            _colorDot(AppColors.primary),
                            _colorDot(AppColors.secondary),
                            _colorDot(AppColors.error),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18, color: AppColors.outline),
                              onPressed: () => setState(() => _points.clear()),
                              tooltip: 'Clear Canvas',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unstructured tactile doodling helps defuse situational cognitive tension.',
                      style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    // Canvas Area
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _points.add(details.localPosition);
                            });
                          },
                          onPanEnd: (details) => _points.add(null),
                          child: CustomPaint(
                            painter: _DoodlePainter(points: _points, color: _selectedColor),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Soundscapes List
              const Text('Restorative Ambient Soundscapes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
              const SizedBox(height: 10),
              _soundscapeItem('Rain in Pine Forest', '3 min • Low frequency alpha waves', Icons.forest_outlined),
              const SizedBox(height: 8),
              _soundscapeItem('High Altitude Wind', '5 min • White noise grounding', Icons.air_outlined),
              const SizedBox(height: 8),
              _soundscapeItem('Himalayan Stream', '4 min • Theta cadence deceleration', Icons.water_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 2),
        ),
      ),
    );
  }

  Widget _soundscapeItem(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: AppColors.secondary, size: 28),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Playing "$title" ambient track...')),
              );
              _db.recordSelfHelpActivity('soundscape', 180);
            },
          ),
        ],
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;
  _DoodlePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => true;
}
