/// Typed mirrors of the ManoFit Analytics & ML microservice schemas
/// (`ml_service/app/schemas.py`). Kept 1:1 with the Python Pydantic models so
/// swapping synthetic data for real anonymized data needs no client changes.
library;

/// Clinical risk tier. The service never exposes raw probabilities to the UI —
/// personnel and commanders only ever see a band.
enum RiskBand {
  low('LOW', 'Low'),
  moderate('MODERATE', 'Moderate'),
  elevated('ELEVATED', 'Elevated');

  const RiskBand(this.wireValue, this.displayName);

  final String wireValue;
  final String displayName;

  static RiskBand fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'ELEVATED':
        return RiskBand.elevated;
      case 'MODERATE':
        return RiskBand.moderate;
      case 'LOW':
      default:
        return RiskBand.low;
    }
  }
}

/// SHAP-style contribution of a single feature, surfaced to Welfare Officers.
class FactorAttribution {
  const FactorAttribution({
    required this.factorName,
    required this.displayTitle,
    required this.importanceWeight,
    required this.direction,
    required this.contextDetail,
  });

  final String factorName;
  final String displayTitle;
  final double importanceWeight;
  final String direction;
  final String contextDetail;

  bool get isRiskIncreasing => direction == 'risk_increasing';

  factory FactorAttribution.fromJson(Map<String, dynamic> json) {
    return FactorAttribution(
      factorName: json['factor_name'] as String? ?? '',
      displayTitle: json['display_title'] as String? ?? '',
      importanceWeight: (json['importance_weight'] as num?)?.toDouble() ?? 0.0,
      direction: json['direction'] as String? ?? 'risk_increasing',
      contextDetail: json['context_detail'] as String? ?? '',
    );
  }
}

class RiskAssessment {
  const RiskAssessment({
    required this.pseudonymToken,
    required this.riskBand,
    required this.confidence,
    required this.topFactors,
    required this.recommendedSupportPathway,
    required this.modelVersion,
    required this.evaluatedAt,
    required this.synthetic,
  });

  final String pseudonymToken;
  final RiskBand riskBand;
  final double confidence;
  final List<FactorAttribution> topFactors;
  final String recommendedSupportPathway;
  final String modelVersion;
  final String evaluatedAt;
  final bool synthetic;

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      pseudonymToken: json['pseudonym_token'] as String? ?? '',
      riskBand: RiskBand.fromString(json['risk_band'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      topFactors: (json['top_factors'] as List<dynamic>? ?? [])
          .map((f) => FactorAttribution.fromJson(f as Map<String, dynamic>))
          .toList(),
      recommendedSupportPathway:
          json['recommended_support_pathway'] as String? ?? '',
      modelVersion: json['model_version'] as String? ?? 'unknown',
      evaluatedAt: json['evaluated_at'] as String? ?? '',
      synthetic: json['synthetic'] as bool? ?? true,
    );
  }
}

class BatchRiskResult {
  const BatchRiskResult({
    required this.results,
    required this.totalEvaluated,
    required this.elevatedCount,
    required this.moderateCount,
    required this.lowCount,
  });

  final List<RiskAssessment> results;
  final int totalEvaluated;
  final int elevatedCount;
  final int moderateCount;
  final int lowCount;

  /// Share of the cohort needing proactive welfare outreach.
  double get elevatedRatio =>
      totalEvaluated == 0 ? 0 : elevatedCount / totalEvaluated;

  factory BatchRiskResult.fromJson(Map<String, dynamic> json) {
    return BatchRiskResult(
      results: (json['results'] as List<dynamic>? ?? [])
          .map((r) => RiskAssessment.fromJson(r as Map<String, dynamic>))
          .toList(),
      totalEvaluated: json['total_evaluated'] as int? ?? 0,
      elevatedCount: json['elevated_count'] as int? ?? 0,
      moderateCount: json['moderate_count'] as int? ?? 0,
      lowCount: json['low_count'] as int? ?? 0,
    );
  }
}

/// Tier 1 — routine conversational sentiment and fatigue tracking.
class SentimentResult {
  const SentimentResult({
    required this.textSnippet,
    required this.sentimentLabel,
    required this.valenceScore,
    required this.stressProbability,
    required this.fatigueIndicators,
  });

  final String textSnippet;
  final String sentimentLabel;
  final double valenceScore;
  final double stressProbability;
  final List<String> fatigueIndicators;

  factory SentimentResult.fromJson(Map<String, dynamic> json) {
    return SentimentResult(
      textSnippet: json['text_snippet'] as String? ?? '',
      sentimentLabel: json['sentiment_label'] as String? ?? 'Neutral',
      valenceScore: (json['valence_score'] as num?)?.toDouble() ?? 0.0,
      stressProbability:
          (json['stress_probability'] as num?)?.toDouble() ?? 0.0,
      fatigueIndicators: (json['fatigue_indicators'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// Tier 2 — high-recall crisis classification plus the Tele-MANAS payload.
class CrisisResult {
  const CrisisResult({
    required this.crisisDetected,
    required this.crisisProbability,
    required this.riskIndicators,
    required this.escalationTriggered,
    required this.helpline,
    required this.priority,
    required this.recommendedAction,
    required this.stabilizingResponseHint,
  });

  final bool crisisDetected;
  final double crisisProbability;
  final List<String> riskIndicators;
  final bool escalationTriggered;
  final String helpline;
  final String priority;
  final String recommendedAction;
  final String stabilizingResponseHint;

  factory CrisisResult.fromJson(Map<String, dynamic> json) {
    final escalation =
        json['escalation'] as Map<String, dynamic>? ?? const {};
    return CrisisResult(
      crisisDetected: json['crisis_detected'] as bool? ?? false,
      crisisProbability:
          (json['crisis_probability'] as num?)?.toDouble() ?? 0.0,
      riskIndicators:
          (json['risk_indicators_detected'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      escalationTriggered: escalation['trigger'] as bool? ?? false,
      helpline: escalation['helpline'] as String? ?? '14416',
      priority: escalation['priority'] as String? ?? 'ROUTINE',
      recommendedAction: escalation['recommended_action'] as String? ?? '',
      stabilizingResponseHint:
          json['stabilizing_response_hint'] as String? ?? '',
    );
  }
}

/// Governance artifact documenting the active model's provenance and metrics.
class ModelCard {
  const ModelCard({
    required this.modelId,
    required this.modelName,
    required this.modelType,
    required this.version,
    required this.trainingWindow,
    required this.sampleSize,
    required this.featuresUtilized,
    required this.metrics,
    required this.knownLimitations,
    required this.lastValidatedDate,
    required this.oversightBoardApproved,
    required this.isActive,
  });

  final String modelId;
  final String modelName;
  final String modelType;
  final String version;
  final String trainingWindow;
  final int sampleSize;
  final List<String> featuresUtilized;
  final Map<String, double> metrics;
  final List<String> knownLimitations;
  final String lastValidatedDate;
  final bool oversightBoardApproved;
  final bool isActive;

  factory ModelCard.fromJson(Map<String, dynamic> json) {
    return ModelCard(
      modelId: json['model_id'] as String? ?? '',
      modelName: json['model_name'] as String? ?? '',
      modelType: json['model_type'] as String? ?? '',
      version: json['version'] as String? ?? '',
      trainingWindow: json['training_window'] as String? ?? '',
      sampleSize: json['sample_size'] as int? ?? 0,
      featuresUtilized: (json['features_utilized'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      metrics: (json['metrics'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      knownLimitations: (json['known_limitations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      lastValidatedDate: json['last_validated_date'] as String? ?? '',
      oversightBoardApproved: json['oversight_board_approved'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}
