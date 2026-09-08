import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/ml_service.dart';
import '../widgets/ml_settings_dialog.dart';
import '../widgets/quick_screen_switcher.dart';
import '../widgets/supabase_settings_dialog.dart';

class HrAdminOverviewScreen extends StatelessWidget {
  const HrAdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final db = DbService();
    final batches = db.hrIngestionBatches;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F4),
      floatingActionButton: const QuickScreenSwitcher(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ManoFit HR Console', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text('Tier 1 & 2 Ingestion Portal', style: TextStyle(fontSize: 11, color: Colors.black54)),
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
            icon: const Icon(Icons.insights_outlined, color: Colors.black54),
            tooltip: 'Analytics & ML Service',
            onPressed: () => MlSettingsDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.mobile_friendly_rounded, color: Colors.black54),
            tooltip: 'Mobile Review Screen',
            onPressed: () => context.go('/hr-mobile-review'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            tooltip: 'Exit HR Console',
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
              // Welcome Banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operational Roster Overview',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        'Sector HQ Data Pipeline • Active Admin: ${auth.currentUser?.fullName ?? 'Inspector Sharma'}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/hr-ingestion'),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Bulk Ingest (CSV)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4 Stat Cards
              Row(
                children: [
                  _statCard('3,842', 'Active Personnel', Icons.people_alt_outlined, Colors.green[800]!),
                  const SizedBox(width: 12),
                  _statCard('98.4%', 'Ingestion Parity', Icons.sync_rounded, Colors.teal[700]!),
                  const SizedBox(width: 12),
                  _statCard('82%', 'Leave Balance Health', Icons.beach_access_outlined, Colors.blue[700]!),
                ],
              ),
              const SizedBox(height: 16),

              // Entry point into the ML-backed welfare risk analytics board
              _analyticsCard(context),
              const SizedBox(height: 24),

              // Pseudonymization Compliance Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.verified_user, color: Colors.green[800], size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Strict Tier 2 Pseudonymization Active',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Raw Service / PF Numbers are cryptographically hashed into rotating tokens before feeding analytics. HR Admin never views individual predictive risk scores.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent Ingestion Batches Table / List
              const Text(
                'Recent Roster Ingestion Batches',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: batches.length,
                itemBuilder: (context, index) {
                  final b = batches[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.table_chart_outlined, color: Colors.green[800], size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b['filename'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Batch ID: ${b['id']} • ${b['file_size_kb']} KB',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${b['accepted_rows']} / ${b['total_rows']} rows',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[900]),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${b['rejected_rows']} rejected',
                              style: const TextStyle(fontSize: 11, color: Colors.black45),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gateway to the predictive analytics board. Live/offline state comes from
  /// [MlService] so an HR admin can see at a glance whether the microservice
  /// is answering before they open the board.
  Widget _analyticsCard(BuildContext context) {
    final ml = MlService();
    final online = ml.isOnline;

    return InkWell(
      onTap: () => context.go('/hr-analytics'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF02241F), Color(0xFF1A3A34)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.insights_rounded,
                  color: Color(0xFFBAEDDE), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welfare Risk Analytics',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'XGBoost behavioural risk bands & factor attributions over the pseudonymized roster',
                    style: TextStyle(fontSize: 11, color: Color(0xFF83A49C), height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: online
                              ? const Color(0xFF6BD6B4)
                              : const Color(0xFFE0A458),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        online ? 'ML service online' : 'ML service offline • fallback active',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF83A49C)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF83A49C), size: 16),
          ],
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
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
