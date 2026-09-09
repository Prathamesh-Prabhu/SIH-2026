import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../services/db_service.dart';
import '../self_help/doodle_canvas.dart';

/// Zen doodling as a standalone Mindfulness activity — a full-screen drawing
/// surface (no page scroll, so strokes can't be mistaken for scrolling). Time
/// on the canvas is written to `mindfulness_logs` (activity_type 'doodle')
/// when the drawing is saved.
class DoodleActivityScreen extends StatefulWidget {
  const DoodleActivityScreen({super.key});

  @override
  State<DoodleActivityScreen> createState() => _DoodleActivityScreenState();
}

class _DoodleActivityScreenState extends State<DoodleActivityScreen> {
  final _startedAt = DateTime.now();
  bool _logged = false;

  void _onSaved() {
    if (_logged) return;
    _logged = true;
    final secs = DateTime.now().difference(_startedAt).inSeconds.clamp(30, 3600);
    context.read<DbService>().recordDoodleSession(durationSeconds: secs);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Doodle saved to your mindfulness history.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.backOr('/mindfulness'),
        ),
        title: const Text('Zen Doodling',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: DoodleCanvas(fullscreen: true, onSaved: _onSaved),
      ),
    );
  }
}
