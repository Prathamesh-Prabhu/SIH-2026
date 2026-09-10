import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/org_wellbeing.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/hr_analytics_controller.dart';
import '../services/ml_service.dart';

/// HR Admin console home.
///
/// Aggregate roll-ups only, and only for the roster the HR Admin actually
/// ingested — no synthetic cohort, no demo trends. Band counts come from the
/// live ML microservice via [HrAnalyticsController]. Individual triage lives on
/// the Predictive Analytics board (`/active-alerts`).
class HrAdminOverviewScreen extends StatefulWidget {
  const HrAdminOverviewScreen({super.key});

  static const _canvas = Color(0xFFF3FBF6);
  static const _ink = Color(0xFF012D1D);
  static const _muted = Color(0xFF414844);
  static const _panel = Color(0xFFFFFFFF);
  static const _green = Color(0xFF24704F);
  static const _amber = Color(0xFFE7A126);
  static const _coral = Color(0xFFE56857);

  @override
  State<HrAdminOverviewScreen> createState() => _HrAdminOverviewScreenState();
}

class _HrAdminOverviewScreenState extends State<HrAdminOverviewScreen> {
  final _ctrl = HrAnalyticsController();
  final _db = DbService();
  final _ml = MlService();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
    _ml.addListener(_onChange);
    _db.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.refresh());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChange);
    _ml.removeListener(_onChange);
    _db.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (mounted) context.go('/landing');
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService().currentUser?.fullName ?? 'HR Administrator';
    final summary = _db.hrCohortSummary;

    return Scaffold(
      backgroundColor: HrAdminOverviewScreen._canvas,
      appBar: AppBar(
        backgroundColor: HrAdminOverviewScreen._canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 14,
        title: const _Brand(),
        actions: [
          IconButton(
            tooltip: 'Re-run scoring',
            onPressed: _ctrl.loading ? null : _ctrl.refresh,
            icon: _ctrl.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: HrAdminOverviewScreen._green),
                  )
                : const Icon(Icons.refresh_rounded, color: HrAdminOverviewScreen._ink),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: HrAdminOverviewScreen._ink),
            onSelected: (v) {
              if (v == 'privacy') _showGovernance(context);
              if (v == 'logout') _logout();
              if (v == 'profile') context.push('/profile');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuItem(value: 'privacy', child: Text('Data governance')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _ctrl.refresh,
          color: HrAdminOverviewScreen._green,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                children: [
                  _hero(name),
                  const SizedBox(height: 16),
                  _cohortStrip(summary),
                  const SizedBox(height: 16),
                  if (!_ctrl.hasCohort)
                    _ingestPrompt()
                  else if (_ctrl.error != null)
                    _offlineCard(_ctrl.error!)
                  else if (_ctrl.loading && !_ctrl.hasReport)
                    _loadingCard()
                  else if (_ctrl.hasReport) ...[
                    _alertsCard(),
                    const SizedBox(height: 16),
                    _distributionCard(),
                  ] else
                    _ingestPrompt(),
                  const SizedBox(height: 16),
                  _orgWellbeingCard(),
                  const SizedBox(height: 16),
                  _participationCard(),
                  const SizedBox(height: 16),
                  _actions(),
                  const SizedBox(height: 16),
                  _privacyNotice(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        onIngestion: () => context.push('/hr-ingestion'),
        onAnalytics: () => context.push('/active-alerts'),
        onProfile: () => context.push('/profile'),
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────
  Widget _hero(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2EDE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Building a Healthier Force',
            style: TextStyle(
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: HrAdminOverviewScreen._ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text('People. Preparedness. Purpose.',
              style: TextStyle(fontSize: 14, color: HrAdminOverviewScreen._ink)),
          const SizedBox(height: 14),
          Text('Signed in as $name',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: HrAdminOverviewScreen._muted)),
        ],
      ),
    );
  }

  // ── Cohort strip ─────────────────────────────────────────────────────────
  Widget _cohortStrip(Map<String, dynamic> summary) {
    final personnel = summary['personnel'] as int? ?? 0;
    final units = summary['units'] as int? ?? 0;

    return _panel(
      child: Row(
        children: [
          Expanded(child: _stat('$personnel', 'Personnel in DB')),
          _divider(),
          Expanded(child: _stat('$units', 'Units')),
          _divider(),
          Expanded(
            child: _stat(
              _ml.isOnline ? 'Online' : 'Offline',
              'Model service',
              color: _ml.isOnline ? HrAdminOverviewScreen._green : HrAdminOverviewScreen._amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, {Color? color}) {
    return Column(
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color ?? HrAdminOverviewScreen._ink)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: HrAdminOverviewScreen._muted)),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: const Color(0xFFE2EDE6),
      );

  // ── States ───────────────────────────────────────────────────────────────
  Widget _ingestPrompt() {
    return _panel(
      child: Column(
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 38, color: HrAdminOverviewScreen._green),
          const SizedBox(height: 10),
          const Text('Ingest a duty roster to begin',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HrAdminOverviewScreen._ink)),
          const SizedBox(height: 6),
          const Text(
            'The console reports only on rosters you upload. Nothing is scored '
            'until a CSV or Excel roster is ingested.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: HrAdminOverviewScreen._muted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/hr-ingestion'),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Open Data Ingestion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HrAdminOverviewScreen._green,
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

  Widget _offlineCard(String message) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFF9A2318)),
              SizedBox(width: 8),
              Text('Model service unavailable',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: HrAdminOverviewScreen._ink)),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontSize: 12, height: 1.4, color: HrAdminOverviewScreen._muted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _ctrl.loading ? null : _ctrl.refresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HrAdminOverviewScreen._green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
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

  Widget _loadingCard() {
    return _panel(
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            CircularProgressIndicator(color: HrAdminOverviewScreen._green),
            SizedBox(height: 12),
            Text('Scoring ingested roster…',
                style: TextStyle(fontSize: 12, color: HrAdminOverviewScreen._muted)),
          ],
        ),
      ),
    );
  }

  // ── Alerts card ──────────────────────────────────────────────────────────
  Widget _alertsCard() {
    final r = _ctrl.result!;
    final elevated = r.elevatedCount;
    return Material(
      color: elevated > 0 ? const Color(0xFFFFE1DE) : const Color(0xFFE8F6ED),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push('/active-alerts'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                elevated > 0 ? Icons.warning_amber_rounded : Icons.verified_outlined,
                color: elevated > 0 ? const Color(0xFFB42318) : HrAdminOverviewScreen._green,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elevated > 0 ? 'Active alerts' : 'No elevated cases',
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700, color: HrAdminOverviewScreen._ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.moderateCount + r.elevatedCount} of ${r.totalEvaluated} personnel flagged for welfare review',
                      style: const TextStyle(fontSize: 11.5, color: HrAdminOverviewScreen._muted),
                    ),
                  ],
                ),
              ),
              Text('$elevated',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, color: HrAdminOverviewScreen._ink)),
              const Icon(Icons.chevron_right_rounded, color: HrAdminOverviewScreen._ink),
            ],
          ),
        ),
      ),
    );
  }

  // ── Distribution card ────────────────────────────────────────────────────
  Widget _distributionCard() {
    final r = _ctrl.result!;
    final total = r.totalEvaluated == 0 ? 1 : r.totalEvaluated;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wellbeing risk distribution',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HrAdminOverviewScreen._ink)),
          const SizedBox(height: 4),
          Text('$total personnel scored by model ${_ctrl.modelVersion}',
              style: const TextStyle(fontSize: 11, color: HrAdminOverviewScreen._muted)),
          const SizedBox(height: 18),
          Row(
            children: [
              _Donut(low: r.lowCount, moderate: r.moderateCount, elevated: r.elevatedCount),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow('Low', r.lowCount, total, HrAdminOverviewScreen._green),
                    const SizedBox(height: 10),
                    _legendRow('Moderate', r.moderateCount, total, HrAdminOverviewScreen._amber),
                    const SizedBox(height: 10),
                    _legendRow('Elevated', r.elevatedCount, total, HrAdminOverviewScreen._coral),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendRow(String label, int n, int total, Color color) {
    final pct = (n / total * 100).toStringAsFixed(0);
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: HrAdminOverviewScreen._ink)),
        ),
        Text('$pct%',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HrAdminOverviewScreen._ink)),
        const SizedBox(width: 5),
        Text('($n)', style: const TextStyle(fontSize: 12, color: HrAdminOverviewScreen._muted)),
      ],
    );
  }

  // ── Organisation wellbeing ───────────────────────────────────────────────
  Widget _orgWellbeingCard() {
    final report = computeOrgWellbeing(_db.anonymousCheckIns);
    final deepDive = computeDeepDive(_db.anonymousDeepDiveResponses);

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_border_rounded, size: 18, color: HrAdminOverviewScreen._green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Organisation wellbeing',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HrAdminOverviewScreen._ink)),
              ),
              if (report.sampleSize > 0)
                Text('${report.sampleSize} check-ins',
                    style: const TextStyle(fontSize: 10.5, color: HrAdminOverviewScreen._muted)),
            ],
          ),
          const SizedBox(height: 16),
          if (report.index == null)
            Text(
              'Needs $kMinOrgSample+ anonymous check-ins (${report.sampleSize} so far).',
              style: const TextStyle(fontSize: 12, color: HrAdminOverviewScreen._muted),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _IndexRing(
                    value: report.index!,
                    color: report.bandColor,
                    band: report.band),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final c in report.concerns.take(3)) _concernBar(c),
                    ],
                  ),
                ),
              ],
            ),
            for (final c in report.concerns.skip(3)) _concernBar(c),
            if (deepDive.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(height: 1, color: const Color(0xFFE2EDE6)),
              const SizedBox(height: 10),
              const Text('Monthly deep-dive',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: HrAdminOverviewScreen._muted)),
              const SizedBox(height: 10),
              for (final c in deepDive.take(4)) _concernBar(c),
            ],
          ],
        ],
      ),
    );
  }

  Widget _concernBar(WellbeingConcern c) {
    final color = c.rate >= 0.5
        ? HrAdminOverviewScreen._coral
        : (c.rate >= 0.25 ? HrAdminOverviewScreen._amber : HrAdminOverviewScreen._green);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HrAdminOverviewScreen._ink)),
              ),
              const SizedBox(width: 8),
              Text('${c.pct}%',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: c.rate.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: const Color(0xFFE8EFEA),
            ),
          ),
        ],
      ),
    );
  }

  // ── Check-in participation ───────────────────────────────────────────────
  Widget _participationCard() {
    final counts = _db.checkInCountsByCadence;
    final daily = counts['daily'] ?? 0;
    final weekly = counts['weekly'] ?? 0;
    final monthly = counts['monthly'] ?? 0;
    final series = _db.checkInsPerDay(days: 14);
    final total = daily + weekly + monthly;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined,
                  size: 18, color: HrAdminOverviewScreen._green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Check-in participation',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HrAdminOverviewScreen._ink)),
              ),
              Text('$total total',
                  style: const TextStyle(
                      fontSize: 10.5, color: HrAdminOverviewScreen._muted)),
            ],
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const Text('No check-ins submitted yet.',
                style: TextStyle(
                    fontSize: 12, color: HrAdminOverviewScreen._muted))
          else ...[
            _CountBars(rows: [
              _CountRow('Daily', daily, HrAdminOverviewScreen._green),
              _CountRow('Weekly', weekly, HrAdminOverviewScreen._amber),
              _CountRow('Monthly', monthly, const Color(0xFF6A4C93)),
            ]),
            const SizedBox(height: 18),
            const Text('LAST 14 DAYS',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: HrAdminOverviewScreen._muted)),
            const SizedBox(height: 8),
            _LineChart(values: series, color: HrAdminOverviewScreen._green),
          ],
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            icon: Icons.cloud_upload_outlined,
            label: 'Data Ingestion',
            sub: 'Upload CSV / Excel roster',
            onTap: () => context.push('/hr-ingestion'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(
            icon: Icons.query_stats_rounded,
            label: 'Predictive Analytics',
            sub: 'Model risk report',
            onTap: () => context.push('/active-alerts'),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7F0EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: HrAdminOverviewScreen._green),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: HrAdminOverviewScreen._ink)),
              const SizedBox(height: 3),
              Text(sub, style: const TextStyle(fontSize: 10.5, color: HrAdminOverviewScreen._muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _privacyNotice() {
    return Material(
      color: const Color(0xFFEAF3ED),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _showGovernance(context),
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: HrAdminOverviewScreen._green, size: 20),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Rosters are pseudonymised (SHA-256) on ingestion. HR Admins see '
                  'aggregate cohort roll-ups only: individual casework is the '
                  'Welfare Officer\'s remit.',

                  style: TextStyle(fontSize: 11.5, height: 1.35, color: HrAdminOverviewScreen._muted),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: HrAdminOverviewScreen._green),
            ],
          ),
        ),
      ),
    );
  }

  void _showGovernance(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => const Padding(
        padding: EdgeInsets.fromLTRB(22, 6, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Institutional data governance',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HrAdminOverviewScreen._ink)),
            SizedBox(height: 12),
            Text(
              '• Tier 2 pseudonymisation: Service IDs are SHA-256 hashed at ingestion; '
              'the raw identifier is never stored.\n\n'
              '• Aggregate-only: HR Admins see cohort band counts and unit roll-ups, '
              'never an individual stress score or identity.\n\n'
              '• Welfare separation: only licensed Welfare Officers open individual '
              'risk output and counselling casework.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: HrAdminOverviewScreen._muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HrAdminOverviewScreen._panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7F0EB)),
      ),
      child: child,
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.health_and_safety_outlined, size: 21, color: HrAdminOverviewScreen._green),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('ManoFit',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HrAdminOverviewScreen._ink)),
              Text('HR ADMIN CONSOLE',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                      color: HrAdminOverviewScreen._muted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular gauge for the 0–100 organisation wellbeing index.
class _IndexRing extends StatelessWidget {
  const _IndexRing({required this.value, required this.color, required this.band});

  final int value;
  final Color color;
  final String band;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(92),
            painter: _RingPainter(value / 100, color),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: HrAdminOverviewScreen._ink,
                      height: 1)),
              const SizedBox(height: 2),
              Text(band,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE8EFEA);
    canvas.drawArc(rect, 0, 2 * math.pi, false, bg);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0),
        false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

// ── Participation charts ─────────────────────────────────────────────────
class _CountRow {
  const _CountRow(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

/// Horizontal bar chart of check-in counts by cadence.
class _CountBars extends StatelessWidget {
  const _CountBars({required this.rows});
  final List<_CountRow> rows;

  @override
  Widget build(BuildContext context) {
    final peak = rows.fold<int>(1, (m, r) => r.value > m ? r.value : m);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(r.label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HrAdminOverviewScreen._ink)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (r.value / peak).clamp(0.0, 1.0),
                      minHeight: 12,
                      color: r.color,
                      backgroundColor: const Color(0xFFEDF2EE),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 24,
                  child: Text('${r.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: HrAdminOverviewScreen._ink)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small filled line chart of a daily count series.
class _LineChart extends StatelessWidget {
  const _LineChart({required this.values, required this.color});
  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: CustomPaint(
          painter: _LinePainter(
              [for (final v in values) v.toDouble()], color)),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max).clamp(1.0, double.infinity);
    final dx = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    Offset at(int i) =>
        Offset(dx * i, size.height - (values[i] / maxV) * (size.height - 6) - 3);

    final baseline = size.height;
    final fill = Path()..moveTo(0, baseline);
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    fill.lineTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
      fill.lineTo(at(i).dx, at(i).dy);
    }
    fill
      ..lineTo(size.width, baseline)
      ..close();

    canvas.drawPath(
        fill,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withOpacity(0.12));
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = color);

    final dot = Paint()..color = color;
    canvas.drawCircle(at(values.length - 1), 3, dot);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.color != color;
}

class _Donut extends StatelessWidget {
  const _Donut({required this.low, required this.moderate, required this.elevated});
  final int low;
  final int moderate;
  final int elevated;

  @override
  Widget build(BuildContext context) {
    final total = low + moderate + elevated;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(120),
            painter: _DonutPainter(low: low, moderate: moderate, elevated: elevated),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$total',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: HrAdminOverviewScreen._ink)),
              const Text('scored', style: TextStyle(fontSize: 10, color: HrAdminOverviewScreen._muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.low, required this.moderate, required this.elevated});
  final int low;
  final int moderate;
  final int elevated;

  @override
  void paint(Canvas canvas, Size size) {
    final total = (low + moderate + elevated).toDouble();
    final rect = Rect.fromLTWH(11, 11, size.width - 22, size.height - 22);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..color = const Color(0xFFE8EFEA);
    canvas.drawArc(rect, 0, 2 * math.pi, false, bg);
    if (total == 0) return;

    final segments = [
      (low, const Color(0xFF24704F)),
      (moderate, const Color(0xFFE7A126)),
      (elevated, const Color(0xFFE56857)),
    ];
    var start = -math.pi / 2;
    for (final (value, color) in segments) {
      if (value == 0) continue;
      final sweep = 2 * math.pi * value / total - 0.03;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.butt
        ..color = color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep + 0.03;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.low != low || old.moderate != moderate || old.elevated != elevated;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.onIngestion,
    required this.onAnalytics,
    required this.onProfile,
  });

  final VoidCallback onIngestion;
  final VoidCallback onAnalytics;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE4EDE8))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(Icons.dashboard_rounded, 'Home', () {}, active: true),
              _item(Icons.cloud_upload_outlined, 'Ingestion', onIngestion),
              _item(Icons.query_stats_outlined, 'Analytics', onAnalytics),
              _item(Icons.person_outline_rounded, 'Profile', onProfile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
    final color = active ? const Color(0xFF24704F) : const Color(0xFF6B746E);
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
