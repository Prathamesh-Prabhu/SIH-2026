import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../services/db_service.dart';
import '../widgets/quick_screen_switcher.dart';

class WellbeingCheckInScreen extends StatefulWidget {
  const WellbeingCheckInScreen({super.key});

  @override
  State<WellbeingCheckInScreen> createState() => _WellbeingCheckInScreenState();
}

class _WellbeingCheckInScreenState extends State<WellbeingCheckInScreen> {
  int _currentIndex = 2; // Question 3 by default per reference design
  final Map<int, int> _answers = {
    0: 0, // Not at all
    1: 1, // Several days
    2: 1, // Several days (preselected per stitch)
  };
  final _db = DbService();
  bool _submitting = false;

  final List<String> _questions = [
    'Little interest or pleasure in doing daily operational tasks or hobbies?',
    'Feeling down, depressed, or fatigued after continuous duty rotations?',
    'In the past two weeks, how often have you felt restless or on edge?',
    'Trouble falling or staying asleep, or sleeping too much during rest cycles?',
    'Feeling tired or having little energy during deployment shifts?',
    'Poor appetite or overeating during prolonged outpost postings?',
    'Trouble concentrating on instructions, communications, or routine details?',
    'Feeling nervous, anxious, or unable to stop or control worrying?',
    'Worrying too much about different personal or organizational matters?',
    'Becoming easily annoyed or irritable around peers or unit members?',
  ];

  final List<Map<String, dynamic>> _options = [
    {'text': 'Not at all', 'score': 0},
    {'text': 'Several days', 'score': 1},
    {'text': 'More than half the days', 'score': 2},
    {'text': 'Nearly every day', 'score': 3},
  ];

  Future<void> _completeAssessment() async {
    setState(() => _submitting = true);

    int totalScore = 0;
    final Map<String, dynamic> formattedAnswers = {};
    _answers.forEach((qIndex, score) {
      totalScore += score;
      formattedAnswers['q${qIndex + 1}'] = {
        'question': _questions[qIndex],
        'score': score,
      };
    });

    await _db.recordAssessment(
      totalScore: totalScore,
      answers: formattedAnswers,
    );

    setState(() => _submitting = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.secondary),
              SizedBox(width: 8),
              Text('Assessment Complete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Score: $totalScore / 30',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your survey data is pseudonymized and stored securely in accordance with DPDP Act 2023. It will feed the predictive welfare model without exposing your raw inputs to commanders.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/home');
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / _questions.length;
    final currentScore = _answers[_currentIndex] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: const QuickScreenSwitcher(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Active Assessment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.person, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('QUESTION PROGRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.onSurfaceVariant)),
                  Text(
                    '${_currentIndex + 1} of ${_questions.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryContainer),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 18),

              // Category Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, size: 14, color: AppColors.onSecondaryContainer),
                    SizedBox(width: 4),
                    Text(
                      'Personal Wellbeing Assessment',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Question Heading
              Text(
                _questions[_currentIndex],
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select the option that best describes your operational or daily experience.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // Multiple Choice Options
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final opt = _options[index];
                  final isSelected = currentScore == opt['score'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: isSelected ? AppColors.secondaryFixed.withOpacity(0.35) : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      elevation: isSelected ? 0 : 1,
                      shadowColor: Colors.black.withOpacity(0.04),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            _answers[_currentIndex] = opt['score'] as int;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                opt['text'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppColors.primaryContainer : AppColors.onSurface,
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerHigh,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Bottom Navigation Buttons
              Row(
                children: [
                  if (_currentIndex > 0) ...[
                    OutlinedButton(
                      onPressed: () => setState(() => _currentIndex--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.outlineVariant),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentIndex < _questions.length - 1) {
                          setState(() => _currentIndex++);
                        } else {
                          _completeAssessment();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentIndex == _questions.length - 1 ? 'Submit Assessment' : 'Next Question',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
