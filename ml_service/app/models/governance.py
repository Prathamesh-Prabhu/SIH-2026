import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
import pandas as pd

from ..config import settings
from ..schemas import ModelCardResponse, RollbackResponse

class ModelGovernanceManager:
    """
    Manages Model Cards, Oversight Board Compliance, Drift Tracking,
    and Independent Model Rollback for the ManoFit Analytics & ML layer.
    """

    def __init__(self):
        self.governance_file = settings.ARTIFACT_DIR / "model_governance.json"
        self.model_card_file = settings.ARTIFACT_DIR / "model_card.json"
        self.checkpoints_dir = settings.ARTIFACT_DIR / "checkpoints"
        self.checkpoints_dir.mkdir(parents=True, exist_ok=True)

    def create_model_card(
        self,
        model_version: str,
        model_type: str,
        metrics: Dict[str, float],
        features: List[str],
        sample_size: int,
        oversight_approved: bool = True
    ) -> ModelCardResponse:
        card = ModelCardResponse(
            model_id=f"manofit-risk-{model_version}",
            model_name="ManoFit Behavioral & Stress Risk Predictive Model",
            model_type=model_type,
            version=model_version,
            training_window="90-day rolling synthetic & anonymized operational records",
            sample_size=sample_size,
            features_utilized=features,
            metrics=metrics,
            known_limitations=[
                "Model operates exclusively on pseudonymized rolling aggregations; no direct clinical diagnoses.",
                "Subject to monthly recalibration by Welfare Clinical Review Board.",
                "Zero cross-linkage to disciplinary or performance evaluation records.",
                "Trained and evaluated on synthetic bootstrap data only; no real "
                "personnel records have been seen by this version. Reported metrics are "
                "measured on a held-out 25% split of simulated personnel, so they show "
                "generalisation within the simulation, NOT real-world accuracy.",
                "Outcome labels are stochastic draws from a latent simulated welfare "
                "state, not clinician-reviewed outcomes. Real performance is unknown "
                "until the Phase 2 clinical-review loop supplies reviewed labels.",
                "Tuned for sensitivity (recall target 0.80), which deliberately trades "
                "precision: a meaningful share of flagged personnel will not be at risk. "
                "Every flag is a prompt for a supportive human check-in, never a "
                "determination.",
            ],
            last_validated_date=datetime.now().date().isoformat(),
            oversight_board_approved=oversight_approved,
            is_active=True
        )

        with open(self.model_card_file, "w") as f:
            json.dump(card.model_dump(), f, indent=2)

        # Snapshot into checkpoints directory
        checkpoint_path = self.checkpoints_dir / f"model_card_{model_version}.json"
        with open(checkpoint_path, "w") as f:
            json.dump(card.model_dump(), f, indent=2)

        return card

    def get_active_model_card(self) -> Optional[ModelCardResponse]:
        if not self.model_card_file.exists():
            return None
        with open(self.model_card_file, "r") as f:
            data = json.load(f)
            return ModelCardResponse(**data)

    def checkpoint_model_version(self, version: str):
        """Archives current model artifacts for rollback."""
        version_dir = self.checkpoints_dir / version
        version_dir.mkdir(parents=True, exist_ok=True)

        for fname in ["behavioral_model.joblib", "nlp_sentiment.joblib", "nlp_crisis.joblib", "model_card.json"]:
            src = settings.ARTIFACT_DIR / fname
            if src.exists():
                shutil.copy2(src, version_dir / fname)

    def rollback_to_version(self, target_version: str, justification: str, authorized_by: str) -> RollbackResponse:
        version_dir = self.checkpoints_dir / target_version
        if not version_dir.exists():
            raise FileNotFoundError(f"Checkpoint for version {target_version} does not exist.")

        # Read current active version
        active_card = self.get_active_model_card()
        prev_version = active_card.version if active_card else "unknown"

        # Restore checkpoint files
        for fname in ["behavioral_model.joblib", "nlp_sentiment.joblib", "nlp_crisis.joblib", "model_card.json"]:
            src = version_dir / fname
            if src.exists():
                shutil.copy2(src, settings.ARTIFACT_DIR / fname)

        # Log rollback in governance audit log
        log_entry = {
            "action": "MODEL_ROLLBACK",
            "from_version": prev_version,
            "to_version": target_version,
            "authorized_by": authorized_by,
            "justification": justification,
            "timestamp": datetime.now().isoformat()
        }
        
        audit_file = settings.ARTIFACT_DIR / "governance_audit.log"
        with open(audit_file, "a") as f:
            f.write(json.dumps(log_entry) + "\n")

        return RollbackResponse(
            status="SUCCESS",
            active_version=target_version,
            previous_version=prev_version,
            timestamp=datetime.now().isoformat()
        )

    def sample_cases_for_clinical_review(
        self, 
        evaluations_df: pd.DataFrame, 
        sample_size: int = 30
    ) -> pd.DataFrame:
        """
        Samples a balanced cohort of flagged (Elevated/Moderate) and unflagged (Low) cases
        for the monthly human clinical validation loop per PRD §3.3.
        """
        if evaluations_df.empty:
            return pd.DataFrame()

        # Stratified sampling
        strata = []
        for band in ["ELEVATED", "MODERATE", "LOW"]:
            subset = evaluations_df[evaluations_df["risk_band"] == band]
            n = min(len(subset), sample_size // 3)
            if n > 0:
                strata.append(subset.sample(n=n, random_state=42))

        if strata:
            return pd.concat(strata).reset_index(drop=True)
        return evaluations_df.head(sample_size)
