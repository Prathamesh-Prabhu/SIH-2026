import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 5-4-3-2-1 sensory grounding protocol.
/// Ported from mindspace's `GroundingExercise.tsx`.
class GroundingExercise extends StatefulWidget {
  const GroundingExercise({super.key, this.onCompleted});
  final VoidCallback? onCompleted;

  @override
  State<GroundingExercise> createState() => _GroundingExerciseState();
}

class _GStep {
  final int number;
  final String sense;
  final String title;
  final IconData icon;
  final Color accentBg;
  final Color accentFg;
  final String instruction;
  final String prompt;
  final List<String> examples;
  const _GStep(this.number, this.sense, this.title, this.icon, this.accentBg,
      this.accentFg, this.instruction, this.prompt, this.examples);
}

const _steps = <_GStep>[
  _GStep(
    5,
    'Sight',
    '5 Things You Can SEE',
    Icons.visibility_outlined,
    Color(0xFFE6F3F1),
    Color(0xFF2C8C82),
    'Look around you right now. Spot 5 specific items in your environment.',
    'Name 5 things you can visually see (e.g., a shadow, a pen, light reflection, a plant, a coffee mug).',
    ['Desk lamp', 'Plant on shelf', 'Sunlight on floor', 'A blue book', 'Window frame'],
  ),
  _GStep(
    4,
    'Touch',
    '4 Things You Can FEEL / TOUCH',
    Icons.back_hand_outlined,
    Color(0xFFE8F0EA),
    Color(0xFF2D6A4F),
    'Pay attention to physical contact and textures against your body.',
    'Feel 4 physical sensations (e.g., feet on the floor, texture of your sleeve, back against the chair, cool air on hands).',
    ['Feet firm on floor', 'Fabric of shirt', 'Smooth desk surface', 'Cool air on skin'],
  ),
  _GStep(
    3,
    'Hearing',
    '3 Things You Can HEAR',
    Icons.volume_up_outlined,
    Color(0xFFE7EFFA),
    Color(0xFF3B6FA6),
    'Listen carefully beyond immediate room sounds.',
    'Identify 3 sounds in your space (e.g., air conditioning hum, distant traffic, your own steady breath, clock tick).',
    ['Hum of laptop fan', 'Distant birds or street', 'Sound of breathing'],
  ),
  _GStep(
    2,
    'Smell',
    '2 Things You Can SMELL',
    Icons.local_florist_outlined,
    Color(0xFFF1EAFB),
    Color(0xFF7C5FA6),
    'Take a gentle breath in through your nose.',
    'Notice 2 scents around you (e.g., fresh air, coffee, hand lotion, linen). If you smell nothing, imagine your favorite calming scent.',
    ['A cup of tea or coffee', 'Fresh air / gentle lotion'],
  ),
  _GStep(
    1,
    'Taste / Gratitude',
    '1 Thing You Can TASTE or FEEL GRATEFUL FOR',
    Icons.favorite_border,
    Color(0xFFFBEAF0),
    Color(0xFFB5507B),
    'Notice the lingering taste in your mouth, or anchor yourself in one genuine positive truth.',
    'Acknowledge 1 comforting taste (water, mint) or tell yourself: "I am safe in this present moment."',
    ['Sip of cool water', '"I am safe and this feeling will pass"'],
  ),
];

class _GroundingExerciseState extends State<GroundingExercise> {
  int _index = 0;
  final Set<int> _done = {};
  final Map<int, String> _notes = {};
  final _controller = TextEditingController();

  bool get _isComplete => _done.length == _steps.length;
  _GStep get _step => _steps[_index];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadNoteFor(int i) {
    _controller.text = _notes[_steps[i].number] ?? '';
  }

  void _completeStep() {
    setState(() {
      _notes[_step.number] = _controller.text;
      _done.add(_step.number);
      if (_index < _steps.length - 1) {
        _index++;
        _loadNoteFor(_index);
      } else if (_isComplete) {
        widget.onCompleted?.call();
      }
    });
  }

  void _goTo(int i) {
    setState(() {
      _notes[_step.number] = _controller.text;
      _index = i;
      _loadNoteFor(i);
    });
  }

  void _reset() {
    setState(() {
      _index = 0;
      _done.clear();
      _notes.clear();
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Intro
        Container(
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
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0EA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('5-4-3-2-1',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Sensory Grounding Protocol',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                  Text('${_done.length} of 5',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "When panic or acute anxiety strikes, your brain's alarm center takes over. This clinically proven technique shifts blood flow back into your sensory cortex, bringing immediate stabilization.",
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Progress row
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              Expanded(child: _progressChip(i)),
              if (i != _steps.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),

        if (!_isComplete)
          _activeStepCard()
        else
          _completeCard(),
      ],
    );
  }

  Widget _progressChip(int i) {
    final step = _steps[i];
    final isDone = _done.contains(step.number);
    final isCurrent = _index == i;
    return InkWell(
      onTap: () => _goTo(i),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFFFAF7F2)
              : isDone
                  ? const Color(0xFFF4F8F5)
                  : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? AppColors.primary
                : isDone
                    ? const Color(0xFFC5DBC8)
                    : AppColors.hairline,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.primaryContainer
                    : isCurrent
                        ? AppColors.primary
                        : const Color(0xFFF3EFE8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text('${step.number}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? Colors.white
                                : AppColors.onSurfaceVariant)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeStepCard() {
    final step = _step;
    return Container(
      padding: const EdgeInsets.all(20),
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: step.accentBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(step.icon, color: step.accentFg, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP ${5 - _index} OF 5',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: AppColors.secondary)),
                    Text(step.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(step.instruction,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                  height: 1.5)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.prompt,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ex in step.examples)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Text(ex,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondary)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText:
                  'Type your anchors here (optional, helps deepen focus)…',
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed:
                    _index == 0 ? null : () => _goTo(_index - 1),
                child: const Text('Previous Anchor'),
              ),
              ElevatedButton.icon(
                onPressed: _completeStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(_index == _steps.length - 1
                    ? 'Finish Grounding'
                    : 'Done & Next Anchor'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _completeCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC5DBC8)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('You are here. You are safe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          const SizedBox(height: 8),
          const Text(
            "Take one slow, deep breath in and let your shoulders drop. You've grounded your five senses in this exact physical reality. The surge is settling down.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _reset,
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Repeat Grounding'),
          ),
        ],
      ),
    );
  }
}
