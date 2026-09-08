import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/quick_screen_switcher.dart';
import '../widgets/supabase_settings_dialog.dart';

class InstitutionalResilienceScreen extends StatelessWidget {
  const InstitutionalResilienceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      floatingActionButton: const QuickScreenSwitcher(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: AppColors.secondaryFixed, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Institutional Resilience', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Text('Commander Aggregate Console', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_outlined, color: Colors.black54),
            tooltip: 'Supabase Settings',
            onPressed: () => SupabaseSettingsDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            tooltip: 'Exit to Home',
            onPressed: () => context.go('/home'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Differential Privacy Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.secondaryContainer),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock, color: AppColors.secondary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Differential Privacy Enforced (k-Anonymity > 25)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Commanders view unit-level trends only. Under Section 3.2 of the PRD, individual scores are cryptographically masked to prevent stigmatization.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Unit Station & Commander Header
              Text(
                'Sector Unit Readiness Overview',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              Text(
                'Reporting Commander: ${user?.fullName ?? 'Col. Rajesh Rao'} • 144th Bn Frontier Deployment',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 18),

              // 4 Key Resilience Metrics Grid
              Row(
                children: [
                  _statCard('86%', 'Unit Readiness Index', Icons.health_and_safety_outlined, AppColors.secondary),
                  const SizedBox(width: 12),
                  _statCard('6.4 d', 'Avg Consecutive Duty', Icons.calendar_today_outlined, AppColors.primary),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statCard('91%', 'Leave Utilization Parity', Icons.beach_access_outlined, Colors.teal[800]!),
                  const SizedBox(width: 12),
                  _statCard('Zone A', 'Overall Stress Band', Icons.sentiment_satisfied_alt, Colors.green[800]!),
                ],
              ),
              const SizedBox(height: 24),

              // Distribution Breakdown Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cohort Risk-Band Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                        Text('Total: 842 Personnel', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Multi-colored bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 14,
                        child: Row(
                          children: [
                            Expanded(flex: 74, child: Container(color: Colors.green[600])),
                            Expanded(flex: 20, child: Container(color: Colors.amber[600])),
                            Expanded(flex: 6, child: Container(color: Colors.red[600])),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _legendDot('Low Risk (74%)', Colors.green[600]!),
                        _legendDot('Moderate (20%)', Colors.amber[600]!),
                        _legendDot('Elevated / WO Reviewed (6%)', Colors.red[600]!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Command Action Button: Request Welfare Rotation
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rotation resource recommendation submitted to Sector Welfare Office.'),
                        backgroundColor: AppColors.secondary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment_turned_in, size: 18),
                  label: const Text('Request Proactive Welfare Roster Rotation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: Colors.white,
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

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }
}
