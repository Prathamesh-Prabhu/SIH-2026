from datetime import datetime
from typing import List
from fastapi import APIRouter, HTTPException, status
import pandas as pd

from ..feature_engineering import FeatureEngineeringPipeline
from ..models.behavioral_model import PredictiveBehavioralModel
from ..models.ensemble import WelfareEnsembleEngine
from ..models.nlp_models import HighRecallCrisisClassifier, RoutineSentimentClassifier
from ..schemas import (
    BatchScoreRequest,
    BatchScoreResponse,
    FeatureSet,
    RiskAssessmentResponse,
    RiskBand,
    ScorePredictionRequest
)

router = APIRouter(prefix="/api/v1/score", tags=["Predictive Scoring & Explainability"])

# Singleton instances loaded lazily
_behavioral_model = PredictiveBehavioralModel()
_sentiment_model = RoutineSentimentClassifier()
_crisis_model = HighRecallCrisisClassifier()
_ensemble_engine = None

def get_ensemble_engine() -> WelfareEnsembleEngine:
    global _ensemble_engine, _behavioral_model, _sentiment_model, _crisis_model
    if _ensemble_engine is None:
        _behavioral_model.load()
        _sentiment_model.load()
        _crisis_model.load()
        _ensemble_engine = WelfareEnsembleEngine(
            behavioral_model=_behavioral_model,
            sentiment_model=_sentiment_model,
            crisis_model=_crisis_model
        )
    return _ensemble_engine

@router.post(
    "/predict", 
    response_model=RiskAssessmentResponse, 
    status_code=status.HTTP_200_OK,
    summary="Evaluate Personnel Risk Band & Top Factors"
)
async def score_personnel(payload: ScorePredictionRequest):
    """
    Evaluates personnel stress/burnout risk.
    Combines behavioral model with conversational signals into a Low/Moderate/Elevated band.
    Returns SHAP-style top factor attributions for Welfare Officers.
    Raw numeric scores are never exposed.
    """
    try:
        engine = get_ensemble_engine()
        fe = FeatureEngineeringPipeline()

        # Extract features if not directly provided
        if payload.features:
            features = payload.features
        elif payload.recent_hr_records or payload.recent_assessments:
            hr_df = pd.DataFrame([r.model_dump() for r in (payload.recent_hr_records or [])])
            ass_df = pd.DataFrame([a.model_dump() for a in (payload.recent_assessments or [])])
            features = fe.extract_features_for_personnel(
                pseudonym_token=payload.pseudonym_token,
                hr_df=hr_df,
                assessments_df=ass_df,
                nlp_sentiment_score=payload.recent_nlp_sentiment_score
            )
        else:
            # Default empty baseline
            features = fe.extract_features_for_personnel(
                pseudonym_token=payload.pseudonym_token,
                hr_df=pd.DataFrame(),
                assessments_df=pd.DataFrame()
            )

        return engine.evaluate_personnel(payload, features)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Scoring prediction failed: {str(e)}"
        )

@router.post(
    "/batch", 
    response_model=BatchScoreResponse, 
    status_code=status.HTTP_200_OK,
    summary="Batch Evaluation for Unit Aggregations"
)
async def score_batch(payload: BatchScoreRequest):
    """
    Batch evaluates risk bands for multiple personnel.
    Used by Edge Functions to feed Commander unit-level aggregate dashboards.
    """
    try:
        engine = get_ensemble_engine()
        fe = FeatureEngineeringPipeline()
        results: List[RiskAssessmentResponse] = []

        elevated_count = 0
        moderate_count = 0
        low_count = 0

        for item in payload.items:
            if item.features:
                feats = item.features
            else:
                hr_df = pd.DataFrame([r.model_dump() for r in (item.recent_hr_records or [])])
                ass_df = pd.DataFrame([a.model_dump() for a in (item.recent_assessments or [])])
                feats = fe.extract_features_for_personnel(
                    pseudonym_token=item.pseudonym_token,
                    hr_df=hr_df,
                    assessments_df=ass_df,
                    nlp_sentiment_score=item.recent_nlp_sentiment_score
                )
            
            res = engine.evaluate_personnel(item, feats)
            results.append(res)

            if res.risk_band == RiskBand.ELEVATED:
                elevated_count += 1
            elif res.risk_band == RiskBand.MODERATE:
                moderate_count += 1
            else:
                low_count += 1

        return BatchScoreResponse(
            results=results,
            total_evaluated=len(results),
            elevated_count=elevated_count,
            moderate_count=moderate_count,
            low_count=low_count
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Batch scoring failed: {str(e)}"
        )
