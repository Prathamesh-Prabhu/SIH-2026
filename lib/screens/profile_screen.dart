import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../widgets/quick_screen_switcher.dart';
import '../widgets/supabase_settings_dialog.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final supabase = SupabaseService();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: const QuickScreenSwitcher(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Personnel Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_outlined, color: AppColors.secondary),
            tooltip: 'Supabase Settings',
            onPressed: () => SupabaseSettingsDialog.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personnel Identity Summary Bento Card
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
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.secondaryContainer,
                          child: Text(
                            (user?.fullName.isNotEmpty == true) ? user!.fullName[0] : 'P',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user?.fullName ?? 'Constable Dhruv',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, size: 16, color: AppColors.secondary),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Service ID: ${user?.serviceId ?? 'CAPF-8821'} • ${user?.rank ?? 'Constable'}',
                                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                              ),
                              Text(
                                user?.unit ?? '144th Bn CAPF',
                                style: const TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Active Duty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Quick Stats Metric Ribbon
                    Row(
                      children: [
                        _metricTile('14', 'Days Logged', AppColors.primary),
                        _metricTile('${user?.readinessScore ?? 88}%', 'Readiness', AppColors.secondary),
                        _metricTile(user?.stressZone ?? 'Zone A', 'Stress Level', AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Trust & Cryptographic Reassurance Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock, size: 18, color: AppColors.onSecondaryFixedVariant),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Military-Grade Confidentiality',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          Text(
                            'Zero command-hierarchy visibility into check-in inputs. RLS enforced.',
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings & Security Group
              const Text('Service & Security', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    _settingsTile(
                      icon: Icons.hub_outlined,
                      title: 'Supabase Connection',
                      subtitle: supabase.isMockMode ? 'Mock / Demo Fallback Mode' : 'Connected to ${supabase.currentUrl}',
                      onTap: () => SupabaseSettingsDialog.show(context),
                    ),
                    const Divider(height: 1),
                    _settingsTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Data & Privacy Explainer',
                      subtitle: 'DPDP Act 2023 compliance & consent audit ledger',
                      onTap: () => context.go('/onboarding'),
                    ),
                    const Divider(height: 1),
                    _settingsTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Switch to HR Admin Console',
                      subtitle: 'Review roster ingestion & validation status',
                      onTap: () {
                        auth.switchPersona(UserProfile.sharmaHrAdmin);
                        context.go('/hr-overview');
                      },
                    ),
                    const Divider(height: 1),
                    _settingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Switch to Commander Resilience',
                      subtitle: 'Aggregate unit-level wellness index (no individual names)',
                      onTap: () {
                        auth.switchPersona(UserProfile.raoCommander);
                        context.go('/resilience');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) {
                      context.go('/landing');
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign Out from Terminal', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.errorContainer),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile(String value, String label, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.outline, size: 18),
      onTap: onTap,
    );
  }
}
