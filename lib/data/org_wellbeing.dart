import 'package:flutter/material.dart';

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
  });

  /// Total anonymous check-ins that fed the roll-up.
  final int sampleSize;

  /// Domains with enough answers, ranked by adverse rate (worst first).
  final List<WellbeingConcern> concerns;

  bool get hasEnough => sampleSize >= kMinOrgSample && concerns.isNotEmpty;
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
  return OrgWellbeingReport(sampleSize: checkIns.length, concerns: concerns);
}
