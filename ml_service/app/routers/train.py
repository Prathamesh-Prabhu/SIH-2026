from datetime import datetime
from typing import Dict, Optional
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
import numpy as np
import pandas as pd

from ..config import settings
from ..feature_engineering import FeatureEngineeringPipeline
from ..models.behavioral_model import PredictiveBehavioralModel
from ..models.governance import ModelGovernanceManager
from ..models.nlp_models import HighRecallCrisisClassifier, RoutineSentimentClassifier
from ..schemas import ModelCardResponse
from ..synthetic_generator import SyntheticDataGenerator

router = APIRouter(prefix="/api/v1/models", tags=["Model Training & Governance"])

class TrainModelsRequest(BaseModel):
    version: str = "v1.0.0"
    personnel_samples: int = 500
    save_checkpoints: bool = True

class TrainModelsResponse(BaseModel):
    status: str
    version: str
    behavioral_model_type: str
    evaluation_metrics: Dict[str, float]
    model_card: ModelCardResponse
    trained_at: str

@router.post(
    "/train", 
    response_model=TrainModelsResponse, 
    status_code=status.HTTP_200_OK,
    summary="Train Predictive Behavioral & NLP Models"
)
async def train_models(payload: TrainModelsRequest):
    """
    Executes full offline training pipeline:
      1. Generates/loads synthetic bootstrap data matching PS specification
      2. Runs 30/60/90-day feature engineering
      3. Trains XGBoost gradient-boosted behavioral risk model
      4. Trains Tier 1 routine sentiment & Tier 2 high-recall crisis models
      5. Computes evaluation metrics and generates compliant Model Card
    """
    try:
        # Step 1: Generate synthetic training data
        generator = SyntheticDataGenerator()
        data = generator.generate_all(personnel_count=payload.personnel_samples, days_history=90, save_to_disk=True)
        hr_df = data["hr_df"]
        assessments_df = data["assessments_df"]
        transcripts_df = data["transcripts_df"]

        # Step 2: Extract features
        fe = FeatureEngineeringPipeline()
        features_df = fe.transform_dataset(hr_df, assessments_df)

        # Step 3: Rule-based ground truth risk labels for Phase 1 supervised bootstrapping
        # High duty days OR severe leave deficit OR high exhaustion + low sleep -> elevated risk (1), else resilient (0)
        risk_condition = (
            (features_df["consecutive_duty_days_max_30d"] > 18) |
            (features_df["leave_utilization_ratio_30d"] < 0.10) |
            ((features_df["avg_sleep_score_30d"] < 2.2) & (features_df["avg_exhaustion_score_30d"] > 3.8))
        )
        y = np.where(risk_condition, 1, 0)

        # Step 4: Train Behavioral Model
        b_model = PredictiveBehavioralModel(model_version=payload.version)
        metrics = b_model.train(features_df, y)
        b_model.save()

        # Step 5: Train NLP Sentiment & Crisis Models
        sentiment_model = RoutineSentimentClassifier()
        # Binary sentiment mapping
        s_texts = transcripts_df["text"].tolist()
        s_labels = transcripts_df["sentiment"].apply(
            lambda s: "stressed_or_fatigued" if "stress" in s or "crisis" in s else "positive_or_neutral"
        ).tolist()
        sentiment_model.train(s_texts, s_labels)
        sentiment_model.save()

        crisis_model = HighRecallCrisisClassifier()
        c_texts = transcripts_df["text"].tolist()
        c_labels = transcripts_df["crisis_label"].tolist()
        crisis_model.train(c_texts, c_labels)
        crisis_model.save()

        # Step 6: Create Model Card & Checkpoint
        gov_mgr = ModelGovernanceManager()
        card = gov_mgr.create_model_card(
            model_version=payload.version,
            model_type=b_model.model_type,
            metrics=metrics,
            features=PredictiveBehavioralModel.FEATURE_NAMES,
            sample_size=payload.personnel_samples,
            oversight_approved=True
        )

        if payload.save_checkpoints:
            gov_mgr.checkpoint_model_version(payload.version)

        return TrainModelsResponse(
            status="SUCCESS",
            version=payload.version,
            behavioral_model_type=b_model.model_type,
            evaluation_metrics=metrics,
            model_card=card,
            trained_at=datetime.now().isoformat()
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Model training failed: {str(e)}"
        )
