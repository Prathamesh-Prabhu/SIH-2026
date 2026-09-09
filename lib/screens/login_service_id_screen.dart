import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../core/auth/role_access.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

class LoginServiceIdScreen extends StatefulWidget {
  const LoginServiceIdScreen({super.key});

  @override
  State<LoginServiceIdScreen> createState() => _LoginServiceIdScreenState();
}

class _LoginServiceIdScreenState extends State<LoginServiceIdScreen> {
  final _serviceIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _serviceIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    FocusScope.of(context).unfocus();
    final serviceId = _serviceIdController.text.trim();
    final password = _passwordController.text;

    if (serviceId.isEmpty) {
      setState(() => _error = 'Enter your Service / PF number.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Enter your access password.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await _auth.signInWithServiceId(serviceId, password);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.ok) {
      // Land on the console this role owns. The router redirect still has the
      // final say (e.g. it diverts to /onboarding when consent is pending).
      context.go(_auth.currentRole.homeRoute);
    } else {
      setState(() => _error = result.error ?? 'Sign-in failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMockMode = SupabaseService().isMockMode;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/landing'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Your Service ID is printed on your appointment order or identity card. Password is issued by your HR cell.')),
              );
            },
            child: const Text('Need help?',
                style: TextStyle(color: AppColors.secondary)),
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.verified_user,
                    color: AppColors.onSecondaryContainer, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in to ManoFit',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use your Service / PF number and issued password',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 28),

              // Service ID field
              _fieldLabel('Service / PF Number', trailing: 'Verified ID'),
              const SizedBox(height: 8),
              TextField(
                controller: _serviceIdController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 16),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.outline),
                  hintText: 'e.g. CAPF-8821',
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              _fieldLabel('Access Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                onSubmitted: (_) => _handleContinue(),
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 16),
                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.lock_outline, color: AppColors.outline),
                  hintText: 'Issued by your HR cell',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.outline),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onErrorContainer,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sign In',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: AppColors.onSecondaryContainer, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Verified government system. Only data required for your welfare support is collected; there is no command-chain access to your check-ins.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),

              if (isMockMode) ...[
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Demo mode: quick-fill personas:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _persona('Dhruv (Personnel)', 'CAPF-8821'),
                    _persona('Sharma (HR Admin)', 'HR-ADMIN-01'),
                    _persona('Dr. Ananya (Welfare)', 'WELFARE-07'),
                    _persona('Col. Rao (Commander)', 'CMD-UNIT-42'),
                    _persona('Oversight Board', 'OVERSIGHT-01'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
        if (trailing != null)
          Text(trailing,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondary)),
      ],
    );
  }

  Widget _persona(String label, String id) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: AppColors.surfaceContainerLowest,
      side: const BorderSide(color: AppColors.outlineVariant),
      onPressed: () {
        setState(() {
          _serviceIdController.text = id;
          _passwordController.text = 'demo';
        });
      },
    );
  }
}
