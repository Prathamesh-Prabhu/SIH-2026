from datetime import datetime
from typing import List, Optional
import numpy as np

from ..config import settings
from ..schemas import (
    FactorAttribution,
    FeatureSet,
    RiskAssessmentResponse,
    RiskBand,
    ScorePredictionRequest
)
from .behavioral_model import PredictiveBehavioralModel
from .nlp_models import HighRecallCrisisClassifier, RoutineSentimentClassifier

class WelfareEnsembleEngine:
    """
    Ensemble Scoring & Explainability Engine for ManoFit.
    Combines:
      1. Predictive Behavioral Tree Model (rolling 30/60/90-day HR + Assessment check-ins)
      2. NLP Sentiment Trajectory
      3. Real-time / recent Crisis Detection flags
      
    Outputs strictly categorical clinical risk bands (LOW, MODERATE, ELEVATED)
    accompanied by top factor attributions for Welfare Officers.
    No raw algorithmic scores are ever exposed outside this engine.
    """

    def __init__(
        self,
        behavioral_model: PredictiveBehavioralModel,
        sentiment_model: RoutineSentimentClassifier,
        crisis_model: HighRecallCrisisClassifier
    ):
        self.behavioral_model = behavioral_model
        self.sentiment_model = sentiment_model
        self.crisis_model = crisis_model

    def evaluate_personnel(
        self, 
        request: ScorePredictionRequest, 
        features: FeatureSet
    ) -> RiskAssessmentResponse:
        # 1. Behavioral Model Probability & Factor Attributions
        prob_behavioral, top_factors = self.behavioral_model.predict_risk_probability(features)

        # 2. Integrate NLP Sentiment Score (if provided)
        nlp_score = request.recent_nlp_sentiment_score
        if nlp_score is None:
            nlp_score = features.nlp_stress_trend_score or 0.0

        # Weighted combination: 75% behavioral/operational history + 25% longitudinal conversational sentiment
        combined_risk_index = (0.75 * prob_behavioral) + (0.25 * nlp_score)

        # 3. Crisis Override: If an acute crisis cue was detected, immediately elevate
        crisis_flag = request.recent_crisis_cue_detected
        if crisis_flag:
            combined_risk_index = max(combined_risk_index, 0.90)
            # Insert crisis attribution at top
            top_factors.insert(0, FactorAttribution(
                factor_name="crisis_cue_detected",
                display_title="High-Recall Crisis Cue Detected",
                importance_weight=0.95,
                direction="risk_increasing",
                context_detail="Recent conversation exhibited acute crisis or despair phrasing triggering Tele-MANAS review"
            ))

        # 4. Map to Categorical Clinical Risk Band (Strictly Low, Moderate, Elevated)
        if combined_risk_index >= settings.RISK_THRESHOLD_ELEVATED:
            risk_band = RiskBand.ELEVATED
            recommendation = (
                "Priority confidential outreach by unit Welfare Officer. "
                "Schedule supportive 1-on-1 check-in; evaluate leave rescheduling and workload relief. "
                "Non-disciplinary, welfare-first pathway."
            )
        elif combined_risk_index >= settings.RISK_THRESHOLD_MODERATE:
            risk_band = RiskBand.MODERATE
            recommendation = (
                "Proactive wellness check-in recommended. Suggest peer-support engagement, "
                "rest roster adjustment, or optional self-paced grounding resources."
            )
        else:
            risk_band = RiskBand.LOW
            recommendation = "Operational workload and wellness indicators within stable baseline. Continue routine monitoring."

        # Calculate confidence band
        confidence = float(np.clip(1.0 - (2.0 * abs(0.5 - combined_risk_index)), 0.65, 0.98))

        return RiskAssessmentResponse(
            pseudonym_token=request.pseudonym_token,
            risk_band=risk_band,
            confidence=round(confidence, 3),
            top_factors=top_factors[:5],
            recommended_support_pathway=recommendation,
            model_version=self.behavioral_model.model_version,
            evaluated_at=datetime.now().isoformat(),
            synthetic=features.synthetic
        )
