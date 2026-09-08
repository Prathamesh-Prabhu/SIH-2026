import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/quick_screen_switcher.dart';

class LoginServiceIdScreen extends StatefulWidget {
  const LoginServiceIdScreen({super.key});

  @override
  State<LoginServiceIdScreen> createState() => _LoginServiceIdScreenState();
}

class _LoginServiceIdScreenState extends State<LoginServiceIdScreen> {
  final _serviceIdController = TextEditingController(text: 'CAPF-8821');
  final _auth = AuthService();
  bool _submitting = false;

  @override
  void dispose() {
    _serviceIdController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final text = _serviceIdController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Service / PF number')),
      );
      return;
    }

    setState(() => _submitting = true);
    await _auth.initiateServiceIdLogin(text);
    setState(() => _submitting = false);

    if (mounted) {
      context.go('/otp');
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
          onPressed: () => context.go('/landing'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Service ID is printed on your official appointment order or identity card.')),
              );
            },
            child: const Text('Need help?', style: TextStyle(color: AppColors.secondary)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Icon Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.spa, color: AppColors.onSecondaryContainer, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to ManoFit',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign in with your Service / PF number',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // Service ID Input Card
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Service / PF Number',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      Text(
                        'Verified ID',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: TextField(
                      controller: _serviceIdController,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 16),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined, color: AppColors.outline),
                        hintText: 'e.g. CAPF-8821 or HR-ADMIN-01',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Security & Encrypted Vault Reassurance Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.verified_user, color: AppColors.onSecondaryContainer, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verified government system',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Only the data required for your welfare support is collected. No command chain access.',
                                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.lock, size: 14, color: AppColors.secondary),
                        SizedBox(width: 6),
                        Text(
                          '256-bit encrypted & isolated credential vault',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Test Personas Quick Buttons
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick-Fill Test Personas:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _testPersonaButton('Dhruv (Personnel)', 'CAPF-8821'),
                  _testPersonaButton('Sharma (HR Admin)', 'HR-ADMIN-01'),
                  _testPersonaButton('Dr. Ananya (Welfare)', 'WELFARE-07'),
                  _testPersonaButton('Col. Rao (Commander)', 'CMD-UNIT-42'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _testPersonaButton(String label, String id) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: AppColors.surfaceContainerLowest,
      side: const BorderSide(color: AppColors.outlineVariant),
      onPressed: () {
        setState(() {
          _serviceIdController.text = id;
        });
      },
    );
  }
}
