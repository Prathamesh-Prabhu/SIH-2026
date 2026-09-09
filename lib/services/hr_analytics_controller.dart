import 'package:flutter/foundation.dart';

import '../models/ml_models.dart';
import 'db_service.dart';
import 'ml_service.dart';

/// Single source of truth for the HR Admin analytics board.
///
/// Everything it exposes is derived from the roster the HR Admin actually
/// ingested ([DbService.hrFeatureRecords]) scored by the live ManoFit ML
/// microservice — no synthetic cohort, no demo trend data, no on-device
/// heuristic substitution. If the model service is unreachable the board shows
/// an explicit offline state rather than fabricated numbers.
class HrAnalyticsController extends ChangeNotifier {
  static final HrAnalyticsController _instance = HrAnalyticsController._();
  factory HrAnalyticsController() => _instance;
  HrAnalyticsController._();

  final _ml = MlService();
  final _db = DbService();

  BatchRiskResult? _result;
  bool _loading = false;
  String? _error;

  BatchRiskResult? get result => _result;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasCohort => _db.hrFeatureRecords.isNotEmpty;
  bool get hasReport => _result != null && _result!.totalEvaluated > 0;
  int get cohortSize => _db.hrFeatureRecords.length;

  String get modelVersion =>
      _result?.results.isNotEmpty == true ? _result!.results.first.modelVersion : '-';


  /// Unit code the roster recorded for a pseudonym token.
  String unitForToken(String token) => _db.unitForToken(token);

  /// Re-scores the ingested cohort against the live model.
  Future<void> refresh() async {
    if (!hasCohort) {
      _result = null;
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _ml.checkHealth();
      if (!_ml.isOnline) {
        throw MlServiceUnavailable(
            'ML microservice offline. Start it with '
            '`python ml_service/run_server.py` (port 8000).');
      }
      _result = await _ml.scoreBatch(
        _db.buildCohortScoringPayload(),
        strict: true,
      );
    } on MlServiceUnavailable catch (e) {
      _error = e.message;
      _result = null;
    } catch (e) {
      _error = 'Scoring failed: $e';
      _result = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Derived aggregates, all straight from [_result] ─────────────────────

  /// Elevated / moderate cases, worst band first, for the triage queue.
  List<RiskAssessment> get flaggedCases {
    final r = _result;
    if (r == null) return const [];
    return r.results.where((a) => a.riskBand != RiskBand.low).toList()
      ..sort((a, b) => b.riskBand.index.compareTo(a.riskBand.index));
  }

  /// Per-unit roll-up: how many of each unit's tokens landed in each band.
  List<UnitRollup> get unitRollups {
    final r = _result;
    if (r == null) return const [];
    final byUnit = <String, UnitRollup>{};
    for (final a in r.results) {
      final unit = _db.unitForToken(a.pseudonymToken);
      final u = byUnit.putIfAbsent(unit, () => UnitRollup(unit));
      u.total++;
      switch (a.riskBand) {
        case RiskBand.elevated:
          u.elevated++;
        case RiskBand.moderate:
          u.moderate++;
        case RiskBand.low:
          u.low++;
      }
    }
    final list = byUnit.values.toList()
      ..sort((a, b) => b.strainShare.compareTo(a.strainShare));
    return list;
  }

  /// Top contributing factor across all flagged cases, ranked by frequency.
  List<MapEntry<String, int>> get topDrivers {
    final tally = <String, int>{};
    for (final a in flaggedCases) {
      for (final f in a.topFactors.where((f) => f.isRiskIncreasing).take(2)) {
        tally[f.displayTitle] = (tally[f.displayTitle] ?? 0) + 1;
      }
    }
    final entries = tally.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(6).toList();
  }
}

class UnitRollup {
  UnitRollup(this.unitCode);
  final String unitCode;
  int total = 0;
  int low = 0;
  int moderate = 0;
  int elevated = 0;

  double get strainShare => total == 0 ? 0 : (elevated + 0.5 * moderate) / total;
}
