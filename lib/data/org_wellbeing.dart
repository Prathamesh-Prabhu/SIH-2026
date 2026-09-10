import 'package:flutter/material.dart';

import 'assessment_questions.dart';

/// Organisation-wide wellbeing roll-up.
///
/// Takes the anonymous 1–5 wellbeing check-ins the org holds (personnel
/// self-reports + any roster wellness pulse) and reports, per domain, the share
/// of responses that fall in the adverse range — "what personnel say hurts them
/// the most". Nothing is per-person; every figure is a cohort count.
class WellbeingConcern {
  const WellbeingConcern({
    required this.key,
    required this.label,
    required this.icon,
    required this.affected,
    required this.answered,
  });

  final String key;
  final String label;
  final IconData icon;

  /// Responses in the adverse range for this domain.
  final int affected;

  /// Responses that answered this domain at all.
  final int answered;

  double get rate => answered == 0 ? 0 : affected / answered;
  int get pct => (rate * 100).round();
}

class _Domain {
  const _Domain(this.key, this.label, this.icon, this.isAdverse);
  final String key;
  final String label;
  final IconData icon;

  /// True when a 1–5 answer counts as "this is hurting me".
  final bool Function(int value) isAdverse;
}

final List<_Domain> _domains = [
  _Domain('workload_perception', 'Duty load too heavy',
      Icons.work_history_outlined, (v) => v >= 4),
  _Domain('physical_exhaustion', 'Physically drained',
      Icons.battery_2_bar_outlined, (v) => v >= 4),
  _Domain('sleep_quality', 'Not resting enough',
      Icons.bedtime_outlined, (v) => v <= 2),
  _Domain('mood_rating', 'Low mood',
      Icons.sentiment_dissatisfied_outlined, (v) => v <= 2),
  _Domain('manager_relationship', 'Unsupported by leadership',
      Icons.supervisor_account_outlined, (v) => v <= 2),
  _Domain('peer_social_support', 'Isolated from the unit',
      Icons.groups_outlined, (v) => v <= 2),
];

/// Minimum answers for a domain before it is shown (small-cell suppression).
const int kMinDomainSample = 2;

/// Minimum total check-ins before the section renders at all.
const int kMinOrgSample = 3;

class OrgWellbeingReport {
  const OrgWellbeingReport({
    required this.sampleSize,
    required this.concerns,
    required this.index,
  });

  /// Total anonymous check-ins that fed the roll-up.
  final int sampleSize;

  /// Domains with enough answers, ranked by adverse rate (worst first).
  final List<WellbeingConcern> concerns;

  /// Overall wellbeing index, 0–100 — the mean of every core answer oriented so
  /// higher is always better. `null` until there is any data.
  final int? index;

  bool get hasEnough => sampleSize >= kMinOrgSample && concerns.isNotEmpty;

  /// Healthy ≥ 70 · Watch 50–69 · Strained < 50.
  String get band => index == null
      ? '—'
      : index! >= 70
          ? 'Healthy'
          : index! >= 50
              ? 'Watch'
              : 'Strained';

  Color get bandColor => index == null
      ? const Color(0xFF6B746E)
      : index! >= 70
          ? const Color(0xFF24704F)
          : index! >= 50
              ? const Color(0xFFE7A126)
              : const Color(0xFFE56857);
}

OrgWellbeingReport computeOrgWellbeing(List<Map<String, int>> checkIns) {
  final concerns = <WellbeingConcern>[];
  for (final d in _domains) {
    var answered = 0;
    var affected = 0;
    for (final c in checkIns) {
      final v = c[d.key];
      if (v == null) continue;
      answered++;
      if (d.isAdverse(v)) affected++;
    }
    if (answered < kMinDomainSample) continue;
    concerns.add(WellbeingConcern(
      key: d.key,
      label: d.label,
      icon: d.icon,
      affected: affected,
      answered: answered,
    ));
  }
  concerns.sort((a, b) {
    final r = b.rate.compareTo(a.rate);
    return r != 0 ? r : b.affected.compareTo(a.affected);
  });

  // Overall index: every core answer, oriented so 5 is always "good", averaged
  // and rescaled 1–5 → 0–100. Matches the ML scale contract in
  // `wellbeing_checkins.dart` (workload + exhaustion are higher = worse).
  const coreKeys = {
    'workload_perception',
    'physical_exhaustion',
    'sleep_quality',
    'mood_rating',
    'manager_relationship',
    'peer_social_support',
  };
  const higherIsWorse = {'workload_perception', 'physical_exhaustion'};
  var sum = 0;
  var n = 0;
  for (final c in checkIns) {
    for (final entry in c.entries) {
      if (!coreKeys.contains(entry.key)) continue;
      final v = entry.value;
      sum += higherIsWorse.contains(entry.key) ? (6 - v) : v;
      n++;
    }
  }
  final index = n == 0 ? null : (((sum / n) - 1) / 4 * 100).round().clamp(0, 100);

  return OrgWellbeingReport(
    sampleSize: checkIns.length,
    concerns: concerns,
    index: index,
  );
}

// ── Monthly deep-dive roll-up ─────────────────────────────────────────────
/// Adverse-rate per monthly-only reflective domain, ranked worst first. Only
/// domains with at least [kMinDomainSample] answers are returned.
List<WellbeingConcern> computeDeepDive(List<Map<String, int>> responses) {
  final out = <WellbeingConcern>[];
  for (final d in kDeepDiveDomains) {
    var answered = 0;
    var affected = 0;
    for (final r in responses) {
      final v = r[d.key];
      if (v == null) continue;
      answered++;
      if (d.isAdverse(v)) affected++;
    }
    if (answered < kMinDomainSample) continue;
    out.add(WellbeingConcern(
      key: d.key,
      label: d.label,
      icon: d.icon,
      affected: affected,
      answered: answered,
    ));
  }
  out.sort((a, b) => b.rate.compareTo(a.rate));
  return out;
}
