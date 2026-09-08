import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../services/db_service.dart';
import '../widgets/quick_screen_switcher.dart';

class MoodCheckInScreen extends StatefulWidget {
  const MoodCheckInScreen({super.key});

  @override
  State<MoodCheckInScreen> createState() => _MoodCheckInScreenState();
}

class _MoodCheckInScreenState extends State<MoodCheckInScreen> {
  int _selectedMoodIndex = 1; // Default 'Good'
  final _notesController = TextEditingController();
  final Set<String> _selectedFactors = {'Roster Load', 'Sleep'};
  final _db = DbService();
  bool _saving = false;

  final _moodOptions = [
    {
      'label': 'Very good',
      'desc': 'Energized, confident & clear',
      'score': 4,
      'icon': Icons.sentiment_very_satisfied,
      'color': AppColors.secondary,
      'bg': AppColors.secondaryContainer,
    },
    {
      'label': 'Good',
      'desc': 'Calm, balanced & steady',
      'score': 3,
      'icon': Icons.sentiment_satisfied,
      'color': AppColors.secondary,
      'bg': AppColors.secondaryContainer,
    },
    {
      'label': 'Okay',
      'desc': 'Managing routine load',
      'score': 2,
      'icon': Icons.sentiment_neutral,
      'color': AppColors.outline,
      'bg': AppColors.surfaceContainerHigh,
    },
    {
      'label': 'Not great',
      'desc': 'Tense, fatigued or drained',
      'score': 1,
      'icon': Icons.sentiment_dissatisfied,
      'color': AppColors.error,
      'bg': AppColors.errorContainer,
    },
  ];

  final _factors = ['Roster Load', 'Sleep', 'Deployment', 'Weather', 'Family', 'Physical Health'];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitMood() async {
    setState(() => _saving = true);
    final chosen = _moodOptions[_selectedMoodIndex];

    await _db.recordMood(
      score: chosen['score'] as int,
      label: chosen['label'] as String,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      energy: _selectedMoodIndex <= 1 ? 'High' : 'Moderate',
    );

    setState(() => _saving = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.secondary),
              SizedBox(width: 8),
              Text('Check-in Recorded', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Your mood has been privately saved to your personal wellbeing log. Thank you for reflecting today.',
            style: TextStyle(fontSize: 13),
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: const QuickScreenSwitcher(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Active Assessment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar (1 of 3)
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0.33,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('1 of 3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 18),

              Text(
                'How are you feeling today?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Take a moment to check in with yourself. This is private and helps you track your own wellbeing over time.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.3),
              ),
              const SizedBox(height: 20),

              // Mood Options
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _moodOptions.length,
                itemBuilder: (context, index) {
                  final opt = _moodOptions[index];
                  final isSelected = _selectedMoodIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: isSelected ? AppColors.secondaryContainer.withOpacity(0.4) : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      elevation: isSelected ? 0 : 1,
                      shadowColor: Colors.black.withOpacity(0.03),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _selectedMoodIndex = index),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: opt['bg'] as Color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(opt['icon'] as IconData, color: opt['color'] as Color, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opt['label'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt['desc'] as String,
                                      style: TextStyle(fontSize: 12, color: isSelected ? AppColors.secondary : AppColors.onSurfaceVariant),
                                    ),
                                  ],
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
              const SizedBox(height: 16),

              // Contributing Factors
              const Text(
                'Key Factors (Select applicable)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _factors.map((f) {
                  final isSelected = _selectedFactors.contains(f);
                  return FilterChip(
                    label: Text(f, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.secondary : AppColors.primary)),
                    selected: isSelected,
                    selectedColor: AppColors.secondaryContainer.withOpacity(0.5),
                    backgroundColor: AppColors.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: isSelected ? AppColors.secondary : AppColors.outlineVariant),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedFactors.add(f);
                        } else {
                          _selectedFactors.remove(f);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Optional Reflection Note
              const Text(
                'Private Note (Optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Add any thoughts on today\'s duty or recovery...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submitMood,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Submit Check-in', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
