import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, roc_auc_score

try:
    import xgboost as xgb
    XGB_AVAILABLE = True
except ImportError:
    XGB_AVAILABLE = False

from sklearn.ensemble import HistGradientBoostingClassifier

from ..config import settings
from ..feature_engineering import FeatureEngineeringPipeline
from ..schemas import FactorAttribution, FeatureSet

class PredictiveBehavioralModel:
    """
    Gradient-boosted decision tree model for personnel stress and burnout risk.
    Chosen for interpretability over deep learning since explainability is a hard requirement.
    Generates SHAP-style factor attributions for Welfare Officers.
    """

    FEATURE_NAMES = FeatureEngineeringPipeline.FEATURE_COLUMNS

    FACTOR_DISPLAY_MAP = {
        "consecutive_duty_days_max_30d": "Continuous Duty Load (30d)",
        "avg_shift_hours_30d": "Average Daily Roster Hours (30d)",
        "leave_utilization_ratio_30d": "Leave Utilization Deficit (30d)",
        "rest_day_deficit_ratio_30d": "Rest Day Deprivation Ratio",
        "high_hardship_exposure_ratio_30d": "Extreme Operational Hardship Exposure",
        "avg_sleep_score_30d": "Reported Sleep Quality",
        "avg_exhaustion_score_30d": "Physical Exhaustion Rating",
        "composite_assessment_score_30d": "Wellness Assessment Baseline",
        "avg_shift_hours_60d": "Average Daily Roster Hours (60d)",
        "leave_utilization_ratio_60d": "Leave Utilization Deficit (60d)",
        "composite_assessment_score_60d": "Wellness Assessment Trend (60d)",
        "deployment_changes_90d": "Redeployment Frequency (90d)",
        "days_at_current_deployment": "Time at Current Posting",
        "consecutive_duty_days_max_90d": "Sustained Operational Duty Load (90d)",
        "leave_utilization_ratio_90d": "Quarterly Leave Deficit",
        "transfer_frequency_rate_90d": "Deployment / Unit Transfer Frequency",
        "training_load_trend_slope": "Physical Training Load Trajectory",
        "mood_trend_slope": "Mood Rating Decline",
        "workload_trend_slope": "Perceived Workload Escalation",
        "sleep_deterioration_delta": "Acute Sleep Score Drop",
        "nlp_stress_trend_score": "Conversational Stress Signal"
    }

    def __init__(self, model_version: str = "v1.0.0"):
        self.model_version = model_version
        self.model = None
        self.baseline_feature_means: Dict[str, float] = {}
        self.feature_importances_: Dict[str, float] = {}
        self.model_type = "XGBoost Classifier" if XGB_AVAILABLE else "HistGradientBoosting Classifier (GBDT)"

    def _init_underlying_model(self):
        if XGB_AVAILABLE:
            return xgb.XGBClassifier(
                n_estimators=120,
                max_depth=4,
                learning_rate=0.07,
                subsample=0.85,
                colsample_bytree=0.85,
                eval_metric="logloss",
                random_state=42
            )
        else:
            return HistGradientBoostingClassifier(
                max_iter=120,
                max_depth=4,
                learning_rate=0.07,
                random_state=42
            )

    def train(self, X: pd.DataFrame, y: np.ndarray) -> Dict[str, float]:
        """
        Trains the gradient boosted tree model and evaluates metrics.
        y is binary risk: 0 = Low/Resilient, 1 = Elevated/Burnout Risk
        """
        X_clean = X[self.FEATURE_NAMES].fillna(0.0)
        self.model = self._init_underlying_model()
        self.model.fit(X_clean, y)

        # Record population baselines for explainability attribution
        self.baseline_feature_means = X_clean.mean().to_dict()

        # Compute feature importances
        if hasattr(self.model, "feature_importances_"):
            importances = self.model.feature_importances_
            self.feature_importances_ = dict(zip(self.FEATURE_NAMES, importances.tolist()))
        else:
            # For HistGradientBoosting, calculate empirical variance as proxy or uniform
            self.feature_importances_ = {col: 1.0 / len(self.FEATURE_NAMES) for col in self.FEATURE_NAMES}

        # Calculate train metrics
        preds = self.model.predict(X_clean)
        probs = self.model.predict_proba(X_clean)[:, 1]

        metrics = {
            "accuracy": round(float(accuracy_score(y, preds)), 4),
            "precision": round(float(precision_score(y, preds, zero_division=0)), 4),
            "recall": round(float(recall_score(y, preds, zero_division=0)), 4),
            "f1": round(float(f1_score(y, preds, zero_division=0)), 4),
            "roc_auc": round(float(roc_auc_score(y, probs)), 4)
        }
        return metrics

    def predict_risk_probability(self, features: FeatureSet) -> Tuple[float, List[FactorAttribution]]:
        """
        Infers stress/burnout probability and computes top factor attributions.
        """
        if self.model is None:
            # Fallback heuristic if untrained
            return 0.20, []

        row_dict = features.model_dump()
        feat_vals = [float(row_dict.get(col, 0.0)) for col in self.FEATURE_NAMES]
        X_in = pd.DataFrame([feat_vals], columns=self.FEATURE_NAMES)

        # Risk probability
        prob = float(self.model.predict_proba(X_in)[0, 1])

        # Compute SHAP-style local factor attribution
        attributions = self._compute_factor_attributions(feat_vals)
        return prob, attributions

    def _compute_factor_attributions(self, feat_vals: List[float]) -> List[FactorAttribution]:
        """
        Calculates directional feature contributions compared against population baseline norms.
        """
        attributions = []
        for name, val in zip(self.FEATURE_NAMES, feat_vals):
            baseline = self.baseline_feature_means.get(name, 0.0)
            global_importance = self.feature_importances_.get(name, 0.05)

            # Invert sign for protective features where higher is better
            protective_features = [
                "avg_sleep_score_30d",
                "composite_assessment_score_30d",
                "composite_assessment_score_60d",
                "leave_utilization_ratio_30d",
                "leave_utilization_ratio_60d",
                "leave_utilization_ratio_90d",
            ]
            if name in protective_features:
                delta = baseline - val  # if val < baseline, risk increases
            else:
                delta = val - baseline  # if val > baseline, risk increases

            local_weight = delta * global_importance
            direction = "risk_increasing" if local_weight > 0.005 else "protective"
            
            # Format context detail
            detail = self._generate_factor_detail(name, val, baseline)
            
            attributions.append(FactorAttribution(
                factor_name=name,
                display_title=self.FACTOR_DISPLAY_MAP.get(name, name),
                importance_weight=round(float(abs(local_weight)), 4),
                direction=direction,
                context_detail=detail
            ))

        # Sort by importance weight descending and return top 5
        attributions.sort(key=lambda x: x.importance_weight, reverse=True)
        return attributions[:5]

    def _generate_factor_detail(self, name: str, val: float, baseline: float) -> str:
        if "consecutive_duty" in name:
            return f"Consecutive operational days at {val:.0f} (baseline norm: {baseline:.0f} days)"
        elif "leave_utilization" in name:
            return f"Leave utilization at {val*100:.1f}% (norm: {baseline*100:.1f}%)"
        elif "shift_hours" in name:
            return f"Average daily duty roster of {val:.1f} hrs (norm: {baseline:.1f} hrs)"
        elif "sleep_deterioration" in name:
            return f"Reported sleep quality drop of {val:.1f} points over window"
        elif name == "deployment_changes_90d":
            return f"{val:.0f} redeployment(s) in the last 90 days (norm: {baseline:.1f})"
        elif name == "days_at_current_deployment":
            return f"{val:.0f} days at the current posting (norm: {baseline:.0f} days)"
        elif "high_hardship" in name:
            return f"{val*100:.0f}% of deployment time in high-risk operational zone"
        elif "avg_sleep" in name:
            return f"Average sleep rating {val:.1f}/5.0 (norm: {baseline:.1f})"
        elif "composite_assessment" in name:
            return f"Self-reported wellness check-in score: {val:.1f}/5.0"
        else:
            return f"Recorded metric value: {val:.2f}"

    def save(self, filepath: Optional[Path] = None):
        target_path = filepath or (settings.ARTIFACT_DIR / "behavioral_model.joblib")
        payload = {
            "model": self.model,
            "version": self.model_version,
            "baseline_means": self.baseline_feature_means,
            "feature_importances": self.feature_importances_,
            "model_type": self.model_type
        }
        joblib.dump(payload, target_path)

    def load(self, filepath: Optional[Path] = None) -> bool:
        target_path = filepath or (settings.ARTIFACT_DIR / "behavioral_model.joblib")
        if not target_path.exists():
            return False
        payload = joblib.load(target_path)
        self.model = payload["model"]
        self.model_version = payload["version"]
        self.baseline_feature_means = payload.get("baseline_means", {})
        self.feature_importances_ = payload.get("feature_importances", {})
        self.model_type = payload.get("model_type", self.model_type)
        return True
