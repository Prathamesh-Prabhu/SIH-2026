import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../data/admin_demo_data.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../widgets/dashboard/dashboard_kit.dart';
import '../widgets/ml_settings_dialog.dart';
import '../widgets/supabase_settings_dialog.dart';

/// HR Admin Console — ingestion status only.
///
/// Layout follows the stitch `hr_admin_web_console_overview` design (record
/// counters → ingestion sources by tier → recent activity table) with
/// mindspace's card/stat-tile treatment, drawn in ManoFit stitch tokens.
///
/// PRD §6.4 / §2: HR Admin is structurally scoped to data *supply*. Nothing on
/// this screen shows a risk score, a band, or an individual — the analytics
/// board is a different console with a different role.
class HrAdminOverviewScreen extends StatelessWidget {
  const HrAdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final db = DbService();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr(),
        ),
        title: const Text('HR Admin Console',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_outlined, size: 20),
            tooltip: 'Backend connection',
            onPressed: () => SupabaseSettingsDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet, size: 20),
            tooltip: 'ML service endpoint',
            onPressed: () => MlSettingsDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.mobile_friendly_rounded, size: 20),
            tooltip: 'Mobile ingestion review',
            onPressed: () => context.push('/hr-mobile-review'),
          ),
        ],
      ),
      body: SafeArea(
        // DbService is a ChangeNotifier — rebuild when a batch is ingested.
        child: ListenableBuilder(
          listenable: db,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              PageHeading(
                title: 'HR Dashboard',
                subtitle:
                    'Manage HR data ingestion and system integration · ${auth.currentUser?.fullName ?? 'HR Admin'}',
                badge: 'Data supply only',
              ),
              _scopeNotice(),
              const SizedBox(height: 16),
              _counters(),
              const SizedBox(height: 16),
              _volumeTrend(),
              const SizedBox(height: 16),
              _sources(context),
              const SizedBox(height: 16),
              _recentActivity(db),
              const SizedBox(height: 16),
              _rejectionReasons(),
              const SizedBox(height: 18),
              _ingestCta(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sections ─────────────────────────────────────────────────────────────

  Widget _scopeNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E5D8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined,
              size: 18, color: AppColors.secondary),
          SizedBox(width: 10),
          // Wording deliberately avoids the analytics vocabulary itself —
          // `hr_admin_console_test` asserts none of it appears on this console.
          Expanded(
            child: Text(
              'Records are pseudonymized on ingestion. This console covers ingestion '
              'status only; welfare analytics and individual data sit behind a '
              'separate role.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.45, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _counters() {
    final acceptRate = kTotalRecordsProcessed == 0
        ? 0.0
        : kAcceptedRecords / kTotalRecordsProcessed * 100;
    return TileGrid(
      children: [
        const IndexTile(
          label: 'Total records processed',
          value: '12,480',
          hint: 'all tiers, this cycle',
          icon: Icons.dataset_outlined,
          accent: AppColors.primary,
        ),
        IndexTile(
          label: 'Accepted records',
          value: '12,327',
          hint: '${acceptRate.toStringAsFixed(1)}% acceptance rate',
          icon: Icons.check_circle_outline,
          accent: AppColors.secondary,
        ),
        const IndexTile(
          label: 'Rejected records',
          value: '153',
          hint: 'failed schema validation',
          icon: Icons.report_gmailerrorred_outlined,
          accent: AppColors.error,
        ),
        const IndexTile(
          label: 'Last successful sync',
          value: '02:15',
          hint: kLastSuccessfulSync,
          icon: Icons.sync,
          accent: Color(0xFFB26A00),
        ),
      ],
    );
  }

  Widget _volumeTrend() {
    final first = kIngestionVolumeTrend.first;
    final last = kIngestionVolumeTrend.last;
    final pct = first == 0 ? 0.0 : (last - first) / first * 100;
    return ChartCard(
      title: 'Accepted record volume',
      description: '12-week ingestion throughput',
      trailing: DeltaBadge(pct, suffix: '%'),
      child: const TrendChart(values: kIngestionVolumeTrend),
    );
  }

  Widget _sources(BuildContext context) {
    return ChartCard(
      title: 'Ingestion sources',
      description: 'Tier 1 API · Tier 2 bulk upload · Tier 3 manual',
      child: Column(
        children: [
          for (var i = 0; i < kIngestionSources.length; i++) ...[
            _sourceRow(kIngestionSources[i]),
            if (i != kIngestionSources.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _sourceRow(IngestionSource s) {
    final color = s.healthy ? AppColors.secondary : AppColors.onSurfaceVariant;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            s.tier == 'Tier 1'
                ? Icons.api_outlined
                : s.tier == 'Tier 2'
                    ? Icons.cloud_upload_outlined
                    : Icons.edit_note_outlined,
            size: 19,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${s.name} (${s.tier})',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              const SizedBox(height: 2),
              Text(s.detail,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StatusPill(
          label: s.status,
          fg: color,
          bg: color.withOpacity(0.12),
        ),
      ],
    );
  }

  Widget _recentActivity(DbService db) {
    // Any batch ingested this session is shown above the fixed demo history.
    final live = db.hrIngestionBatches.map((b) => IngestionRun(
          timestamp: 'This session',
          source: (b['filename'] as String?) ?? 'CSV Upload',
          records: (b['total_rows'] as num?)?.toInt() ?? 0,
          rejected: (b['rejected_rows'] as num?)?.toInt() ?? 0,
          status: (b['status'] as String?) == 'committed' ? 'Completed' : 'Partial',
        ));
    final runs = [...live, ...kRecentIngestionRuns].take(8).toList();

    return ChartCard(
      title: 'Recent ingestion activity',
      description: 'Newest first',
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        children: [
          for (var i = 0; i < runs.length; i++) ...[
            _runRow(runs[i]),
            if (i != runs.length - 1)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Divider(height: 14),
              ),
          ],
        ],
      ),
    );
  }

  Widget _runRow(IngestionRun r) {
    final ok = r.status == 'Completed';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                Text(r.timestamp,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${r.records}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                Text(r.rejected == 0 ? 'no rejects' : '${r.rejected} rejected',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: r.rejected == 0
                            ? AppColors.onSurfaceVariant
                            : AppColors.error)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(
            label: r.status,
            fg: ok ? AppColors.secondary : const Color(0xFFB26A00),
            bg: ok ? const Color(0xFFE8F0EA) : const Color(0xFFFFE7C2),
          ),
        ],
      ),
    );
  }

  Widget _rejectionReasons() {
    final total = kRejectionReasons.values.fold<int>(0, (a, b) => a + b);
    return ChartCard(
      title: 'Why rows were rejected',
      description: '$total rejected rows this cycle',
      child: RankedBarChart(
        rows: [
          for (final e in kRejectionReasons.entries)
            RankedRow(e.key, e.value.toDouble(), color: AppColors.statusCaution),
        ],
      ),
    );
  }

  Widget _ingestCta(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.push('/hr-ingestion'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.cloud_upload_outlined, size: 18),
        label: const Text('Upload a new roster batch',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
