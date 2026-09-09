from datetime import datetime, timedelta
from typing import Dict, List, Optional, Union
import numpy as np
import pandas as pd

from .schemas import FeatureSet, HRRecordInput, WellnessAssessmentInput

class FeatureEngineeringPipeline:
    """
    Feature Engineering Pipeline for ManoFit.
    Converts pseudonymized HR operational data and wellness survey check-ins
    into rolling-window (30/60/90-day) behavioral and longitudinal features.
    
    Hard requirement: Schema parity between synthetic and real production data.
    """

    FEATURE_COLUMNS = [
        "consecutive_duty_days_max_30d",
        "avg_shift_hours_30d",
        "leave_utilization_ratio_30d",
        "rest_day_deficit_ratio_30d",
        "high_hardship_exposure_ratio_30d",
        "avg_sleep_score_30d",
        "avg_exhaustion_score_30d",
        "composite_assessment_score_30d",
        "avg_shift_hours_60d",
        "leave_utilization_ratio_60d",
        "composite_assessment_score_60d",
        "deployment_changes_90d",
        "days_at_current_deployment",
        "consecutive_duty_days_max_90d",
        "leave_utilization_ratio_90d",
        "transfer_frequency_rate_90d",
        "training_load_trend_slope",
        "mood_trend_slope",
        "workload_trend_slope",
        "sleep_deterioration_delta",
        "nlp_stress_trend_score"
    ]

    def extract_features_for_personnel(
        self,
        pseudonym_token: str,
        hr_df: pd.DataFrame,
        assessments_df: pd.DataFrame,
        as_of_date: Optional[str] = None,
        nlp_sentiment_score: Optional[float] = None
    ) -> FeatureSet:
        """
        Builds a single FeatureSet for a given personnel token as of a target date.
        """
        # Filter records for token
        if hr_df is not None and not hr_df.empty and "pseudonym_token" in hr_df.columns:
            user_hr = hr_df[hr_df["pseudonym_token"] == pseudonym_token].copy()
        else:
            user_hr = pd.DataFrame()

        if assessments_df is not None and not assessments_df.empty and "pseudonym_token" in assessments_df.columns:
            user_assessments = assessments_df[assessments_df["pseudonym_token"] == pseudonym_token].copy()
        else:
            user_assessments = pd.DataFrame()

        if as_of_date:
            target_dt = pd.to_datetime(as_of_date)
        else:
            target_dt = pd.to_datetime(datetime.now().date())

        # Ensure datetime sorting
        if not user_hr.empty and "record_date" in user_hr.columns:
            user_hr["record_date"] = pd.to_datetime(user_hr["record_date"])
            user_hr = user_hr[user_hr["record_date"] <= target_dt].sort_values("record_date")
        else:
            user_hr = pd.DataFrame()
        
        if not user_assessments.empty and "assessment_date" in user_assessments.columns:
            user_assessments["assessment_date"] = pd.to_datetime(user_assessments["assessment_date"])
            user_assessments = user_assessments[user_assessments["assessment_date"] <= target_dt].sort_values("assessment_date")
        else:
            user_assessments = pd.DataFrame()

        # 30-day and 90-day cutoffs
        dt_30d = target_dt - timedelta(days=30)
        dt_60d = target_dt - timedelta(days=60)
        dt_90d = target_dt - timedelta(days=90)

        hr_30d = user_hr[user_hr["record_date"] >= dt_30d] if not user_hr.empty else pd.DataFrame()
        hr_60d = user_hr[user_hr["record_date"] >= dt_60d] if not user_hr.empty else pd.DataFrame()
        hr_90d = user_hr[user_hr["record_date"] >= dt_90d] if not user_hr.empty else pd.DataFrame()

        assessments_30d = user_assessments[user_assessments["assessment_date"] >= dt_30d] if not user_assessments.empty else pd.DataFrame()
        assessments_60d = user_assessments[user_assessments["assessment_date"] >= dt_60d] if not user_assessments.empty else pd.DataFrame()
        assessments_90d = user_assessments[user_assessments["assessment_date"] >= dt_90d] if not user_assessments.empty else pd.DataFrame()

        # 1. Operational HR features (30-day)
        if not hr_30d.empty and "consecutive_active_days" in hr_30d.columns:
            consecutive_30d_max = float(hr_30d["consecutive_active_days"].max())
            avg_shift_30d = float(hr_30d["shift_hours"].mean()) if "shift_hours" in hr_30d.columns else 8.0
            total_leave_taken_30d = float(hr_30d["leave_taken_days"].sum()) if "leave_taken_days" in hr_30d.columns else 0.0
            latest_leave_balance = float(hr_30d["leave_balance_days"].iloc[-1]) if "leave_balance_days" in hr_30d.columns else 15.0
            leave_util_30d = total_leave_taken_30d / max(1.0, (total_leave_taken_30d + latest_leave_balance))
            
            rest_days_30d = (hr_30d["is_rest_day"] == True).sum() if "is_rest_day" in hr_30d.columns else 0
            expected_rest_days = max(1.0, len(hr_30d) / 7.0)
            rest_deficit_30d = max(0.0, (expected_rest_days - rest_days_30d) / expected_rest_days)
            
            hardship_tiers = ["CI_OPS", "FIELD_EXTREME", "BORDER_OUTPOST"]
            high_hardship_count = hr_30d["location_tier"].isin(hardship_tiers).sum() if "location_tier" in hr_30d.columns else 0
            hardship_ratio_30d = float(high_hardship_count / max(1, len(hr_30d)))
        else:
            consecutive_30d_max = 0.0
            avg_shift_30d = 8.0
            leave_util_30d = 0.5
            rest_deficit_30d = 0.0
            hardship_ratio_30d = 0.0

        # 1b. Operational HR features (60-day) — the middle window the PRD and
        # architecture both specify; without it a strain that builds over two
        # months is invisible between the 30d snapshot and the 90d trend.
        if not hr_60d.empty and "shift_hours" in hr_60d.columns:
            avg_shift_60d = float(hr_60d["shift_hours"].mean())
            total_leave_taken_60d = float(hr_60d["leave_taken_days"].sum()) if "leave_taken_days" in hr_60d.columns else 0.0
            latest_balance_60d = float(hr_60d["leave_balance_days"].iloc[-1]) if "leave_balance_days" in hr_60d.columns else 15.0
            leave_util_60d = total_leave_taken_60d / max(1.0, (total_leave_taken_60d + latest_balance_60d))
        else:
            avg_shift_60d = 8.0
            leave_util_60d = 0.5

        # 1c. Deployment history (PS category: "deployment records").
        # deployment_id changes on redeployment, so a change is a real event we
        # can count — unlike transfer_count_last_12m, which is a static field.
        deployment_changes_90d = 0.0
        days_at_current_deployment = 0.0
        if not hr_90d.empty and "deployment_id" in hr_90d.columns:
            stints = hr_90d["deployment_id"].dropna()
            if not stints.empty:
                # Consecutive-run count: how many times the posting changed.
                deployment_changes_90d = float((stints != stints.shift()).sum() - 1)
                deployment_changes_90d = max(0.0, deployment_changes_90d)

            if "deployment_start_date" in hr_90d.columns:
                last_start = hr_90d["deployment_start_date"].dropna()
                if not last_start.empty:
                    start_dt = pd.to_datetime(last_start.iloc[-1], errors="coerce")
                    if pd.notna(start_dt):
                        days_at_current_deployment = float(max(0, (target_dt - start_dt).days))

        # 2. Operational HR features (90-day)
        if not hr_90d.empty and "consecutive_active_days" in hr_90d.columns:
            consecutive_90d_max = float(hr_90d["consecutive_active_days"].max())
            total_leave_taken_90d = float(hr_90d["leave_taken_days"].sum()) if "leave_taken_days" in hr_90d.columns else 0.0
            latest_balance_90d = float(hr_90d["leave_balance_days"].iloc[-1]) if "leave_balance_days" in hr_90d.columns else 15.0
            leave_util_90d = total_leave_taken_90d / max(1.0, (total_leave_taken_90d + latest_balance_90d))
            transfer_rate_90d = float(hr_90d["transfer_count_last_12m"].max() / 4.0) if "transfer_count_last_12m" in hr_90d.columns else 0.0
            
            # Training load trend slope
            if len(hr_90d) > 5 and "training_load_hours" in hr_90d.columns:
                x = np.arange(len(hr_90d))
                y = hr_90d["training_load_hours"].values
                slope = np.polyfit(x, y, 1)[0]
                training_trend_slope = float(slope)
            else:
                training_trend_slope = 0.0
        else:
            consecutive_90d_max = 0.0
            leave_util_90d = 0.5
            transfer_rate_90d = 0.0
            training_trend_slope = 0.0

        # 3. Wellness Survey Assessment features (30-day and 90-day trends)
        if not assessments_30d.empty and "mood_rating" in assessments_30d.columns:
            avg_sleep_30d = float(assessments_30d["sleep_quality"].mean())
            avg_exhaustion_30d = float(assessments_30d["physical_exhaustion"].mean())
            
            # Composite score: higher means higher well-being (1 to 5 scale)
            # Positive: mood, sleep, social, manager; Negative: workload, exhaustion
            pos_dims = assessments_30d["mood_rating"] + assessments_30d["sleep_quality"] + \
                       assessments_30d["peer_social_support"] + assessments_30d["manager_relationship"]
            neg_dims = assessments_30d["workload_perception"] + assessments_30d["physical_exhaustion"]
            series_composite = ((pos_dims / 4.0) - (neg_dims / 2.0) + 5.0) / 2.0
            composite_30d = float(series_composite.mean())
        else:
            avg_sleep_30d = 3.5
            avg_exhaustion_30d = 2.5
            composite_30d = 3.5

        if not assessments_60d.empty and "mood_rating" in assessments_60d.columns:
            pos_60 = assessments_60d["mood_rating"] + assessments_60d["sleep_quality"] +                      assessments_60d["peer_social_support"] + assessments_60d["manager_relationship"]
            neg_60 = assessments_60d["workload_perception"] + assessments_60d["physical_exhaustion"]
            composite_60d = float((((pos_60 / 4.0) - (neg_60 / 2.0) + 5.0) / 2.0).mean())
        else:
            composite_60d = 3.5

        if not assessments_90d.empty and len(assessments_90d) > 2:
            x_ass = np.arange(len(assessments_90d))
            mood_slope = float(np.polyfit(x_ass, assessments_90d["mood_rating"].values, 1)[0])
            workload_slope = float(np.polyfit(x_ass, assessments_90d["workload_perception"].values, 1)[0])
            
            # Sleep deterioration: difference between first recorded sleep score and latest
            first_sleep = assessments_90d["sleep_quality"].iloc[0]
            latest_sleep = assessments_90d["sleep_quality"].iloc[-1]
            sleep_det_delta = float(first_sleep - latest_sleep)  # positive means dropped
        else:
            mood_slope = 0.0
            workload_slope = 0.0
            sleep_det_delta = 0.0

        return FeatureSet(
            pseudonym_token=pseudonym_token,
            feature_timestamp=target_dt.strftime("%Y-%m-%d"),
            consecutive_duty_days_max_30d=round(consecutive_30d_max, 2),
            avg_shift_hours_30d=round(avg_shift_30d, 2),
            leave_utilization_ratio_30d=round(leave_util_30d, 4),
            rest_day_deficit_ratio_30d=round(rest_deficit_30d, 4),
            high_hardship_exposure_ratio_30d=round(hardship_ratio_30d, 4),
            avg_sleep_score_30d=round(avg_sleep_30d, 2),
            avg_exhaustion_score_30d=round(avg_exhaustion_30d, 2),
            composite_assessment_score_30d=round(composite_30d, 2),
            avg_shift_hours_60d=round(avg_shift_60d, 2),
            leave_utilization_ratio_60d=round(leave_util_60d, 4),
            composite_assessment_score_60d=round(composite_60d, 2),
            deployment_changes_90d=round(deployment_changes_90d, 2),
            days_at_current_deployment=round(days_at_current_deployment, 1),
            consecutive_duty_days_max_90d=round(consecutive_90d_max, 2),
            leave_utilization_ratio_90d=round(leave_util_90d, 4),
            transfer_frequency_rate_90d=round(transfer_rate_90d, 2),
            training_load_trend_slope=round(training_trend_slope, 4),
            mood_trend_slope=round(mood_slope, 4),
            workload_trend_slope=round(workload_slope, 4),
            sleep_deterioration_delta=round(sleep_det_delta, 2),
            nlp_stress_trend_score=round(nlp_sentiment_score or 0.0, 3),
            synthetic=True
        )

    def transform_dataset(
        self,
        hr_df: pd.DataFrame,
        assessments_df: pd.DataFrame,
        as_of_date: Optional[str] = None,
        nlp_scores: Optional[Dict[str, float]] = None
    ) -> pd.DataFrame:
        """
        Batch transformation of HR and assessment data into a standardized feature matrix.

        [nlp_scores] maps a pseudonym token to its longitudinal conversational
        stress score (0-1). Pass it at training time: without it the
        `nlp_stress_trend_score` column is uniformly zero, and a feature that
        never varies is a feature the tree model cannot learn from.
        """
        all_tokens = hr_df["pseudonym_token"].unique()
        scores = nlp_scores or {}
        feature_rows = []
        for token in all_tokens:
            fs = self.extract_features_for_personnel(
                pseudonym_token=token,
                hr_df=hr_df,
                assessments_df=assessments_df,
                as_of_date=as_of_date,
                nlp_sentiment_score=scores.get(token)
            )
            feature_rows.append(fs.model_dump())
        return pd.DataFrame(feature_rows)
