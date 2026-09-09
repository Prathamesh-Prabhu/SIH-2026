from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import joblib
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline

from ..config import settings
from ..schemas import (
    NLPCrisisResponse,
    NLPSentimentResponse,
    TeleManasEscalationPayload
)

class RoutineSentimentClassifier:
    """
    Tier 1 NLP Model:
    Tracks longitudinal mood, fatigue, and stress indicators in everyday companion check-in dialogue.
    Outputs sentiment category, valence (-1.0 to 1.0), and estimated stress probability.
    """

    def __init__(self):
        self.pipeline: Optional[Pipeline] = None
        self.is_trained = False
        self._init_default_pipeline()

    def _init_default_pipeline(self):
        self.pipeline = Pipeline([
            ("tfidf", TfidfVectorizer(ngram_range=(1, 2), max_features=1500, stop_words="english")),
            ("clf", LogisticRegression(class_weight="balanced", max_iter=200, random_state=42))
        ])

    def train(self, texts: List[str], labels: List[str]):
        """
        Labels: 'positive_or_neutral' vs 'stressed_or_fatigued'
        """
        self.pipeline.fit(texts, labels)
        self.is_trained = True

    def analyze(self, text: str) -> NLPSentimentResponse:
        text_clean = text.strip()
        lower = text_clean.lower()

        # Heuristic keywords for fatigue & operational strain
        fatigue_cues = ["fatigue", "tired", "exhausted", "sleepy", "drained", "night shift", "insomnia", "body ache", "headache"]
        stress_cues = ["headache", "irritable", "overwhelmed", "pressure", "anxious", "restless", "burden", "heavy"]
        positive_cues = ["good", "productive", "fine", "calm", "looking forward", "energized", "relaxed", "rested", "peaceful"]

        matched_fatigue = [cue for cue in fatigue_cues if cue in lower]
        matched_stress = [cue for cue in stress_cues if cue in lower]
        matched_pos = [cue for cue in positive_cues if cue in lower]

        if self.is_trained and self.pipeline:
            prob_stressed = float(self.pipeline.predict_proba([text_clean])[0, 1])
        else:
            # Rule-assisted fallback
            prob_stressed = 0.5
            if matched_stress or matched_fatigue:
                prob_stressed = min(0.95, 0.4 + 0.15 * (len(matched_stress) + len(matched_fatigue)))
            elif matched_pos:
                prob_stressed = max(0.05, 0.3 - 0.1 * len(matched_pos))

        # Determine label and valence
        if prob_stressed > 0.65:
            label = "Fatigued" if (len(matched_fatigue) > len(matched_stress)) else "Stressed"
            valence = -round(prob_stressed, 2)
        elif prob_stressed > 0.40:
            label = "Neutral"
            valence = 0.05
        else:
            label = "Positive"
            valence = round(1.0 - prob_stressed, 2)

        return NLPSentimentResponse(
            text_snippet=text_clean[:120] + ("..." if len(text_clean) > 120 else ""),
            sentiment_label=label,
            valence_score=valence,
            stress_probability=round(prob_stressed, 3),
            fatigue_indicators=matched_fatigue,
            processed_at=datetime.now().isoformat()
        )

    def save(self, filepath: Optional[Path] = None):
        target_path = filepath or (settings.ARTIFACT_DIR / "nlp_sentiment.joblib")
        joblib.dump({"pipeline": self.pipeline, "is_trained": self.is_trained}, target_path)

    def load(self, filepath: Optional[Path] = None) -> bool:
        target_path = filepath or (settings.ARTIFACT_DIR / "nlp_sentiment.joblib")
        if not target_path.exists():
            return False
        data = joblib.load(target_path)
        self.pipeline = data["pipeline"]
        self.is_trained = data["is_trained"]
        return True


class HighRecallCrisisClassifier:
    """
    Tier 2 NLP Model:
    Dedicated high-recall crisis classifier for the Tele-MANAS (14416) escalation path.
    Catches both direct and subtle/indirect crisis expressions:
      - Despair & hopelessness ("can't take this anymore", "there is no way out")
      - Burdensomeness ("better off without me", "burden to everyone")
      - Farewell / Giving away possessions ("giving away my things", "won't need my gear")
      - Self-harm / suicidal ideation ("ending this suffering", "pulling the trigger")
    
    Priority: High sensitivity/recall, fast response, immediate parallel alert dispatch.
    """

    INDIRECT_CRISIS_PATTERNS = [
        ("no way out", "Feelings of entrapment and hopelessness"),
        ("better off without me", "Perceived burdensomeness on comrades or family"),
        ("giving away my", "Preparation / distributing personal possessions"),
        ("won't need", "Preparation / disengagement cues"),
        ("can't take this anymore", "Acute overwhelm / loss of endurance"),
        ("ending it all", "Active suicidal intent"),
        ("end this suffering", "Suicidal ideation / severe acute distress"),
        ("pulling the trigger", "Weapon-related self-harm intent"),
        ("don't want to wake up", "Passive suicidal ideation"),
        ("darkness won't stop", "Severe psychological exhaustion / depression"),
        ("pointless to live", "Existential despair"),
        ("no reason to live", "Explicit hopelessness")
    ]

    def __init__(self):
        self.pipeline: Optional[Pipeline] = None
        self.is_trained = False
        self._init_pipeline()

    def _init_pipeline(self):
        self.pipeline = Pipeline([
            ("tfidf", TfidfVectorizer(ngram_range=(1, 3), max_features=3000)),
            ("clf", LogisticRegression(class_weight={0: 1.0, 1: 5.0}, max_iter=250, random_state=42))
        ])

    def train(self, texts: List[str], crisis_labels: List[int]):
        """
        crisis_labels: 0 = non-crisis, 1 = crisis
        """
        self.pipeline.fit(texts, crisis_labels)
        self.is_trained = True

    def classify_crisis(self, text: str, transcript_id: Optional[str] = None) -> NLPCrisisResponse:
        text_clean = text.strip()
        lower = text_clean.lower()

        # Step 1: Detect pattern & semantic markers
        indicators = []
        rule_boost = 0.0
        for pattern, description in self.INDIRECT_CRISIS_PATTERNS:
            if pattern in lower:
                indicators.append(f"{description} (detected cue: '{pattern}')")
                rule_boost = max(rule_boost, 0.75)

        # Step 2: Model prediction if available
        if self.is_trained and self.pipeline:
            model_prob = float(self.pipeline.predict_proba([text_clean])[0, 1])
        else:
            model_prob = 0.1

        # Combine with priority for recall (max rule boost or model prob)
        combined_prob = max(model_prob, rule_boost)
        crisis_detected = (combined_prob >= settings.CRISIS_RECALL_THRESHOLD)

        # Tele-MANAS escalation payload
        escalation = TeleManasEscalationPayload(
            trigger=crisis_detected,
            helpline=settings.TELE_MANAS_HELPLINE,
            priority="IMMEDIATE_ESCALATION" if crisis_detected else "NONE",
            recommended_action=(
                f"Notify Tele-MANAS ({settings.TELE_MANAS_HELPLINE}) in parallel; "
                "alert unit duty Welfare Officer for immediate supportive human check-in."
                if crisis_detected else "Standard routine monitoring."
            )
        )

        stabilizing_prompt = (
            "I hear how heavy this feels right now, and I am right here with you. "
            "You don't have to carry this alone. Let's take a slow breath together — "
            "I want to make sure you have support. Can you tell me what's happening right now?"
            if crisis_detected else
            "Thank you for sharing that with me. How can I best support you today?"
        )

        return NLPCrisisResponse(
            crisis_detected=crisis_detected,
            crisis_probability=round(combined_prob, 4),
            risk_indicators_detected=indicators,
            escalation=escalation,
            stabilizing_response_hint=stabilizing_prompt,
            processed_at=datetime.now().isoformat()
        )

    def save(self, filepath: Optional[Path] = None):
        target_path = filepath or (settings.ARTIFACT_DIR / "nlp_crisis.joblib")
        joblib.dump({"pipeline": self.pipeline, "is_trained": self.is_trained}, target_path)

    def load(self, filepath: Optional[Path] = None) -> bool:
        target_path = filepath or (settings.ARTIFACT_DIR / "nlp_crisis.joblib")
        if not target_path.exists():
            return False
        data = joblib.load(target_path)
        self.pipeline = data["pipeline"]
        self.is_trained = data["is_trained"]
        return True
