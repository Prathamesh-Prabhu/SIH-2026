import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/ml_models.dart';
import '../services/db_service.dart';
import '../services/ml_service.dart';
import '../widgets/ml_settings_dialog.dart';
import '../widgets/quick_screen_switcher.dart';

/// Welfare Risk Analytics board — the consumer of the ManoFit Analytics & ML
/// microservice. Operates strictly on pseudonymized tokens and shows only
/// clinical risk *bands* plus SHAP-style factor attributions; raw model
/// probabilities are never rendered.
class HrRiskAnalyticsScreen extends StatefulWidget {
  const HrRiskAnalyticsScreen({super.key});

  @override
  State<HrRiskAnalyticsScreen> createState() => _HrRiskAnalyticsScreenState();
}

class _HrRiskAnalyticsScreenState extends State<HrRiskAnalyticsScreen> {
  final _ml = MlService();
  final _db = DbService();

  BatchRiskResult? _result;
  bool _isScoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ml.addListener(_onMlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAnalysis());
  }

  @override
  void dispose() {
    _ml.removeListener(_onMlChanged);
    super.dispose();
  }

  void _onMlChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _isScoring = true;
      _error = null;
    });

    try {
      await _ml.checkHealth();
      final payload = _db.buildCohortScoringPayload();
      final result = await _ml.scoreBatch(payload);
      if (mounted) {
        setState(() {
          _result = result;
          _isScoring = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isScoring = false;
        });
      }
    }
  }

  Color _bandColor(RiskBand band) => switch (band) {
        RiskBand.elevated => AppColors.error,
        RiskBand.moderate => const Color(0xFFB26A00),
        RiskBand.low => AppColors.secondary,
      };

  Color _bandContainer(RiskBand band) => switch (band) {
        RiskBand.elevated => AppColors.errorContainer,
        RiskBand.moderate => const Color(0xFFFFE7C2),
        RiskBand.low => AppColors.secondaryContainer,
      };

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: const QuickScreenSwitcher(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/hr-overview'),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welfare Risk Analytics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Predictive Behavioural Model • Pseudonymized Cohort',
                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet, size: 20),
            tooltip: 'ML Service Endpoint',
            onPressed: () => MlSettingsDialog.show(context),
          ),
          IconButton(
            icon: _isScoring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 20),
            tooltip: 'Re-run cohort scoring',
            onPressed: _isScoring ? null : _runAnalysis,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _runAnalysis,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _serviceStatusBanner(),
              const SizedBox(height: 16),
              if (_error != null) ...[
                _errorCard(_error!),
                const SizedBox(height: 16),
              ],
              if (_isScoring && result == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (result != null) ...[
                _distributionSection(result),
                const SizedBox(height: 24),
                _cohortSection(result),
                const SizedBox(height: 24),
                _modelCardSection(),
                const SizedBox(height: 24),
                _privacyFooter(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Service status
  // -------------------------------------------------------------------

  Widget _serviceStatusBanner() {
    final online = _ml.isOnline;
    final color = online ? AppColors.secondary : const Color(0xFFB26A00);
    final container =
        online ? AppColors.secondaryContainer : const Color(0xFFFFE7C2);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online
                      ? 'Analytics & ML Microservice Connected'
                      : 'ML Microservice Unreachable',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  online ? '${_ml.statusMessage} • ${_ml.baseUrl}' : _ml.statusMessage,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 12, color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Risk band distribution
  // -------------------------------------------------------------------

  Widget _distributionSection(BatchRiskResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Cohort Risk Distribution',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            Text('${r.totalEvaluated} personnel',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _bandStatCard('Low', r.lowCount, RiskBand.low),
            const SizedBox(width: 10),
            _bandStatCard('Moderate', r.moderateCount, RiskBand.moderate),
            const SizedBox(width: 10),
            _bandStatCard('Elevated', r.elevatedCount, RiskBand.elevated),
          ],
        ),
        const SizedBox(height: 14),
        _distributionBar(r),
      ],
    );
  }

  Widget _bandStatCard(String label, int count, RiskBand band) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bandColor(band).withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: _bandColor(band), shape: BoxShape.circle),
            ),
            const SizedBox(height: 12),
            Text('$count',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _bandColor(band))),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _distributionBar(BatchRiskResult r) {
    if (r.totalEvaluated == 0) return const SizedBox.shrink();

    Widget segment(int count, RiskBand band) {
      if (count == 0) return const SizedBox.shrink();
      return Expanded(
        flex: count,
        child: Container(color: _bandColor(band)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                segment(r.lowCount, RiskBand.low),
                segment(r.moderateCount, RiskBand.moderate),
                segment(r.elevatedCount, RiskBand.elevated),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(r.elevatedRatio * 100).toStringAsFixed(1)}% of the cohort is in the '
          'Elevated band and warrants proactive, confidential welfare outreach.',
          style: const TextStyle(
              fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Per-personnel breakdown
  // -------------------------------------------------------------------

  Widget _cohortSection(BatchRiskResult r) {
    // Highest-risk personnel first so outreach queues top the list.
    final sorted = [...r.results]
      ..sort((a, b) => b.riskBand.index.compareTo(a.riskBand.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pseudonymized Cohort Assessment',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
        const SizedBox(height: 4),
        const Text(
          'Tap a token to view the contributing factors shared with Welfare Officers.',
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ...sorted.map(_personnelTile),
      ],
    );
  }

  Widget _personnelTile(RiskAssessment a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const Border(),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _bandContainer(a.riskBand),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fingerprint,
                color: _bandColor(a.riskBand), size: 22),
          ),
          title: Text(
            a.pseudonymToken,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface),
          ),
          subtitle: Text(
            'Model ${a.modelVersion} • confidence band ${(a.confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _bandContainer(a.riskBand),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              a.riskBand.displayName,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _bandColor(a.riskBand)),
            ),
          ),
          children: [
            if (a.topFactors.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('No dominant contributing factors identified.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              )
            else
              // SHAP weights are unbounded, so bars are scaled against the
              // strongest factor for this person rather than against 1.0.
              ...() {
                final maxWeight = a.topFactors
                    .map((f) => f.importanceWeight.abs())
                    .fold<double>(0, (m, w) => w > m ? w : m);
                return a.topFactors.map((f) => _factorRow(f, maxWeight));
              }(),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recommended Support Pathway',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Text(
                    a.recommendedSupportPathway,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _factorRow(FactorAttribution f, double maxWeight) {
    final color =
        f.isRiskIncreasing ? AppColors.error : AppColors.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            f.isRiskIncreasing
                ? Icons.trending_up_rounded
                : Icons.shield_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.displayTitle,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(f.contextDetail,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        height: 1.3)),
                const SizedBox(height: 5),
                // Relative contribution weight, not a raw risk probability.
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxWeight <= 0
                        ? 0.0
                        : (f.importanceWeight.abs() / maxWeight)
                            .clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Model governance
  // -------------------------------------------------------------------

  Widget _modelCardSection() {
    final card = _ml.modelCard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Model Card & Governance',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: card == null
              ? const Text(
                  'Model card unavailable. Start the ML microservice to view '
                  'training provenance, metrics, and Oversight Board sign-off.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(card.modelName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface)),
                        ),
                        if (card.oversightBoardApproved)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified,
                                    size: 12, color: AppColors.secondary),
                                SizedBox(width: 4),
                                Text('Board Approved',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.secondary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${card.modelType} • ${card.version} • validated ${card.lastValidatedDate}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${card.trainingWindow} • n=${card.sampleSize} • '
                      '${card.featuresUtilized.length} features',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: card.metrics.entries
                          .map((e) => _metricChip(e.key, e.value))
                          .toList(),
                    ),
                    if (card.knownLimitations.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Known Limitations',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                      const SizedBox(height: 6),
                      ...card.knownLimitations.map(
                        (l) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.onSurfaceVariant)),
                              Expanded(
                                child: Text(l,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.onSurfaceVariant,
                                        height: 1.35)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _metricChip(String name, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant)),
          const SizedBox(width: 6),
          Text(value.toStringAsFixed(2),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary)),
        ],
      ),
    );
  }

  Widget _privacyFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined,
              size: 18, color: AppColors.secondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'The analytics layer receives only rotating pseudonym tokens and '
              'derived rolling features — never names, Service/PF numbers, or '
              'disciplinary and medical records. Outputs are clinical support '
              'bands, never fitness-for-duty or disciplinary determinations.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
