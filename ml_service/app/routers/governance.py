from typing import List
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
import pandas as pd

from ..models.governance import ModelGovernanceManager
from ..schemas import ModelCardResponse, RollbackRequest, RollbackResponse

router = APIRouter(prefix="/api/v1/governance", tags=["Model Governance & Audit"])

_gov_manager = ModelGovernanceManager()

class ClinicalSampleRequest(BaseModel):
    evaluations: List[dict]
    sample_size: int = 30

@router.get(
    "/model-card", 
    response_model=ModelCardResponse, 
    status_code=status.HTTP_200_OK,
    summary="Get Active Model Card & Governance Metadata"
)
async def get_model_card():
    """
    Returns the active Model Card, documenting training window, sample size,
    performance metrics (ROC-AUC, Precision, Recall, F1), known limitations,
    and Oversight Board sign-off status.
    """
    card = _gov_manager.get_active_model_card()
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active model card found. Run /api/v1/models/train first."
        )
    return card

@router.post(
    "/rollback", 
    response_model=RollbackResponse, 
    status_code=status.HTTP_200_OK,
    summary="Rollback Model to a Prior Validated Checkpoint"
)
async def rollback_model(payload: RollbackRequest):
    """
    Rolls back the active model to a prior versioned checkpoint in case of drift,
    anomalous false positives, or Oversight Board directive.
    """
    try:
        return _gov_manager.rollback_to_version(
            target_version=payload.target_version,
            justification=payload.justification,
            authorized_by=payload.authorized_by
        )
    except FileNotFoundError as fnf:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(fnf))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Rollback failed: {str(e)}"
        )

@router.post(
    "/clinical-sample", 
    status_code=status.HTTP_200_OK,
    summary="Generate Monthly Clinical Validation Sample"
)
async def sample_clinical_cases(payload: ClinicalSampleRequest):
    """
    Samples a balanced cohort across Low, Moderate, and Elevated risk bands
    for the monthly human clinical review and threshold recalibration loop.
    """
    try:
        df = pd.DataFrame(payload.evaluations)
        sampled_df = _gov_manager.sample_cases_for_clinical_review(df, sample_size=payload.sample_size)
        return {
            "status": "SUCCESS",
            "sampled_count": len(sampled_df),
            "sample": sampled_df.to_dict(orient="records")
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Sampling failed: {str(e)}"
        )
