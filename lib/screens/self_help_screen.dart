import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../services/db_service.dart';
import 'self_help/ambient_sound_player.dart';
import 'self_help/breathing_calmer.dart';
import 'self_help/doodle_canvas.dart';
import 'self_help/feeling_recommender.dart';
import 'self_help/grounding_exercise.dart';
import 'self_help/worry_dissolver.dart';

/// Self-Help Hub — feeling check-in + interactive regulation tools.
/// Structure & tools ported from mindspace's `SelfHelpPage`.
class SelfHelpScreen extends StatefulWidget {
  const SelfHelpScreen({super.key});

  @override
  State<SelfHelpScreen> createState() => _SelfHelpScreenState();
}

class _SelfHelpScreenState extends State<SelfHelpScreen> {
  final _db = DbService();
  final _controller = TextEditingController();

  FeelingSuggestion? _suggestion;
  bool _analyzing = false;
  bool _toolDismissed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  RecommendedTool? get _recommendedTool =>
      (!_toolDismissed && _suggestion?.tool != null &&
              _suggestion!.tool != RecommendedTool.doodle)
          ? _suggestion!.tool
          : null;

  int? get _recommendedDoodleId => _suggestion?.doodleId;

  Future<void> _analyze([String? preset]) async {
    final query = (preset ?? _controller.text).trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _analyzing = true);
    // Local heuristic — kept async so swapping in the LLM later is a drop-in.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _suggestion = analyzeFeeling(query);
      _toolDismissed = false;
      _analyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tool = _recommendedTool;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/home'),
        ),
        title: const Text('Self-Help Hub',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _feelingCheckIn(),
              const SizedBox(height: 24),

              if (tool != null) ...[
                _sectionHeader(
                  'Recommended for you: ${toolLabel(tool)}',
                  onDismiss: () => setState(() => _toolDismissed = true),
                ),
                const SizedBox(height: 12),
                _toolFor(tool),
                const SizedBox(height: 24),
              ],

              Text(tool != null ? 'Zen Doodling' : 'Zen Doodling',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(height: 12),
              DoodleCanvas(
                initialDoodleId: _recommendedDoodleId,
                onSaved: () => _db.recordSelfHelpActivity('doodle', 180),
              ),
              const SizedBox(height: 24),

              _crisisStrip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolFor(RecommendedTool tool) {
    switch (tool) {
      case RecommendedTool.grounding:
        return GroundingExercise(
          onCompleted: () => _db.recordSelfHelpActivity('grounding', 240),
        );
      case RecommendedTool.breathing:
        return BreathingCalmer(
          onCycleCompleted: (c) {
            if (c == 3) _db.recordSelfHelpActivity('breathing', 90);
          },
        );
      case RecommendedTool.dissolve:
        return WorryDissolver(
          onReleased: () => _db.recordSelfHelpActivity('grounding', 120),
        );
      case RecommendedTool.sounds:
        return AmbientSoundPlayer(
          onPlay: (_) => _db.recordSelfHelpActivity('soundscape', 180),
        );
      case RecommendedTool.doodle:
        return const SizedBox.shrink();
    }
  }

  Widget _feelingCheckIn() {
    final s = _suggestion;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('How are you feeling right now?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0EA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Private',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Type what you're experiencing. We'll suggest a matching tool and a short activity.",
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in kQuickFeelings)
                ActionChip(
                  label: Text(q.label, style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFFFAF7F2),
                  side: const BorderSide(color: AppColors.hairline),
                  onPressed: _analyzing
                      ? null
                      : () {
                          _controller.text = q.query;
                          _analyze(q.query);
                        },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText:
                  "Describe what's on your mind or how your body feels…",
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _analyzing ? null : () => _analyze(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _analyzing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.explore_outlined, size: 16),
              label: Text(_analyzing
                  ? 'Analysing…'
                  : 'Get Activities & Guidance'),
            ),
          ),
          if (s != null && !_analyzing) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD5E5D8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GUIDANCE NOTE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppColors.secondary)),
                        const SizedBox(height: 2),
                        Text(s.empathyNote,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (s.activity != null) ...[
              const SizedBox(height: 12),
              _activityCard(s.activity!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _activityCard(TailoredActivity a) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('Recommended Activity: ${a.title}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0EA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(a.duration,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(a.description,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ACTION STEPS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                for (var i = 0; i < a.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(a.steps[i],
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onDismiss}) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
        if (onDismiss != null)
          TextButton.icon(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 14),
            label: const Text('Dismiss'),
          ),
      ],
    );
  }

  Widget _crisisStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 18, color: AppColors.secondary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Need live human support? Tele-MANAS 14416 is confidential and available 24/7.',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/companion'),
            child: const Text('AI Companion'),
          ),
        ],
      ),
    );
  }
}
