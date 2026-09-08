import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';

class QuickScreenSwitcher extends StatelessWidget {
  const QuickScreenSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'quick_switcher',
      backgroundColor: AppColors.primaryContainer,
      foregroundColor: AppColors.secondaryFixed,
      tooltip: 'Screen Switcher (15 Screens)',
      onPressed: () => _showSwitcherSheet(context),
      child: const Icon(Icons.apps_rounded, size: 20),
    );
  }

  void _showSwitcherSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SwitcherContent(),
    );
  }
}

class _SwitcherContent extends StatelessWidget {
  const _SwitcherContent();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    final screens = [
      {'name': '1. Landing Page', 'route': '/landing', 'icon': Icons.spa_outlined, 'group': 'Auth & Onboarding'},
      {'name': '2. Service ID Login', 'route': '/login', 'icon': Icons.badge_outlined, 'group': 'Auth & Onboarding'},
      {'name': '3. OTP Verification', 'route': '/otp', 'icon': Icons.lock_clock_outlined, 'group': 'Auth & Onboarding'},
      {'name': '4. Data Consent Onboarding', 'route': '/onboarding', 'icon': Icons.verified_user_outlined, 'group': 'Auth & Onboarding'},
      {'name': '5. Personnel Home Dashboard', 'route': '/home', 'icon': Icons.home_rounded, 'group': 'Personnel Suite'},
      {'name': '6. Mood Check-in', 'route': '/mood', 'icon': Icons.sentiment_satisfied_alt, 'group': 'Personnel Suite'},
      {'name': '7. Wellbeing Assessment (10 Qs)', 'route': '/wellbeing', 'icon': Icons.assignment_turned_in_outlined, 'group': 'Personnel Suite'},
      {'name': '8. Self-Help Hub & Box Breathing', 'route': '/self-help', 'icon': Icons.air_rounded, 'group': 'Personnel Suite'},
      {'name': '9. AI Companion & Crisis Line', 'route': '/companion', 'icon': Icons.graphic_eq_rounded, 'group': 'Personnel Suite'},
      {'name': '10. Book Counseling Session', 'route': '/book', 'icon': Icons.event_available_outlined, 'group': 'Personnel Suite'},
      {'name': '11. Profile & Identity Vault', 'route': '/profile', 'icon': Icons.person_outline_rounded, 'group': 'Personnel Suite'},
      {'name': '12. HR Admin Console Overview', 'route': '/hr-overview', 'icon': Icons.admin_panel_settings_outlined, 'group': 'HR & Command'},
      {'name': '13. HR Tier-2 Data Ingestion (CSV)', 'route': '/hr-ingestion', 'icon': Icons.cloud_upload_outlined, 'group': 'HR & Command'},
      {'name': '14. HR Mobile Ingestion Review', 'route': '/hr-mobile-review', 'icon': Icons.mobile_friendly_rounded, 'group': 'HR & Command'},
      {'name': '15. Institutional Resilience', 'route': '/resilience', 'icon': Icons.shield_outlined, 'group': 'HR & Command'},
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All 15 ManoFit Screens',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Text(
                      'Quick demo navigator for evaluation',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Persona Quick Switch Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Switch Active Persona / Role:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _personaChip(context, 'Dhruv (Personnel)', UserProfile.dhruvPersonnel, auth),
                      const SizedBox(width: 8),
                      _personaChip(context, 'Sharma (HR Admin)', UserProfile.sharmaHrAdmin, auth),
                      const SizedBox(width: 8),
                      _personaChip(context, 'Dr. Ananya (Welfare)', UserProfile.ananyaWelfare, auth),
                      const SizedBox(width: 8),
                      _personaChip(context, 'Col. Rao (Commander)', UserProfile.raoCommander, auth),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: screens.length,
              itemBuilder: (context, index) {
                final item = screens[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(context);
                        context.go(item['route'] as String);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item['icon'] as IconData, size: 20, color: AppColors.secondary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primary),
                                  ),
                                  Text(
                                    item['group'] as String,
                                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _personaChip(BuildContext context, String label, UserProfile persona, AuthService auth) {
    final isSelected = auth.currentUser?.id == persona.id;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(color: isSelected ? AppColors.secondaryFixed : AppColors.primary),
      onSelected: (_) {
        auth.switchPersona(persona);
      },
    );
  }
}
