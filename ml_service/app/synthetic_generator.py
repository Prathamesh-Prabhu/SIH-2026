import json
import random
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple
import pandas as pd

from .config import settings
from .schemas import DeploymentLocationTier

class SyntheticDataGenerator:
    """
    Generates statistically realistic, schema-matched synthetic datasets
    bootstrapping the ManoFit Analytics & ML layer in Phase 1 offline without real identifiers.
    Categories mandated by the Problem Statement:
      1. Anonymized HR records & deployment history
      2. Leave history and operational workload
      3. Wellness survey data (6 check-ins)
      4. Simulated companion transcripts (routine to crisis)
      5. Rule-based clinical-stand-in labels for supervised calibration
    """

    def __init__(self, seed: int = 42):
        random.seed(seed)
        self.location_tiers = list(DeploymentLocationTier)
        self.unit_prefixes = ["BN-08", "BN-14", "BN-23", "COBRA-204", "RAF-108", "BSF-SHQ", "CRPF-OPS"]

    def generate_personnel_tokens(self, count: int) -> List[str]:
        return [f"TOKEN-{i:06d}" for i in range(1, count + 1)]

    def generate_all(
        self, 
        personnel_count: int = 500, 
        days_history: int = 90, 
        save_to_disk: bool = True
    ) -> Dict[str, any]:
        tokens = self.generate_personnel_tokens(personnel_count)
        
        # 1. Assign archetypes to personnel to mirror authentic military welfare distributions:
        # ~65% low risk / resilient, ~25% moderate strain / emerging fatigue, ~10% elevated risk / severe stress
        personnel_archetypes = {}
        for token in tokens:
            r = random.random()
            if r < 0.65:
                archetype = "resilient"
            elif r < 0.90:
                archetype = "moderate_strain"
            else:
                archetype = "elevated_risk"
            personnel_archetypes[token] = archetype

        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days_history)

        hr_records: List[Dict] = []
        assessment_records: List[Dict] = []
        transcript_records: List[Dict] = []

        for token in tokens:
            archetype = personnel_archetypes[token]
            unit = random.choice(self.unit_prefixes)
            transfers = 0 if archetype == "resilient" else (1 if archetype == "moderate_strain" else random.randint(1, 3))
            base_leave_balance = random.randint(15, 30)

            # Deployment stints: a posting is a span with a start date, not a
            # per-day dice roll. Churn scales with archetype — repeated
            # redeployment with short turnarounds is itself a strain signal.
            deployment_schedule = self._generate_deployment_schedule(
                archetype, start_date, days_history
            )

            # Generate HR daily records
            consecutive_active = 0
            leave_balance = base_leave_balance

            for day_idx in range(days_history):
                curr_date = start_date + timedelta(days=day_idx)
                
                # Active deployment stint for this day drives the location tier.
                stint = deployment_schedule[day_idx]

                # Characteristics based on archetype
                if archetype == "resilient":
                    location = stint["location"]
                    is_rest = (day_idx % 7 == 0)
                    shift_hours = 0.0 if is_rest else random.uniform(6.0, 8.5)
                    training_load = random.uniform(0.5, 2.0) if not is_rest else 0.0
                    leave_taken = 1.0 if (day_idx % 25 == 0 and leave_balance > 0) else 0.0
                elif archetype == "moderate_strain":
                    location = stint["location"]
                    is_rest = (day_idx % 12 == 0)
                    shift_hours = 0.0 if is_rest else random.uniform(9.0, 12.0)
                    training_load = random.uniform(1.5, 3.5) if not is_rest else 0.0
                    leave_taken = 1.0 if (day_idx % 40 == 0 and leave_balance > 0) else 0.0
                else:  # elevated_risk
                    location = stint["location"]
                    is_rest = (day_idx % 22 == 0)  # very few rest days
                    shift_hours = 0.0 if is_rest else random.uniform(12.0, 16.0)
                    training_load = random.uniform(3.0, 5.0) if not is_rest else 0.0
                    leave_taken = 1.0 if (day_idx % 70 == 0 and leave_balance > 0) else 0.0  # severely denied leave

                if is_rest or leave_taken > 0:
                    consecutive_active = 0
                else:
                    consecutive_active += 1

                if leave_taken > 0 and leave_balance > 0:
                    leave_balance -= leave_taken

                hr_records.append({
                    "pseudonym_token": token,
                    "record_date": curr_date.isoformat(),
                    "unit_code": unit,
                    "location_tier": location.value,
                    "shift_hours": round(shift_hours, 1),
                    "is_rest_day": is_rest,
                    "leave_taken_days": leave_taken,
                    "leave_balance_days": leave_balance,
                    "consecutive_active_days": consecutive_active,
                    "transfer_count_last_12m": transfers,
                    "deployment_id": stint["deployment_id"],
                    "deployment_start_date": stint["start_date"],
                    "training_load_hours": round(training_load, 1),
                    "synthetic": True
                })

            # Generate Periodic Wellness Survey Check-Ins (Bi-weekly)
            for checkin_day in range(0, days_history, 14):
                c_date = start_date + timedelta(days=checkin_day)
                # 6 Check-ins: Workload, Mood, Manager, Sleep, Exhaustion, Social Support
                if archetype == "resilient":
                    workload = random.randint(1, 2)
                    mood = random.randint(4, 5)
                    manager = random.randint(4, 5)
                    sleep = random.randint(4, 5)
                    exhaustion = random.randint(1, 2)
                    social = random.randint(4, 5)
                elif archetype == "moderate_strain":
                    workload = random.randint(3, 4)
                    mood = random.randint(2, 4)
                    manager = random.randint(2, 3)
                    sleep = random.randint(2, 3)
                    exhaustion = random.randint(3, 4)
                    social = random.randint(2, 4)
                else:  # elevated_risk
                    # Deteriorating trajectory
                    trajectory_decay = 1 if checkin_day > (days_history // 2) else 0
                    workload = min(5, random.randint(4, 5) + trajectory_decay)
                    mood = max(1, random.randint(1, 2) - trajectory_decay)
                    manager = random.randint(1, 2)
                    sleep = max(1, random.randint(1, 2) - trajectory_decay)
                    exhaustion = 5
                    social = random.randint(1, 2)

                assessment_records.append({
                    "pseudonym_token": token,
                    "assessment_date": c_date.isoformat(),
                    "workload_perception": workload,
                    "mood_rating": mood,
                    "manager_relationship": manager,
                    "sleep_quality": sleep,
                    "physical_exhaustion": exhaustion,
                    "peer_social_support": social,
                    "synthetic": True
                })

            # Generate companion transcripts (sampled)
            transcript_records.extend(self._generate_transcripts_for_archetype(token, archetype))

        hr_df = pd.DataFrame(hr_records)
        assessments_df = pd.DataFrame(assessment_records)
        transcripts_df = pd.DataFrame(transcript_records)

        paths = {}
        if save_to_disk:
            hr_path = settings.DATA_DIR / "synthetic_hr_records.csv"
            assessments_path = settings.DATA_DIR / "synthetic_assessments.csv"
            transcripts_path = settings.DATA_DIR / "synthetic_transcripts.jsonl"
            
            hr_df.to_csv(hr_path, index=False)
            assessments_df.to_csv(assessments_path, index=False)
            transcripts_df.to_json(transcripts_path, orient="records", lines=True)
            
            paths["hr_records"] = str(hr_path)
            paths["assessments"] = str(assessments_path)
            paths["transcripts"] = str(transcripts_path)

        return {
            "hr_df": hr_df,
            "assessments_df": assessments_df,
            "transcripts_df": transcripts_df,
            "nlp_scores": self.compute_nlp_stress_scores(transcripts_df),
            "paths": paths
        }

    def _generate_deployment_schedule(
        self, archetype: str, start_date, days_history: int
    ) -> List[Dict]:
        """
        Builds a day-indexed deployment schedule: a list of stints, each with an
        id, a start date and a hardship tier, expanded to one entry per day.

        This is the PS's "deployment records" category. Modelling postings as
        spans (rather than a per-day random location) is what makes
        redeployment an observable event, so the feature pipeline can count
        changes and measure time at the current posting.
        """
        if archetype == "resilient":
            stint_lengths = [days_history]
            tiers = [DeploymentLocationTier.PEACE, DeploymentLocationTier.HIGH_ALTITUDE]
        elif archetype == "moderate_strain":
            stint_lengths = [random.randint(35, 55)]
            stint_lengths.append(days_history - stint_lengths[0])
            tiers = [DeploymentLocationTier.HIGH_ALTITUDE, DeploymentLocationTier.BORDER_OUTPOST]
        else:  # elevated_risk — frequent redeployment, short turnarounds
            remaining = days_history
            stint_lengths = []
            while remaining > 0:
                length = min(remaining, random.randint(20, 35))
                stint_lengths.append(length)
                remaining -= length
            tiers = [DeploymentLocationTier.CI_OPS, DeploymentLocationTier.FIELD_EXTREME]

        schedule: List[Dict] = []
        day_cursor = 0
        for idx, length in enumerate(stint_lengths):
            if length <= 0:
                continue
            stint_start = start_date + timedelta(days=day_cursor)
            stint = {
                "deployment_id": f"DEP-{random.randint(100000, 999999)}",
                "start_date": stint_start.isoformat(),
                "location": tiers[idx % len(tiers)],
            }
            schedule.extend([stint] * length)
            day_cursor += length

        # Pad/trim so the schedule always covers exactly days_history entries.
        while len(schedule) < days_history:
            schedule.append(schedule[-1])
        return schedule[:days_history]

    @staticmethod
    def compute_nlp_stress_scores(transcripts_df: pd.DataFrame) -> Dict[str, float]:
        """
        Longitudinal conversational stress score per person, 0-1.

        Feeds `nlp_stress_trend_score` at training time. Crisis utterances weigh
        more than routine strain, matching the two-tier NLP split in PRD §5.
        """
        if transcripts_df is None or transcripts_df.empty:
            return {}

        weights = {
            "positive_or_neutral": 0.0,
            "stressed_or_fatigued": 0.5,
            "severe_distress": 0.8,
            "crisis": 1.0,
        }
        scored = transcripts_df.copy()
        scored["_w"] = scored["sentiment"].map(weights).fillna(0.3)
        return {
            str(token): round(float(min(1.0, group["_w"].mean())), 3)
            for token, group in scored.groupby("pseudonym_token")
        }

    def _generate_transcripts_for_archetype(self, token: str, archetype: str) -> List[Dict]:
        """Simulate conversational utterances with routine, stressed, and crisis cues."""
        routine_phrases = [
            "Had a productive patrol today. Unit morale is decent.",
            "Weather was tough at the pass, but we managed the shift well.",
            "Looking forward to calling family this weekend.",
            "Routine physical conditioning done. Feeling energized.",
            "Duty hours were normal today, got 7 hours of rest."
        ]
        
        moderate_strain_phrases = [
            "Third night shift in a row, headache won't go away.",
            "Feeling constant fatigue lately, hard to stay focused on sentry duty.",
            "Too much paperwork on top of 12-hour guard rosters.",
            "Missed my child's birthday because leave was delayed again.",
            "Irritable lately, body aches from the wet cold."
        ]
        
        elevated_phrases = [
            "I feel completely isolated here, nobody understands what we're going through.",
            "Can't sleep more than 2 hours without waking up panicking.",
            "Everything feels numb and pointless lately.",
            "I don't know how much longer I can carry this burden.",
            "Constantly on edge, hands shaking during weapon cleaning."
        ]

        crisis_phrases = [
            "I can't take this pain anymore, there's no way out for me.",
            "Everyone in the unit and back home would be better off without me.",
            "I'm giving away my watch and personal gear tonight, won't need them.",
            "Thinking about ending it all, the darkness won't stop.",
            "I feel like pulling the trigger and just ending this suffering."
        ]

        transcripts = []
        if archetype == "resilient":
            phrases = random.sample(routine_phrases, k=2)
            for phrase in phrases:
                transcripts.append({
                    "pseudonym_token": token,
                    "text": phrase,
                    "sentiment": "positive_or_neutral",
                    "crisis_label": 0,
                    "synthetic": True
                })
        elif archetype == "moderate_strain":
            phrases = random.sample(moderate_strain_phrases, k=2)
            for phrase in phrases:
                transcripts.append({
                    "pseudonym_token": token,
                    "text": phrase,
                    "sentiment": "stressed_or_fatigued",
                    "crisis_label": 0,
                    "synthetic": True
                })
        else:  # elevated_risk
            # Includes high-recall crisis statements and severe distress
            phrases = [random.choice(elevated_phrases), random.choice(crisis_phrases)]
            for phrase in phrases:
                is_crisis = 1 if phrase in crisis_phrases else 0
                transcripts.append({
                    "pseudonym_token": token,
                    "text": phrase,
                    "sentiment": "crisis" if is_crisis else "severe_distress",
                    "crisis_label": is_crisis,
                    "synthetic": True
                })

        return transcripts
