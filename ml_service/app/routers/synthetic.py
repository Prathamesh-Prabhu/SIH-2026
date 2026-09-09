from datetime import datetime
from fastapi import APIRouter, HTTPException, status
from ..schemas import SyntheticDataGenRequest, SyntheticDataGenResponse
from ..synthetic_generator import SyntheticDataGenerator

router = APIRouter(prefix="/api/v1/synthetic", tags=["Synthetic Data Generation"])

@router.post(
    "/generate", 
    response_model=SyntheticDataGenResponse, 
    status_code=status.HTTP_201_CREATED,
    summary="Generate Schema-Matched Synthetic Datasets"
)
async def generate_synthetic_data(payload: SyntheticDataGenRequest):
    """
    Generates realistic, offline synthetic HR operational data, wellness survey check-ins,
    and simulated companion transcripts as mandated by the problem statement.
    Every record is flagged with `synthetic: true`.
    """
    try:
        generator = SyntheticDataGenerator()
        results = generator.generate_all(
            personnel_count=payload.personnel_count,
            days_history=payload.days_history,
            save_to_disk=payload.save_to_disk
        )
        return SyntheticDataGenResponse(
            status="SUCCESS",
            personnel_count=payload.personnel_count,
            hr_records_count=len(results["hr_df"]),
            assessments_count=len(results["assessments_df"]),
            transcripts_count=len(results["transcripts_df"]),
            file_paths=results.get("paths", {}),
            generated_at=datetime.now().isoformat()
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate synthetic datasets: {str(e)}"
        )
