import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Write a looping worry, then metaphorically let it dissolve.
/// Ported from mindspace's `WorryDissolver.tsx`. Nothing is ever stored.
class WorryDissolver extends StatefulWidget {
  const WorryDissolver({super.key, this.onReleased});
  final VoidCallback? onReleased;

  @override
  State<WorryDissolver> createState() => _WorryDissolverState();
}

class _WorryDissolverState extends State<WorryDissolver> {
  final _controller = TextEditingController();
  bool _dissolving = false;
  int _count = 0;
  bool _released = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dissolve() {
    if (_controller.text.trim().isEmpty || _dissolving) return;
    setState(() {
      _dissolving = true;
      _released = false;
    });
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() {
        _controller.clear();
        _dissolving = false;
        _released = true;
        _count++;
      });
      widget.onReleased?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1EAFB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.air, size: 16, color: Color(0xFF7C5FA6)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Mindful Thought Release',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                  if (_count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0EA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          '$_count ${_count == 1 ? 'thought' : 'thoughts'} released',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Externalizing a ruminating thought by writing it down and letting it go unhooks your mind from the anxiety loop. You are not your thoughts; they are passing mental events.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EFE8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WHAT DISTRESSING THOUGHT IS LOOPING IN YOUR HEAD?',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: _dissolving ? 0 : 1,
                duration: const Duration(milliseconds: 1800),
                child: TextField(
                  controller: _controller,
                  enabled: !_dissolving,
                  minLines: 3,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText:
                        "e.g. 'I will mess up this deliverable and lose everyone's respect'…",
                  ),
                ),
              ),
              if (_dissolving)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.air,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 10),
                      const Text('Dissolving into the breeze…',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      const SizedBox(height: 4),
                      const Text(
                        'You have acknowledged it. Now let it drift away without judgment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Confidential · never stored or sent anywhere.',
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.onSurfaceVariant),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _dissolving ? null : _dissolve,
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
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Release & Dissolve'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_released && !_dissolving) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD5E5D8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: AppColors.secondary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Thought released. It exists independently of you. You are the sky, and that thought was just a passing storm cloud.',
                    style: TextStyle(fontSize: 13, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
