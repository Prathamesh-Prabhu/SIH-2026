import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/quick_screen_switcher.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _auth = AuthService();
  bool _companionMemory = true;
  bool _wearableSync = false;
  bool _anonymizedResearch = true;

  void _completeOnboarding() {
    _auth.updateConsent({
      'mandatory_hr_sync': true,
      'optional_wearable_sync': _wearableSync,
      'companion_memory': _companionMemory,
      'anonymized_research': _anonymizedResearch,
    });
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: const QuickScreenSwitcher(),
      appBar: AppBar(
        title: const Text('Confidentiality Charter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text('Skip', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.secondary, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Privacy is Protected',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ManoFit is built with zero-command hierarchy visibility. Review how your data is handled.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // Mandatory vs Optional Cards
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('MANDATORY OPERATIONAL', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        const Icon(Icons.lock, size: 16, color: AppColors.secondary),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Operational Load & Leave Sync',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Roster hours and leave balances are synced for fatigue monitoring. Never shared for disciplinary or fitness actions.',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Consent Toggles
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('OPTIONAL CONTROLS', style: TextStyle(fontSize: 10, color: AppColors.secondary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('AI Companion Reflection Memory', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Enables empathetic continuity across sessions. Stored locally/encrypted.', style: TextStyle(fontSize: 11)),
                      activeColor: AppColors.secondary,
                      value: _companionMemory,
                      onChanged: (v) => setState(() => _companionMemory = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Wearable Health Sync (Phase 3)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Sleep, resting HRV, and steps via Health Connect. Disabled by default.', style: TextStyle(fontSize: 11)),
                      activeColor: AppColors.secondary,
                      value: _wearableSync,
                      onChanged: (v) => setState(() => _wearableSync = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Anonymized Research Aggregate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Contribute anonymized statistics to armed forces wellbeing research.', style: TextStyle(fontSize: 11)),
                      activeColor: AppColors.secondary,
                      value: _anonymizedResearch,
                      onChanged: (v) => setState(() => _anonymizedResearch = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Accept & Enter ManoFit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      Icon(Icons.check_circle_outline, size: 18),
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
