import 'package:flutter/material.dart';

import 'wellbeing_checkins.dart';

/// The three recurring assessments personnel can attend. Every completion writes
/// the same 1–5 domain scores into `assessments` (tagged with its cadence), so
/// they all feed the anonymous Organisation Wellbeing roll-up on the HR
/// dashboard the moment they are submitted.
enum CheckInCadence { daily, weekly, monthly }

extension CheckInCadenceX on CheckInCadence {
  String get id => name;

  String get title => switch (this) {
        CheckInCadence.daily => 'Daily pulse',
        CheckInCadence.weekly => 'Weekly check-in',
        CheckInCadence.monthly => 'Monthly review',
      };

  String get blurb => switch (this) {
        CheckInCadence.daily => 'A quick read on today — 3 questions',
        CheckInCadence.weekly => 'The full six-domain check-in',
        CheckInCadence.monthly => 'A deeper look back over the month',
      };

  IconData get icon => switch (this) {
        CheckInCadence.daily => Icons.wb_sunny_outlined,
        CheckInCadence.weekly => Icons.event_repeat_outlined,
        CheckInCadence.monthly => Icons.calendar_month_outlined,
      };

  Duration get interval => switch (this) {
        CheckInCadence.daily => const Duration(days: 1),
        CheckInCadence.weekly => const Duration(days: 7),
        CheckInCadence.monthly => const Duration(days: 30),
      };

  /// Domain keys this cadence asks about.
  List<String> get domainKeys => switch (this) {
        CheckInCadence.daily => const [
            'workload_perception',
            'physical_exhaustion',
            'mood_rating',
          ],
        CheckInCadence.weekly => [for (final i in kWellbeingCheckIns) i.key],
        CheckInCadence.monthly => [for (final i in kWellbeingCheckIns) i.key],
      };

  /// The check-in items to present, in the canonical order.
  List<CheckInItem> get items =>
      [for (final i in kWellbeingCheckIns) if (domainKeys.contains(i.key)) i];
}

CheckInCadence cadenceFromId(String? id) => switch (id) {
      'daily' => CheckInCadence.daily,
      'monthly' => CheckInCadence.monthly,
      _ => CheckInCadence.weekly,
    };

/// Short "due in 3d" / "due now" phrasing from a last-completed timestamp.
String cadenceDueLabel(CheckInCadence cadence, DateTime? last) {
  if (last == null) return 'Not started';
  final next = last.add(cadence.interval);
  final remaining = next.difference(DateTime.now());
  if (remaining.isNegative) return 'Due now';
  if (remaining.inHours < 24) return 'Due in ${remaining.inHours + 1}h';
  return 'Due in ${remaining.inDays + 1}d';
}
