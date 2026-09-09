from typing import List, Optional
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
import pandas as pd

from ..feature_engineering import FeatureEngineeringPipeline
from ..schemas import FeatureSet, HRRecordInput, WellnessAssessmentInput

router = APIRouter(prefix="/api/v1/features", tags=["Feature Engineering"])

class TransformRequest(BaseModel):
    pseudonym_token: str
    hr_records: List[HRRecordInput]
    assessments: List[WellnessAssessmentInput]
    as_of_date: Optional[str] = None
    nlp_sentiment_score: Optional[float] = None

@router.post(
    "/transform", 
    response_model=FeatureSet, 
    status_code=status.HTTP_200_OK,
    summary="Compute 30/60/90-day Rolling Features"
)
async def transform_features(payload: TransformRequest):
    """
    Transforms operational HR records and self-reported check-ins
    into rolling-window behavioral features for a single personnel token.
    """
    try:
        pipeline = FeatureEngineeringPipeline()
        hr_df = pd.DataFrame([r.model_dump() for r in payload.hr_records]) if payload.hr_records else pd.DataFrame()
        assessments_df = pd.DataFrame([a.model_dump() for a in payload.assessments]) if payload.assessments else pd.DataFrame()
        
        features = pipeline.extract_features_for_personnel(
            pseudonym_token=payload.pseudonym_token,
            hr_df=hr_df,
            assessments_df=assessments_df,
            as_of_date=payload.as_of_date,
            nlp_sentiment_score=payload.nlp_sentiment_score
        )
        return features
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Feature transformation error: {str(e)}"
        )
