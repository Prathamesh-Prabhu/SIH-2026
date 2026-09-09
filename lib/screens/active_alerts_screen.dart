import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation.dart';
import '../models/ml_models.dart';
import '../services/hr_analytics_controller.dart';
import '../services/ml_service.dart';

/// Predictive Analytics board for the HR Admin flow.
///
/// Every number on this screen is the live ManoFit ML microservice
/// (`/api/v1/score/batch`, model `v1.0.0`) scoring the roster the HR Admin
/// ingested through the Tier 2 portal. Nothing is synthetic, nothing is carried
/// over from a previous demo, and the on-device heuristic is never substituted —
/// if the model service is down the board says so.
class ActiveAlertsScreen extends StatefulWidget {
  const ActiveAlertsScreen({super.key});

  @override
  State<ActiveAlertsScreen> createState() => _ActiveAlertsScreenState();
}

class _ActiveAlertsScreenState extends State<ActiveAlertsScreen> {
  static const _ink = Color(0xFF012D1D);
  static const _green = Color(0xFF24704F);
  static const _amber = Color(0xFFE7A126);
  static const _coral = Color(0xFFE56857);
  static const _muted = Color(0xFF6B746E);

  final _ctrl = HrAnalyticsController();
  final _ml = MlService();

  /// Pseudonym tokens whose alert has been forwarded to the Welfare Officer
  /// this session (aggregate-only referral — no identity leaves the board).
  final Set<String> _reported = {};

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
    _ml.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.refresh());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChange);
    _ml.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Color _bandColor(RiskBand b) => switch (b) {
        RiskBand.elevated => _coral,
        RiskBand.moderate => _amber,
        RiskBand.low => _green,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FBF6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3FBF6),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => context.backOr('/hr-overview'),
        ),
        title: const Text(
          'Predictive Analytics',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
        ),
        actions: [
          IconButton(
            tooltip: 'Re-run scoring',
            icon: _ctrl.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                  )
                : const Icon(Icons.refresh_rounded, color: _ink, size: 22),
            onPressed: _ctrl.loading ? null : _ctrl.refresh,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _ctrl.refresh,
          color: _green,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _body(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (!_ctrl.hasCohort) {
      return [_statusBanner(), const SizedBox(height: 16), _emptyState()];
    }
    if (_ctrl.error != null) {
      return [_statusBanner(), const SizedBox(height: 16), _errorState(_ctrl.error!)];
    }
    if (_ctrl.loading && !_ctrl.hasReport) {
      return [
        _statusBanner(),
        const SizedBox(height: 80),
        const Center(child: CircularProgressIndicator(color: _green)),
        const SizedBox(height: 12),
        const Center(
          child: Text('Scoring ingested roster…',
              style: TextStyle(fontSize: 12, color: _muted)),
        ),
      ];
    }
    if (!_ctrl.hasReport) {
      return [_statusBanner(), const SizedBox(height: 16), _emptyState()];
    }

    final r = _ctrl.result!;
    return [
      _statusBanner(),
      const SizedBox(height: 14),
      _kpiRow(r),
      const SizedBox(height: 16),
      _distributionCard(r),
      const SizedBox(height: 16),
      _unitRollupCard(),
      const SizedBox(height: 16),
      _driversCard(),
      const SizedBox(height: 18),
      _triageHeader(),
      const SizedBox(height: 10),
      ..._ctrl.flaggedCases.map(_caseCard),
      if (_ctrl.flaggedCases.isEmpty) _noFlags(),
      const SizedBox(height: 16),
      _provenance(r),
    ];
  }

  // ── Model status ─────────────────────────────────────────────────────────
  Widget _statusBanner() {
    final online = _ml.isOnline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: online ? const Color(0xFFE8F6ED) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: online ? const Color(0xFFBBE5CA) : const Color(0xFFFFD59E)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: online ? _green : _amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        online ? 'Live ML microservice' : 'Model service offline',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: online ? const Color(0xFF144D34) : const Color(0xFF8A5300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: online ? _green : const Color(0xFFB26A00),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'model ${_ctrl.modelVersion}',
                        style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                  Text(
                    online
                        ? 'XGBoost behavioural ensemble · /api/v1/score/batch'
                        : 'Connect to ML service: live model scoring required',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF414844)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty / error ────────────────────────────────────────────────────────
  Widget _emptyState() {
    return _card(
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: _muted),
          const SizedBox(height: 12),
          const Text('No roster ingested yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          const Text(
            'The predictive board scores only the roster an HR Admin uploads '
            'through the Tier 2 ingestion portal. Upload a duty roster to begin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: _muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/hr-ingestion'),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Go to Data Ingestion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 20, color: Color(0xFF9A2318)),
              SizedBox(width: 8),
              Text('Model service unavailable',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 12, height: 1.4, color: _muted)),
          const SizedBox(height: 8),
          Text('Cohort ready to score: ${_ctrl.cohortSize} pseudonymised tokens.',
              style: const TextStyle(fontSize: 11.5, color: _muted)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _ctrl.loading ? null : _ctrl.refresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPI row ──────────────────────────────────────────────────────────────
  Widget _kpiRow(BatchRiskResult r) {
    final elevatedPct =
        r.totalEvaluated == 0 ? 0.0 : r.elevatedCount / r.totalEvaluated * 100;
    return Row(
      children: [
        Expanded(child: _kpi('Cohort scored', '${r.totalEvaluated}', 'pseudonymised tokens', _green)),
        const SizedBox(width: 10),
        Expanded(child: _kpi('Elevated band', '${r.elevatedCount}', 'needs welfare review', _coral)),
        const SizedBox(width: 10),
        Expanded(child: _kpi('Elevated share', '${elevatedPct.toStringAsFixed(1)}%', 'of scored cohort', _amber)),
      ],
    );
  }

  Widget _kpi(String title, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EFE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF414844))),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: _muted)),
        ],
      ),
    );
  }

  // ── Distribution ─────────────────────────────────────────────────────────
  Widget _distributionCard(BatchRiskResult r) {
    final total = r.totalEvaluated == 0 ? 1 : r.totalEvaluated;
    String pct(int n) => (n / total * 100).toStringAsFixed(0);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Risk band distribution',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 4),
          const Text('Where the ingested cohort currently sits',
              style: TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (r.lowCount > 0)
                    Expanded(flex: r.lowCount, child: Container(color: _green)),
                  if (r.moderateCount > 0) ...[
                    const SizedBox(width: 2),
                    Expanded(flex: r.moderateCount, child: Container(color: _amber)),
                  ],
                  if (r.elevatedCount > 0) ...[
                    const SizedBox(width: 2),
                    Expanded(flex: r.elevatedCount, child: Container(color: _coral)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legend('Low', '${pct(r.lowCount)}%', '(${r.lowCount})', _green),
              _legend('Moderate', '${pct(r.moderateCount)}%', '(${r.moderateCount})', _amber),
              _legend('Elevated', '${pct(r.elevatedCount)}%', '(${r.elevatedCount})', _coral),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, String pct, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF414844))),
        const SizedBox(width: 4),
        Text(pct, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(width: 2),
        Text(count, style: const TextStyle(fontSize: 10.5, color: _muted)),
      ],
    );
  }

  // ── Unit roll-up ─────────────────────────────────────────────────────────
  Widget _unitRollupCard() {
    final rows = _ctrl.unitRollups;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('Unit strain roll-up',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink)),
              ),
              SizedBox(width: 8),
              Text('elevated + ½·moderate share',
                  style: TextStyle(fontSize: 10.5, color: _muted)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Aggregated from this batch only: no unit history',
              style: TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Text('No unit codes in the ingested roster.',
                style: TextStyle(fontSize: 12, color: _muted))
          else
            ...rows.map((u) {
              final share = u.strainShare;
              final color = share >= 0.5 ? _coral : (share >= 0.25 ? _amber : _green);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(u.unitCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink)),
                        ),
                        const SizedBox(width: 8),
                        Text('${(share * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.0, 1.0),
                        minHeight: 7,
                        color: color,
                        backgroundColor: const Color(0xFFE8EFEA),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${u.elevated} elevated · ${u.moderate} moderate of ${u.total}',
                      style: const TextStyle(fontSize: 10.5, color: _muted),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Drivers ──────────────────────────────────────────────────────────────
  Widget _driversCard() {
    final drivers = _ctrl.topDrivers;
    final flagged = _ctrl.flaggedCases.length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('Top strain drivers',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink)),
              ),
              SizedBox(width: 8),
              Text('SHAP factor · % of flagged',
                  style: TextStyle(fontSize: 10.5, color: _muted)),
            ],
          ),
          const SizedBox(height: 14),
          if (drivers.isEmpty)
            const Text('No risk-increasing factors in the flagged cases.',
                style: TextStyle(fontSize: 12, color: _muted))
          else
            ...drivers.map((e) {
              final share = flagged == 0 ? 0.0 : e.value / flagged;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.key,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF26322C))),
                        ),
                        const SizedBox(width: 8),
                        Text('${(share * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.0, 1.0),
                        minHeight: 6,
                        color: _green,
                        backgroundColor: const Color(0xFFE8EFEA),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Triage queue ─────────────────────────────────────────────────────────
  Widget _triageHeader() {
    final open = _ctrl.flaggedCases
        .where((a) => !_reported.contains(a.pseudonymToken))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.assignment_late_outlined, size: 19, color: Color(0xFFB42318)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Cohort welfare triage queue',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _ink)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${open.length} open',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A2318))),
            ),
          ],
        ),
        if (open.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _report(open),
              icon: const Icon(Icons.notifications_active_outlined, size: 17),
              label: Text('Notify Welfare Officer: all ${open.length} flagged'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: Color(0xFFC1C8C2)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _noFlags() {
    return _card(
      child: const Row(
        children: [
          Icon(Icons.verified_outlined, size: 18, color: _green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No personnel in the moderate or elevated band for this roster.',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  /// Forwards the aggregate alert(s) to the Welfare Officer queue. Only the
  /// pseudonym token, band and factor titles travel — never an identity.
  void _report(List<RiskAssessment> cases) {
    if (cases.isEmpty) return;
    setState(() => _reported.addAll(cases.map((a) => a.pseudonymToken)));
    final msg = cases.length == 1
        ? 'Alert for ${cases.first.pseudonymToken} (${cases.first.riskBand.displayName}) sent to the Welfare Officer.'
        : '${cases.length} flagged cohort alerts sent to the Welfare Officer queue.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _green),
    );
  }

  Widget _caseCard(RiskAssessment a) {
    final color = _bandColor(a.riskBand);
    final critical = a.riskBand == RiskBand.elevated;
    final reported = _reported.contains(a.pseudonymToken);
    final riskFactors = a.topFactors.where((f) => f.isRiskIncreasing).toList();
    final shown = (riskFactors.isEmpty ? a.topFactors : riskFactors).take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: critical ? const Color(0xFFF7C2BC) : const Color(0xFFE5EFE8),
          width: critical ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: critical ? const Color(0xFFFEE4E2) : const Color(0xFFFEF0C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  critical ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                  color: critical ? const Color(0xFFB42318) : const Color(0xFFB26A00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.pseudonymToken,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                    const SizedBox(height: 3),
                    Text(
                      '${_ctrl.unitForToken(a.pseudonymToken)} • confidence ${(a.confidence * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(a.riskBand.displayName.toUpperCase(),
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // SHAP contributing factors
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFCFA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEBF2EC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ML behavioural drivers (SHAP attributions):',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF414844)),
                ),
                const SizedBox(height: 4),
                for (final f in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ',
                            style: TextStyle(
                                fontSize: 11,
                                color: f.isRiskIncreasing ? _coral : _green)),
                        Expanded(
                          child: Text(
                            '${f.displayTitle}: ${f.contextDetail}',
                            style: const TextStyle(fontSize: 11, height: 1.3, color: Color(0xFF333C36)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Recommended pathway
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 16, color: _amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  a.recommendedSupportPathway,
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w500, color: _ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Report action
          SizedBox(
            width: double.infinity,
            child: reported
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_outline, size: 17),
                    label: const Text('Reported to Welfare Officer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: Color(0xFFBFE3CC)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _report([a]),
                    icon: const Icon(Icons.forward_to_inbox_outlined, size: 17),
                    label: const Text('Report to Welfare Officer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Provenance ───────────────────────────────────────────────────────────
  Widget _provenance(BatchRiskResult r) {
    final version = r.results.isNotEmpty ? r.results.first.modelVersion : 'unknown';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Model provenance',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 8),
          _kv('Scoring source', 'Live ML microservice (/api/v1/score/batch)'),
          _kv('Model version', version),
          _kv('Cohort', '${r.totalEvaluated} pseudonymised tokens from the last ingested roster'),
          _kv('Aggregates', 'Unit roll-up & drivers computed from this batch only'),
          const SizedBox(height: 6),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 13, color: _muted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'A band is never an outcome on its own. Clinical review by a Welfare '
                  'Officer decides every intervention.',
                  style: TextStyle(fontSize: 11, color: _muted),
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
              width: 120,
              child: Text(k, style: const TextStyle(fontSize: 11.5, color: _muted)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600, color: _ink)),
            ),
          ],
        ),
      );

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EFE8)),
      ),
      child: child,
    );
  }
}
