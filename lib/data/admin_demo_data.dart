/// Hardcoded console data for the HR Admin and Welfare Risk consoles.
///
/// The risk *bands* themselves come from the scoring pipeline (live ML service
/// when reachable, `MlService._fallbackBatch` heuristics otherwise). What lives
/// here is everything the scorer does not return but the dashboards need to be
/// legible: historical trend, unit-level aggregates, ingestion telemetry.
///
/// Deliberately fixed rather than random so demos are reproducible and two
/// people looking at the board see the same numbers.
library;

// ── Welfare Risk Analytics ─────────────────────────────────────────────────

/// Composite unit-wellbeing index, 12 weekly points, 0–100 (higher = better).
const List<double> kWellbeingIndexTrend = [
  74.2, 73.6, 72.1, 72.8, 70.4, 69.1,
  68.3, 69.7, 71.2, 70.8, 72.4, 73.1,
];

/// Change in the wellbeing index against the start of the window.
double get kWellbeingIndexDelta =>
    kWellbeingIndexTrend.last - kWellbeingIndexTrend.first;

/// Share of the cohort in the elevated band, same 12-week window (%).
const List<double> kElevatedShareTrend = [
  8.4, 9.1, 10.6, 10.2, 12.8, 13.9,
  14.6, 13.2, 11.9, 12.4, 10.7, 9.8,
];

class UnitRisk {
  const UnitRisk({
    required this.unitCode,
    required this.name,
    required this.severity,
    required this.headcount,
    required this.elevated,
    required this.delta,
  });

  final String unitCode;
  final String name;

  /// Peak domain severity 0–100 (higher = more strain).
  final double severity;
  final int headcount;
  final int elevated;

  /// Week-on-week change in severity.
  final double delta;
}

/// Unit aggregates — never individual names (PRD §8.2: commanders and welfare
/// officers see cohort roll-ups, re-identification is a separate two-person
/// protocol).
const List<UnitRisk> kUnitRisk = [
  UnitRisk(
      unitCode: 'UNIT-104',
      name: 'Northern Sector · Outpost Coy',
      severity: 71,
      headcount: 42,
      elevated: 6,
      delta: 4.2),
  UnitRisk(
      unitCode: 'UNIT-101',
      name: 'Northern Sector · HQ Coy',
      severity: 58,
      headcount: 61,
      elevated: 4,
      delta: 1.1),
  UnitRisk(
      unitCode: 'UNIT-106',
      name: 'Eastern Sector · CI Ops',
      severity: 54,
      headcount: 38,
      elevated: 3,
      delta: -2.4),
  UnitRisk(
      unitCode: 'UNIT-102',
      name: 'Western Sector · Border Post',
      severity: 43,
      headcount: 55,
      elevated: 2,
      delta: -0.8),
  UnitRisk(
      unitCode: 'UNIT-103',
      name: 'Eastern Sector · Training Wing',
      severity: 31,
      headcount: 47,
      elevated: 1,
      delta: -3.6),
];

/// Strain drivers ranked by how often they appear as a top factor across the
/// flagged cohort (%). Mirrors mindspace's DriverAnalysis ranking.
const Map<String, double> kTopStrainDrivers = {
  'Consecutive duty days without rest': 68,
  'Sustained physical exhaustion': 61,
  'Leave accrued but never taken': 47,
  'Low peer social support': 39,
  'Frequent redeployment (3+ / 12 mo)': 28,
};

/// Human-review queue state — the PRD requires a clinician between the model
/// and any individual outreach (§3, §8.1).
const int kAwaitingClinicalReview = 7;
const int kReviewedThisCycle = 19;
const int kOutreachCompleted = 12;

// ── HR Admin Console (ingestion) ───────────────────────────────────────────

const int kTotalRecordsProcessed = 12480;
const int kAcceptedRecords = 12327;
const int kRejectedRecords = 153;
const String kLastSuccessfulSync = '31 Aug 2025 · 02:15';

/// Weekly accepted-record volume, for the ingestion sparkline.
const List<double> kIngestionVolumeTrend = [
  860, 940, 1120, 1080, 1240, 1190,
  1310, 1275, 1420, 1380, 1465, 1520,
];

class IngestionSource {
  const IngestionSource({
    required this.tier,
    required this.name,
    required this.status,
    required this.detail,
    required this.healthy,
  });

  final String tier;
  final String name;
  final String status;
  final String detail;
  final bool healthy;
}

const List<IngestionSource> kIngestionSources = [
  // Names are sentence-case and must stay that way — `hr_admin_console_test`
  // asserts the exact tier labels the PRD names.
  IngestionSource(
      tier: 'Tier 1',
      name: 'HRMS integration',
      status: 'Connected',
      detail: 'Last sync: 31 Aug 2025, 02:15 AM',
      healthy: true),
  IngestionSource(
      tier: 'Tier 2',
      name: 'CSV / XLSX upload',
      status: 'Active',
      detail: 'Last upload: 30 Aug 2025, 11:20 AM',
      healthy: true),
  IngestionSource(
      tier: 'Tier 3',
      name: 'Manual entry',
      status: 'Available',
      detail: 'No recent activity',
      healthy: false),
];

class IngestionRun {
  const IngestionRun({
    required this.timestamp,
    required this.source,
    required this.records,
    required this.rejected,
    required this.status,
  });

  final String timestamp;
  final String source;
  final int records;
  final int rejected;
  final String status;
}

const List<IngestionRun> kRecentIngestionRuns = [
  IngestionRun(
      timestamp: '31 Aug · 02:15',
      source: 'HRMS (API)',
      records: 1520,
      rejected: 4,
      status: 'Completed'),
  IngestionRun(
      timestamp: '30 Aug · 11:20',
      source: 'CSV Upload',
      records: 520,
      rejected: 6,
      status: 'Completed'),
  IngestionRun(
      timestamp: '29 Aug · 18:04',
      source: 'HRMS (API)',
      records: 1465,
      rejected: 0,
      status: 'Completed'),
  IngestionRun(
      timestamp: '28 Aug · 09:41',
      source: 'Manual Entry',
      records: 18,
      rejected: 2,
      status: 'Partial'),
  IngestionRun(
      timestamp: '27 Aug · 02:15',
      source: 'HRMS (API)',
      records: 1380,
      rejected: 11,
      status: 'Completed'),
];

/// Most common reasons a row is rejected at validation.
const Map<String, int> kRejectionReasons = {
  'Missing Service ID': 64,
  'Malformed duty-hours value': 41,
  'Leave balance out of range': 29,
  'Duplicate record in batch': 19,
};
