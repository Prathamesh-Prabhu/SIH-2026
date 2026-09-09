from datetime import datetime
from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

class RiskBand(str, Enum):
    LOW = "LOW"
    MODERATE = "MODERATE"
    ELEVATED = "ELEVATED"

class DeploymentLocationTier(str, Enum):
    PEACE = "PEACE"
    HIGH_ALTITUDE = "HIGH_ALTITUDE"
    CI_OPS = "CI_OPS"  # Counter-insurgency operations
    BORDER_OUTPOST = "BORDER_OUTPOST"
    FIELD_EXTREME = "FIELD_EXTREME"

# -------------------------------------------------------------------
# Raw HR & Ingestion Schemas (Pseudonymized at point of entry)
# -------------------------------------------------------------------

class HRRecordInput(BaseModel):
    pseudonym_token: str = Field(..., description="Pseudonymized token ID, never raw Service/PF number")
    record_date: str = Field(..., description="Date of record in YYYY-MM-DD format")
    unit_code: str = Field(..., description="Anonymized unit/battalion identifier")
    location_tier: DeploymentLocationTier = Field(..., description="Deployment hardship tier")
    shift_hours: float = Field(..., ge=0.0, le=24.0, description="Hours on active duty in the roster")
    is_rest_day: bool = Field(False, description="Whether this was an assigned rest/off day")
    leave_taken_days: float = Field(0.0, ge=0.0, description="Leave days taken in this period")
    leave_balance_days: float = Field(..., ge=0.0, description="Accrued leave balance available")
    consecutive_active_days: int = Field(0, ge=0, description="Consecutive operational days without rest")
    transfer_count_last_12m: int = Field(0, ge=0, description="Number of transfers/relocations in past 12m")
    deployment_id: Optional[str] = Field(
        None,
        description="Identifier of the current posting/deployment stint. Changes when the "
                    "person is redeployed, making deployment change an observable event "
                    "rather than a static counter."
    )
    deployment_start_date: Optional[str] = Field(
        None, description="Start date of the current deployment stint, YYYY-MM-DD"
    )
    training_load_hours: float = Field(0.0, ge=0.0, description="Hours spent in heavy physical or tactical training")
    synthetic: bool = Field(False, description="Flag indicating if record was synthetically generated")

# -------------------------------------------------------------------
# Assessment Check-In Schemas (The 6 Private Wellness Survey Check-ins)
# -------------------------------------------------------------------

class WellnessAssessmentInput(BaseModel):
    pseudonym_token: str = Field(..., description="Pseudonymized token ID")
    assessment_date: str = Field(..., description="Date of assessment completion in YYYY-MM-DD")
    workload_perception: int = Field(..., ge=1, le=5, description="1=Manageable to 5=Overwhelming")
    mood_rating: int = Field(..., ge=1, le=5, description="1=Very Low/Depressed to 5=Optimal/Calm")
    manager_relationship: int = Field(..., ge=1, le=5, description="1=Poor/Conflict to 5=Supportive")
    sleep_quality: int = Field(..., ge=1, le=5, description="1=Severe Insomnia to 5=Restful/8+ hrs")
    physical_exhaustion: int = Field(..., ge=1, le=5, description="1=Energized to 5=Completely Drained")
    peer_social_support: int = Field(..., ge=1, le=5, description="1=Isolated to 5=Strong Bond")
    synthetic: bool = Field(False, description="Flag indicating if survey was synthetically generated")

# -------------------------------------------------------------------
# Processed 30/60/90-day Rolling Features
# -------------------------------------------------------------------

class FeatureSet(BaseModel):
    pseudonym_token: str
    feature_timestamp: str
    
    # 30-Day Windows
    consecutive_duty_days_max_30d: float
    avg_shift_hours_30d: float
    leave_utilization_ratio_30d: float
    rest_day_deficit_ratio_30d: float
    high_hardship_exposure_ratio_30d: float
    avg_sleep_score_30d: float
    avg_exhaustion_score_30d: float
    composite_assessment_score_30d: float
    
    # 60-Day Windows
    avg_shift_hours_60d: float = 8.0
    leave_utilization_ratio_60d: float = 0.5
    composite_assessment_score_60d: float = 3.5

    # Deployment history (PS: "deployment records")
    deployment_changes_90d: float = 0.0
    days_at_current_deployment: float = 0.0

    # 90-Day Trends
    consecutive_duty_days_max_90d: float
    leave_utilization_ratio_90d: float
    transfer_frequency_rate_90d: float
    training_load_trend_slope: float
    mood_trend_slope: float
    workload_trend_slope: float
    sleep_deterioration_delta: float
    
    # NLP Historical Trend Component (Consented Transcripts)
    nlp_stress_trend_score: Optional[float] = Field(0.0, ge=0.0, le=1.0)
    
    synthetic: bool = True

# -------------------------------------------------------------------
# Scoring & Explainability Schemas
# -------------------------------------------------------------------

class FactorAttribution(BaseModel):
    factor_name: str = Field(..., description="Canonical feature identifier")
    display_title: str = Field(..., description="Human-readable factor title for Welfare Officer")
    importance_weight: float = Field(..., description="SHAP-style contribution weight")
    direction: str = Field(..., description="'risk_increasing' or 'protective'")
    context_detail: str = Field(..., description="Contextual observation (e.g. '28 continuous duty days')")

class ScorePredictionRequest(BaseModel):
    pseudonym_token: str
    features: Optional[FeatureSet] = None
    recent_hr_records: Optional[List[HRRecordInput]] = None
    recent_assessments: Optional[List[WellnessAssessmentInput]] = None
    recent_nlp_sentiment_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    recent_crisis_cue_detected: Optional[bool] = False

class RiskAssessmentResponse(BaseModel):
    pseudonym_token: str
    risk_band: RiskBand = Field(..., description="Categorical clinical risk tier (never a raw score)")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence band of prediction")
    top_factors: List[FactorAttribution] = Field(
        ..., 
        description="Top 3-5 contributing factors for Welfare Officer explainability"
    )
    recommended_support_pathway: str = Field(
        ..., 
        description="Supportive recommendation (no disciplinary or fitness-for-duty implication)"
    )
    model_version: str
    evaluated_at: str
    synthetic: bool

class BatchScoreRequest(BaseModel):
    items: List[ScorePredictionRequest]

class BatchScoreResponse(BaseModel):
    results: List[RiskAssessmentResponse]
    total_evaluated: int
    elevated_count: int
    moderate_count: int
    low_count: int

# -------------------------------------------------------------------
# NLP Schemas (Routine Sentiment + High-Recall Crisis Classification)
# -------------------------------------------------------------------

class NLPSentimentRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Message text or companion conversation turn")
    context_turn_id: Optional[str] = None

class NLPSentimentResponse(BaseModel):
    text_snippet: str
    sentiment_label: str = Field(..., description="Positive, Neutral, Stressed, Fatigued")
    valence_score: float = Field(..., ge=-1.0, le=1.0, description="Negative to Positive valence")
    stress_probability: float = Field(..., ge=0.0, le=1.0, description="Estimated stress likelihood")
    fatigue_indicators: List[str] = Field(default_factory=list)
    processed_at: str

class NLPCrisisRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Companion conversation turn to monitor for crisis")
    transcript_id: Optional[str] = None
    pseudonym_token: Optional[str] = None

class TeleManasEscalationPayload(BaseModel):
    trigger: bool
    helpline: str = "14416"
    priority: str
    recommended_action: str

class NLPCrisisResponse(BaseModel):
    crisis_detected: bool = Field(..., description="High-recall crisis flag")
    crisis_probability: float = Field(..., ge=0.0, le=1.0)
    risk_indicators_detected: List[str] = Field(default_factory=list)
    escalation: TeleManasEscalationPayload
    stabilizing_response_hint: str = Field(
        ..., 
        description="Calm, supportive script directive for AI Companion; never terminate conversation"
    )
    processed_at: str

# -------------------------------------------------------------------
# Model Governance & Audit Schemas
# -------------------------------------------------------------------

class ModelCardResponse(BaseModel):
    model_id: str
    model_name: str
    model_type: str
    version: str
    training_window: str
    sample_size: int
    features_utilized: List[str]
    metrics: Dict[str, float]
    known_limitations: List[str]
    last_validated_date: str
    oversight_board_approved: bool
    is_active: bool

class RollbackRequest(BaseModel):
    target_version: str
    justification: str = Field(..., min_length=10)
    authorized_by: str

class RollbackResponse(BaseModel):
    status: str
    active_version: str
    previous_version: str
    timestamp: str

# -------------------------------------------------------------------
# Synthetic Generation Request / Response
# -------------------------------------------------------------------

class SyntheticDataGenRequest(BaseModel):
    personnel_count: int = Field(500, ge=10, le=5000)
    days_history: int = Field(90, ge=30, le=180)
    save_to_disk: bool = True

class SyntheticDataGenResponse(BaseModel):
    status: str
    personnel_count: int
    hr_records_count: int
    assessments_count: int
    transcripts_count: int
    file_paths: Dict[str, str]
    generated_at: str
