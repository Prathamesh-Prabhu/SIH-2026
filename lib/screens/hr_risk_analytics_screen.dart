import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../data/admin_demo_data.dart';
import '../models/ml_models.dart';
import '../services/db_service.dart';
import '../services/ml_service.dart';
import '../widgets/dashboard/dashboard_kit.dart';

/// Welfare Risk Analytics console.
///
/// Information architecture follows mindspace's admin overview (executive
/// summary → population breakdown → composite indices → cohort ranking →
/// drill-down), rendered in the ManoFit stitch tokens.
///
/// Risk *bands* come from the scoring pipeline — the live ML microservice when
/// reachable, `MlService`'s on-device heuristics otherwise. Trend, unit
/// aggregates and review-queue figures are fixed demo data
/// (`admin_demo_data.dart`) until those endpoints exist.
///
/// PRD §8.1 / §3: bands, aggregates and factor attributions only — never a raw
/// model probability, never an identity.
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
    setState(() => _isScoring = true);
    // scoreBatch falls back to on-device heuristics when the service is
    // unreachable, so this never leaves the board empty.
    await _ml.checkHealth();
    final result = await _ml.scoreBatch(_db.buildCohortScoringPayload());
    if (!mounted) return;
    setState(() {
      _result = result;
      _isScoring = false;
    });
  }

  static Color _bandColor(RiskBand b) => switch (b) {
        RiskBand.elevated => AppColors.statusDistress,
        RiskBand.moderate => AppColors.statusCaution,
        RiskBand.low => AppColors.statusPositive,
      };

  @override
  Widget build(BuildContext context) {
    final r = _result;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr(),
        ),
        title: const Text('Welfare Risk Analytics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
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
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _runAnalysis,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              PageHeading(
                title: 'Cohort Risk Board',
                subtitle:
                    'Pseudonymized cohort · rolling 30-day feature window',
                badge: _ml.isOnline ? 'Live model' : 'On-device scoring',
              ),

              if (r == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _summary(r),
                const SizedBox(height: 16),
                _indices(r),
                const SizedBox(height: 16),
                _distribution(r),
                const SizedBox(height: 16),
                _trend(),
                const SizedBox(height: 16),
                _units(),
                const SizedBox(height: 16),
                _drivers(),
                const SizedBox(height: 20),
                SectionHeading('Cases awaiting clinical review',
                    icon: Icons.medical_information_outlined,
                    trailing: StatusPill(
                      label: '${_needsReview(r).length} open',
                      fg: AppColors.error,
                      bg: AppColors.errorContainer,
                    )),
                ..._needsReview(r).map(_caseCard),
                const SizedBox(height: 16),
                _provenance(r),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<RiskAssessment> _needsReview(BatchRiskResult r) => r.results
      .where((a) => a.riskBand != RiskBand.low)
      .toList()
    ..sort((a, b) => a.riskBand.index.compareTo(b.riskBand.index));

  // ── Sections ─────────────────────────────────────────────────────────────

  Widget _summary(BatchRiskResult r) {
    final elevatedPct =
        r.totalEvaluated == 0 ? 0 : (r.elevatedCount / r.totalEvaluated * 100);
    final worst = kUnitRisk.first;
    final trendDown = kWellbeingIndexDelta < 0;

    return ExecutiveSummaryCard(
      eyebrow: 'Executive summary',
      headline: r.elevatedCount == 0
          ? 'No personnel are currently in the elevated band.'
          : '${r.elevatedCount} of ${r.totalEvaluated} personnel are in the elevated band.',
      body:
          'Composite wellbeing index sits at ${kWellbeingIndexTrend.last.toStringAsFixed(1)}/100, '
          '${trendDown ? 'down' : 'up'} ${kWellbeingIndexDelta.abs().toStringAsFixed(1)} points across the 12-week window. '
          'Every flag below requires clinician sign-off before any outreach.',
      bullets: [
        '${worst.name} carries the highest strain (${worst.severity.toStringAsFixed(0)}/100, ${worst.elevated} elevated of ${worst.headcount}).',
        '${kTopStrainDrivers.keys.first} is the most frequent top factor, appearing in ${kTopStrainDrivers.values.first.toStringAsFixed(0)}% of flagged cases.',
        '$kAwaitingClinicalReview cases await review; $kOutreachCompleted outreaches completed this cycle.',
        '${elevatedPct.toStringAsFixed(1)}% of the scored cohort is elevated.',
      ],
      footnote:
          'Tokens only: no names, Service IDs or raw scores are rendered on this board.',

    );
  }

  Widget _indices(BatchRiskResult r) {
    return TileGrid(
      children: [
        IndexTile(
          label: 'Cohort evaluated',
          value: '${r.totalEvaluated}',
          hint: 'pseudonymized tokens',
          icon: Icons.groups_outlined,
          accent: AppColors.primary,
        ),
        IndexTile(
          label: 'Elevated band',
          value: '${r.elevatedCount}',
          hint: 'needs clinical review',
          icon: Icons.priority_high_rounded,
          accent: AppColors.error,
          delta: kElevatedShareTrend.last - kElevatedShareTrend.first,
          deltaGoodWhenNegative: true,
        ),
        IndexTile(
          label: 'Wellbeing index',
          value: kWellbeingIndexTrend.last.toStringAsFixed(1),
          hint: '100 = best · 12-week composite',
          icon: Icons.insights_outlined,
          accent: AppColors.secondary,
          delta: kWellbeingIndexDelta,
        ),
        IndexTile(
          label: 'Awaiting review',
          value: '$kAwaitingClinicalReview',
          hint: '$kReviewedThisCycle reviewed this cycle',
          icon: Icons.pending_actions_outlined,
          accent: const Color(0xFFB26A00),
        ),
      ],
    );
  }

  Widget _distribution(BatchRiskResult r) {
    return ChartCard(
      title: 'Risk band distribution',
      description: 'Where the scored cohort currently sits',
      child: StackedShareBar(
        segments: [
          ShareSegment('Low', r.lowCount, AppColors.statusPositive),
          ShareSegment('Moderate', r.moderateCount, AppColors.statusCaution),
          ShareSegment('Elevated', r.elevatedCount, AppColors.statusDistress),
        ],
      ),
    );
  }

  Widget _trend() {
    return ChartCard(
      title: 'Composite wellbeing index',
      description: '12-week trend · higher is better',
      trailing: DeltaBadge(kWellbeingIndexDelta),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrendChart(values: kWellbeingIndexTrend),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('Elevated share of cohort',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
              DeltaBadge(
                  kElevatedShareTrend.last - kElevatedShareTrend.first,
                  suffix: '%',
                  goodWhenNegative: true),
            ],
          ),
          const SizedBox(height: 8),
          TrendChart(
              values: kElevatedShareTrend,
              height: 42,
              color: AppColors.statusDistress),
        ],
      ),
    );
  }

  Widget _units() {
    return ChartCard(
      title: 'Unit severity ranking',
      description: 'Peak domain severity by unit · aggregates only',
      child: RankedBarChart(
        maxValue: 100,
        rows: [
          for (final u in kUnitRisk)
            RankedRow(
              u.name,
              u.severity,
              caption:
                  '${u.unitCode} · ${u.elevated} elevated of ${u.headcount} · '
                  '${u.delta >= 0 ? '+' : ''}${u.delta.toStringAsFixed(1)} wk/wk',
              color: u.severity >= 65
                  ? AppColors.statusDistress
                  : u.severity >= 45
                      ? AppColors.statusCaution
                      : AppColors.statusPositive,
            ),
        ],
      ),
    );
  }

  Widget _drivers() {
    return ChartCard(
      title: 'Top strain drivers',
      description: 'How often each appears as a top factor in flagged cases',
      child: RankedBarChart(
        maxValue: 100,
        valueSuffix: '%',
        rows: [
          for (final e in kTopStrainDrivers.entries)
            RankedRow(e.key, e.value, color: AppColors.primaryContainer),
        ],
      ),
    );
  }

  Widget _caseCard(RiskAssessment a) {
    final color = _bandColor(a.riskBand);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shield_outlined, size: 18, color: color),
            ),
            title: Text(a.pseudonymToken,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            subtitle: Text(
              '${a.riskBand.displayName} band · confidence ${(a.confidence * 100).round()}%',
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.onSurfaceVariant),
            ),
            trailing: StatusPill(
              label: a.riskBand.displayName,
              fg: color,
              bg: color.withOpacity(0.14),
            ),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('CONTRIBUTING FACTORS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.onSurfaceVariant)),
              ),
              const SizedBox(height: 8),
              for (final f in a.topFactors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(f.displayTitle,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ),
                          Text('${(f.importanceWeight * 100).round()}%',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: f.importanceWeight.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(f.contextDetail,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD5E5D8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RECOMMENDED SUPPORT PATHWAY',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.secondary)),
                    const SizedBox(height: 4),
                    Text(a.recommendedSupportPathway,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _provenance(BatchRiskResult r) {
    final version =
        r.results.isNotEmpty ? r.results.first.modelVersion : 'unknown';
    return ChartCard(
      title: 'Model provenance',
      description: 'Required alongside every scored board (PRD §5)',
      child: Column(
        children: [
          _kv('Scoring source',
              _ml.isOnline ? 'Live ML microservice' : 'On-device fallback heuristics'),
          _kv('Model version', version),
          _kv('Cohort', '${r.totalEvaluated} pseudonymized tokens'),
          _kv('Trend & unit aggregates', 'Fixed demo data'),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: AppColors.onSurfaceVariant),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'A band is never an outcome on its own. Clinical review decides every intervention.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ],
        ),
      );
}
